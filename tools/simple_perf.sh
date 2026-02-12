#!/bin/bash
# Simple performance benchmarking for WiserOne using system tools

set -euo pipefail

BINARY="${1:-build-release/wiserone}"
REPORT_FILE="performance_baseline_$(date +%Y%m%d_%H%M%S).md"

if [[ ! -f "$BINARY" ]]; then
    echo "Error: Binary not found: $BINARY"
    exit 1
fi

echo "# WiserOne Performance Baseline Report" > "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Binary size analysis
echo "## Binary Analysis" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
echo "Binary size: $(du -h "$BINARY" | cut -f1)" >> "$REPORT_FILE"
echo "Strip status: $(file "$BINARY" | grep -o 'stripped\|not stripped')" >> "$REPORT_FILE"
echo "Binary info: $(file "$BINARY")" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Check for debug symbols
if readelf -S "$BINARY" | grep -q debug; then
    echo "⚠️  **WARNING: Binary contains debug symbols**" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
fi

# Memory analysis using valgrind (if available)
echo "## Memory Analysis" >> "$REPORT_FILE"

if command -v valgrind &> /dev/null; then
    echo "Running memory leak detection..." >&2

    # Create temp home dir for Qt settings
    TEMP_HOME=$(mktemp -d)

    timeout 10s valgrind \
        --tool=memcheck \
        --leak-check=full \
        --show-leak-kinds=all \
        --track-origins=yes \
        --verbose \
        --log-file=valgrind.log \
        env QT_QPA_PLATFORM=offscreen HOME="$TEMP_HOME" \
        "$BINARY" 2>/dev/null || true

    if [[ -f valgrind.log ]]; then
        echo '```' >> "$REPORT_FILE"
        echo "Memory leak summary:" >> "$REPORT_FILE"
        grep -A 10 "LEAK SUMMARY" valgrind.log >> "$REPORT_FILE" || true
        echo "" >> "$REPORT_FILE"
        echo "Error summary:" >> "$REPORT_FILE"
        grep "ERROR SUMMARY" valgrind.log >> "$REPORT_FILE" || true
        echo '```' >> "$REPORT_FILE"
        rm -f valgrind.log
    fi

    rm -rf "$TEMP_HOME"
else
    echo "Valgrind not available - skipping memory leak detection" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

# Startup time measurement
echo "## Startup Performance" >> "$REPORT_FILE"
echo "Measuring application startup time..." >&2

startup_times=()
for i in {1..5}; do
    start=$(date +%s.%N)

    timeout 2s env QT_QPA_PLATFORM=offscreen "$BINARY" 2>/dev/null &
    pid=$!

    # Wait for process to start properly
    sleep 0.1

    # Kill the process
    kill $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true

    end=$(date +%s.%N)
    startup_time=$(echo "$end - $start" | bc -l)
    startup_times+=($startup_time)

    echo "  Run $i: ${startup_time}s" >&2
done

echo '```' >> "$REPORT_FILE"
echo "Startup time measurements (5 runs):" >> "$REPORT_FILE"
for i in "${!startup_times[@]}"; do
    ms=$(echo "${startup_times[$i]} * 1000" | bc -l)
    printf "Run %d: %.2f ms\n" $((i+1)) "$ms" >> "$REPORT_FILE"
done

# Calculate average
avg=$(echo "${startup_times[*]}" | awk '{sum=0; for(i=1;i<=NF;i++)sum+=$i; print sum/NF}')
avg_ms=$(echo "$avg * 1000" | bc -l)
printf "Average: %.2f ms\n" "$avg_ms" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Performance budget check
if (( $(echo "$avg_ms < 500" | bc -l) )); then
    echo "✅ **Startup time budget: PASS** (< 500ms)" >> "$REPORT_FILE"
else
    echo "❌ **Startup time budget: FAIL** (>= 500ms)" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

# Build configuration analysis
echo "## Build Configuration" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"

# Check compiler flags from CMake
if [[ -f build-release/CMakeCache.txt ]]; then
    echo "CMake build type:" >> "$REPORT_FILE"
    grep "CMAKE_BUILD_TYPE" build-release/CMakeCache.txt >> "$REPORT_FILE" || true
    echo "" >> "$REPORT_FILE"

    echo "Compiler flags:" >> "$REPORT_FILE"
    grep "CMAKE_CXX_FLAGS" build-release/CMakeCache.txt | head -3 >> "$REPORT_FILE" || true
fi

echo '```' >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Dependencies analysis
echo "## Dependencies" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
echo "Dynamic libraries:" >> "$REPORT_FILE"
ldd "$BINARY" | head -10 >> "$REPORT_FILE"
echo "..." >> "$REPORT_FILE"
echo "Total libraries: $(ldd "$BINARY" | wc -l)" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Size analysis by section
echo "## Binary Size Breakdown" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
size "$BINARY" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Performance recommendations
echo "## Performance Budget Status" >> "$REPORT_FILE"

binary_size_mb=$(du -m "$BINARY" | cut -f1)

echo "| Metric | Current | Budget | Status |" >> "$REPORT_FILE"
echo "|--------|---------|--------|--------|" >> "$REPORT_FILE"
echo "| Startup Time | ${avg_ms} ms | < 500 ms | $( [[ $(echo "$avg_ms < 500" | bc -l) == 1 ]] && echo "✅ PASS" || echo "❌ FAIL" ) |" >> "$REPORT_FILE"
echo "| Binary Size | ${binary_size_mb} MB | < 5 MB | $( [[ $binary_size_mb -lt 5 ]] && echo "✅ PASS" || echo "❌ FAIL" ) |" >> "$REPORT_FILE"

# Check if stripped
if file "$BINARY" | grep -q "not stripped"; then
    echo "| Debug Symbols | Present | Stripped | ❌ FAIL |" >> "$REPORT_FILE"
else
    echo "| Debug Symbols | Stripped | Stripped | ✅ PASS |" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

echo "Report saved to: $REPORT_FILE"
echo "Current baseline established!"

# Show quick summary
echo ""
echo "=== QUICK SUMMARY ==="
printf "Startup time: %.2f ms (avg)\n" "$avg_ms"
echo "Binary size: $(du -h "$BINARY" | cut -f1)"
echo "Report: $REPORT_FILE"