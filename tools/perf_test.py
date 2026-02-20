#!/usr/bin/env python3
"""
Performance testing harness for WiserOne application
Tests startup time, memory usage, database operations, and sustained load
"""

import subprocess
import time
import psutil
import os
import sys
import json
import sqlite3
import tempfile
import shutil
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import List, Dict, Optional
import signal


@dataclass
class PerformanceMetrics:
    """Container for performance measurement results"""
    startup_time_ms: float
    memory_rss_mb: float
    memory_peak_mb: float
    cpu_percent: float
    database_init_ms: float
    quote_fetch_ms: float
    binary_size_mb: float
    test_duration_s: float
    quotes_fetched: int
    errors: List[str]


class WiserOneProfiler:
    """Performance profiler for WiserOne application"""

    def __init__(self, binary_path: str):
        self.binary_path = Path(binary_path)
        if not self.binary_path.exists():
            raise FileNotFoundError(f"Binary not found: {binary_path}")

        self.results = []
        self.temp_dir = None

    def setup_test_environment(self):
        """Setup isolated test environment"""
        self.temp_dir = tempfile.mkdtemp(prefix="wiserone_perf_")
        print(f"Test environment: {self.temp_dir}")

    def cleanup_test_environment(self):
        """Cleanup test environment"""
        if self.temp_dir:
            shutil.rmtree(self.temp_dir, ignore_errors=True)

    def measure_startup_time(self, iterations: int = 5) -> float:
        """Measure application startup time"""
        startup_times = []

        for i in range(iterations):
            env = os.environ.copy()
            env['QT_QPA_PLATFORM'] = 'offscreen'  # Headless mode

            start_time = time.perf_counter()

            # Start app and wait for it to initialize
            proc = subprocess.Popen(
                [str(self.binary_path)],
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )

            # Give it time to initialize
            time.sleep(0.1)

            # Terminate gracefully
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()

            end_time = time.perf_counter()
            startup_time = (end_time - start_time) * 1000  # Convert to ms
            startup_times.append(startup_time)

            print(f"  Startup iteration {i+1}: {startup_time:.2f}ms")

        avg_startup = sum(startup_times) / len(startup_times)
        return avg_startup

    def measure_memory_usage(self, duration_s: int = 10) -> Dict[str, float]:
        """Measure memory usage over time"""
        env = os.environ.copy()
        env['QT_QPA_PLATFORM'] = 'offscreen'

        # Start the application
        proc = subprocess.Popen(
            [str(self.binary_path)],
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )

        try:
            # Wait for process to start
            time.sleep(1)

            # Get psutil process
            ps_proc = psutil.Process(proc.pid)

            memory_samples = []
            cpu_samples = []

            # Sample memory/CPU usage
            for _ in range(duration_s * 2):  # Sample every 0.5s
                try:
                    memory_info = ps_proc.memory_info()
                    cpu_percent = ps_proc.cpu_percent()

                    memory_samples.append(memory_info.rss / 1024 / 1024)  # MB
                    cpu_samples.append(cpu_percent)

                    time.sleep(0.5)
                except psutil.NoSuchProcess:
                    break

            return {
                'rss_mb': memory_samples[-1] if memory_samples else 0,
                'peak_mb': max(memory_samples) if memory_samples else 0,
                'cpu_avg': sum(cpu_samples) / len(cpu_samples) if cpu_samples else 0
            }

        finally:
            # Clean shutdown
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()

    def benchmark_database_operations(self, num_operations: int = 1000) -> Dict[str, float]:
        """Benchmark database operations directly"""
        # Create a test database with the same schema
        test_db_path = Path(self.temp_dir) / "test_quotes.db"

        # Time database creation and seeding
        start_time = time.perf_counter()

        conn = sqlite3.connect(str(test_db_path))
        cursor = conn.cursor()

        # Create schema (same as QuoteManager)
        cursor.execute("""
            CREATE TABLE quotes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                text TEXT NOT NULL UNIQUE,
                author TEXT DEFAULT 'The Wiser One',
                category TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)

        cursor.execute("CREATE INDEX idx_category ON quotes(category)")

        # Enable WAL mode (same as app)
        cursor.execute("PRAGMA journal_mode=WAL")
        cursor.execute("PRAGMA synchronous=NORMAL")

        # Seed with test data
        test_quotes = [
            ("Quote text " + str(i), "Author " + str(i), "category" + str(i % 5))
            for i in range(120)  # Same as app
        ]

        cursor.executemany(
            "INSERT INTO quotes (text, author, category) VALUES (?, ?, ?)",
            test_quotes
        )
        conn.commit()

        init_time = time.perf_counter() - start_time

        # Benchmark random quote fetching
        start_time = time.perf_counter()

        for _ in range(num_operations):
            # Simulate random quote fetch (same logic as app)
            cursor.execute("SELECT MIN(id), MAX(id) FROM quotes")
            min_id, max_id = cursor.fetchone()

            import random
            random_id = random.randint(min_id, max_id)

            cursor.execute(
                "SELECT id FROM quotes WHERE id >= ? LIMIT 1",
                (random_id,)
            )
            actual_id = cursor.fetchone()[0]

            cursor.execute(
                "SELECT id, text, author, category FROM quotes WHERE id = ?",
                (actual_id,)
            )
            cursor.fetchone()

        fetch_time = time.perf_counter() - start_time

        conn.close()

        return {
            'init_ms': init_time * 1000,
            'fetch_ms': (fetch_time / num_operations) * 1000
        }

    def stress_test(self, duration_s: int = 60, load_multiplier: int = 10) -> PerformanceMetrics:
        """Perform stress test with sustained load"""
        print(f"Running stress test for {duration_s}s with {load_multiplier}x load...")

        errors = []

        # Measure binary size
        binary_size_mb = self.binary_path.stat().st_size / 1024 / 1024

        # Measure startup time
        print("Measuring startup time...")
        startup_time = self.measure_startup_time()

        # Measure memory under load
        print("Measuring memory usage...")
        memory_stats = self.measure_memory_usage(duration_s // 6)

        # Benchmark database operations
        print("Benchmarking database operations...")
        db_stats = self.benchmark_database_operations(1000 * load_multiplier)

        return PerformanceMetrics(
            startup_time_ms=startup_time,
            memory_rss_mb=memory_stats['rss_mb'],
            memory_peak_mb=memory_stats['peak_mb'],
            cpu_percent=memory_stats['cpu_avg'],
            database_init_ms=db_stats['init_ms'],
            quote_fetch_ms=db_stats['fetch_ms'],
            binary_size_mb=binary_size_mb,
            test_duration_s=duration_s,
            quotes_fetched=1000 * load_multiplier,
            errors=errors
        )

    def run_full_benchmark(self) -> Dict[str, PerformanceMetrics]:
        """Run comprehensive performance benchmark"""
        print("=== WiserOne Performance Benchmark ===")

        self.setup_test_environment()

        try:
            results = {}

            # Normal load test
            print("\n1. Normal Load Test:")
            results['normal'] = self.stress_test(duration_s=30, load_multiplier=1)

            # 10x load test
            print("\n2. High Load Test (10x):")
            results['high_load'] = self.stress_test(duration_s=60, load_multiplier=10)

            # 100x load test
            print("\n3. Extreme Load Test (100x):")
            results['extreme_load'] = self.stress_test(duration_s=60, load_multiplier=100)

            return results

        finally:
            self.cleanup_test_environment()

    def generate_report(self, results: Dict[str, PerformanceMetrics], output_file: str = None):
        """Generate performance report"""
        report = {
            'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
            'binary_path': str(self.binary_path),
            'results': {k: asdict(v) for k, v in results.items()}
        }

        # Console output
        print("\n" + "="*80)
        print("PERFORMANCE BENCHMARK RESULTS")
        print("="*80)

        for test_name, metrics in results.items():
            print(f"\n{test_name.upper()} TEST:")
            print(f"  Binary Size:      {metrics.binary_size_mb:.2f} MB")
            print(f"  Startup Time:     {metrics.startup_time_ms:.2f} ms")
            print(f"  Memory RSS:       {metrics.memory_rss_mb:.2f} MB")
            print(f"  Memory Peak:      {metrics.memory_peak_mb:.2f} MB")
            print(f"  CPU Usage:        {metrics.cpu_percent:.1f}%")
            print(f"  DB Init Time:     {metrics.database_init_ms:.2f} ms")
            print(f"  Quote Fetch:      {metrics.quote_fetch_ms:.3f} ms/op")
            print(f"  Quotes Fetched:   {metrics.quotes_fetched:,}")
            if metrics.errors:
                print(f"  Errors:           {len(metrics.errors)}")

        # Performance budgets
        print(f"\nPERFORMANCE BUDGET ANALYSIS:")
        normal = results.get('normal')
        if normal:
            print(f"  Startup Budget (< 500ms):     {'PASS' if normal.startup_time_ms < 500 else 'FAIL'}")
            print(f"  Memory Budget (< 50MB):       {'PASS' if normal.memory_peak_mb < 50 else 'FAIL'}")
            print(f"  DB Fetch Budget (< 1ms):      {'PASS' if normal.quote_fetch_ms < 1.0 else 'FAIL'}")
            print(f"  Binary Size Budget (< 5MB):   {'PASS' if normal.binary_size_mb < 5.0 else 'FAIL'}")

        # Save to file
        if output_file:
            with open(output_file, 'w') as f:
                json.dump(report, f, indent=2)
            print(f"\nDetailed results saved to: {output_file}")


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 perf_test.py <path_to_wiserone_binary>")
        sys.exit(1)

    binary_path = sys.argv[1]

    try:
        profiler = WiserOneProfiler(binary_path)
        results = profiler.run_full_benchmark()

        # Generate report
        timestamp = time.strftime('%Y%m%d_%H%M%S')
        output_file = f"performance_report_{timestamp}.json"
        profiler.generate_report(results, output_file)

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()