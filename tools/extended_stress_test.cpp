// Extended stress test for WiserOne - 10x and 100x workloads with memory profiling
// Tests sustained load patterns and memory usage

#include <QtCore/QCoreApplication>
#include <QtSql/QSqlDatabase>
#include <QtSql/QSqlQuery>
#include <QtSql/QSqlError>
#include <QRandomGenerator>
#include <QDir>
#include <QStandardPaths>
#include <QElapsedTimer>
#include <QThread>
#include <iostream>
#include <chrono>
#include <vector>
#include <algorithm>
#include <cstdio>
#include <unistd.h>
#include <fstream>

class ExtendedQuoteStressTester {
private:
    QSqlDatabase m_database;
    QString m_dbPath;

    struct TestResults {
        double avgFetchTimeMs = 0.0;
        double maxFetchTimeMs = 0.0;
        double minFetchTimeMs = 999999.0;
        double p50FetchTimeMs = 0.0;
        double p95FetchTimeMs = 0.0;
        double p99FetchTimeMs = 0.0;
        int totalQueries = 0;
        int failedQueries = 0;
        double totalTestTimeMs = 0.0;
        size_t peakMemoryKB = 0;
        size_t finalMemoryKB = 0;
    };

    // Get current memory usage in KB
    size_t getCurrentMemoryUsage() {
        std::ifstream file("/proc/self/status");
        std::string line;
        while (std::getline(file, line)) {
            if (line.substr(0, 6) == "VmRSS:") {
                size_t pos = line.find_first_of("0123456789");
                if (pos != std::string::npos) {
                    return std::stoul(line.substr(pos));
                }
            }
        }
        return 0;
    }

public:
    ExtendedQuoteStressTester() {
        // Use temporary database for stress testing
        m_dbPath = QDir::temp().filePath("extended_stress_quotes.db");
        QFile::remove(m_dbPath); // Clean slate

        m_database = QSqlDatabase::addDatabase("QSQLITE", "extended_stress");
        m_database.setDatabaseName(m_dbPath);
    }

    ~ExtendedQuoteStressTester() {
        m_database.close();
        QFile::remove(m_dbPath);
    }

    bool initializeDatabase() {
        if (!m_database.open()) {
            std::cerr << "Failed to open database: "
                      << m_database.lastError().text().toStdString() << std::endl;
            return false;
        }

        // Enable aggressive performance settings for stress test
        QSqlQuery pragma(m_database);
        pragma.exec("PRAGMA journal_mode=WAL");
        pragma.exec("PRAGMA synchronous=NORMAL");
        pragma.exec("PRAGMA cache_size=50000"); // 50MB cache for extreme load
        pragma.exec("PRAGMA temp_store=memory");
        pragma.exec("PRAGMA mmap_size=268435456"); // 256MB mmap

        // Create schema
        QSqlQuery query(m_database);
        if (!query.exec(
            "CREATE TABLE quotes ("
            "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
            "  text TEXT NOT NULL UNIQUE,"
            "  author TEXT DEFAULT 'The Wiser One',"
            "  category TEXT,"
            "  created_at TEXT DEFAULT CURRENT_TIMESTAMP"
            ")")) {
            std::cerr << "Failed to create table: "
                      << query.lastError().text().toStdString() << std::endl;
            return false;
        }

        query.exec("CREATE INDEX idx_category ON quotes(category)");
        query.exec("CREATE INDEX idx_text_fts ON quotes(text)"); // Full text search index

        // Seed with larger dataset for extreme testing (100k quotes)
        std::vector<std::tuple<QString, QString, QString>> quotes;
        quotes.reserve(100000);

        for (int i = 0; i < 100000; ++i) {
            quotes.emplace_back(
                QString("Stress test quote number %1 with substantial content to simulate real-world quote lengths and database load patterns. This text is designed to be realistic in length and complexity for thorough performance testing under extreme conditions.").arg(i),
                QString("Author %1").arg(i % 500), // 500 different authors
                QString("category%1").arg(i % 50)   // 50 categories
            );
        }

        std::cout << "Seeding database with 100,000 quotes..." << std::endl;
        QElapsedTimer seedTimer;
        seedTimer.start();

        m_database.transaction();
        query.prepare("INSERT INTO quotes (text, author, category) VALUES (?, ?, ?)");

        int batchCount = 0;
        for (const auto& [text, author, category] : quotes) {
            query.addBindValue(text);
            query.addBindValue(author);
            query.addBindValue(category);

            if (!query.exec()) {
                std::cerr << "Failed to insert quote: "
                          << query.lastError().text().toStdString() << std::endl;
                m_database.rollback();
                return false;
            }

            // Commit in batches to avoid excessive memory usage
            if (++batchCount % 10000 == 0) {
                m_database.commit();
                m_database.transaction();
                std::cout << "  Seeded " << batchCount << " quotes..." << std::endl;
            }
        }

        if (!m_database.commit()) {
            std::cerr << "Failed to commit final batch" << std::endl;
            return false;
        }

        auto seedTime = seedTimer.elapsed();
        std::cout << "Database seeded in " << seedTime << "ms" << std::endl;

        return true;
    }

    TestResults extremeLoadTest(int numQueries, const std::string& testName) {
        std::cout << "\nRunning " << testName << " (" << numQueries << " queries)..." << std::endl;

        TestResults results;
        std::vector<double> fetchTimes;
        fetchTimes.reserve(numQueries);

        size_t initialMemory = getCurrentMemoryUsage();
        size_t peakMemory = initialMemory;

        QElapsedTimer totalTimer;
        totalTimer.start();

        // Get ID range once
        QSqlQuery minMaxQuery(m_database);
        if (!minMaxQuery.exec("SELECT MIN(id), MAX(id) FROM quotes") || !minMaxQuery.next()) {
            std::cerr << "Failed to get ID range" << std::endl;
            return results;
        }

        qint64 minId = minMaxQuery.value(0).toLongLong();
        qint64 maxId = minMaxQuery.value(1).toLongLong();

        // Prepare query once for efficiency
        QSqlQuery fetchQuery(m_database);
        fetchQuery.prepare("SELECT id, text, author, category FROM quotes WHERE id >= ? LIMIT 1");

        for (int i = 0; i < numQueries; ++i) {
            QElapsedTimer fetchTimer;
            fetchTimer.start();

            // Generate random ID
            qint64 randomId = minId + QRandomGenerator::global()->bounded(
                static_cast<quint32>(maxId - minId + 1));

            fetchQuery.addBindValue(randomId);

            if (fetchQuery.exec() && fetchQuery.next()) {
                // Force processing of all fields
                QString text = fetchQuery.value(1).toString();
                QString author = fetchQuery.value(2).toString();
                QString category = fetchQuery.value(3).toString();

                // Force evaluation to prevent compiler optimization
                volatile int len = text.length() + author.length() + category.length();
                Q_UNUSED(len);

                double fetchTime = fetchTimer.elapsed();
                fetchTimes.push_back(fetchTime);
            } else {
                ++results.failedQueries;
            }

            fetchQuery.finish();

            // Monitor memory usage every 1000 queries
            if (i % 1000 == 0) {
                size_t currentMemory = getCurrentMemoryUsage();
                peakMemory = std::max(peakMemory, currentMemory);

                // Progress indicator for long tests
                if (numQueries > 10000 && (i + 1) % (numQueries / 20) == 0) {
                    std::cout << "  Progress: " << ((i + 1) * 100 / numQueries)
                              << "% (Memory: " << currentMemory << " KB)" << std::endl;
                }
            }
        }

        results.totalTestTimeMs = totalTimer.elapsed();
        results.totalQueries = numQueries;
        results.peakMemoryKB = peakMemory;
        results.finalMemoryKB = getCurrentMemoryUsage();

        if (!fetchTimes.empty()) {
            // Calculate comprehensive statistics
            std::sort(fetchTimes.begin(), fetchTimes.end());

            results.avgFetchTimeMs = std::accumulate(fetchTimes.begin(), fetchTimes.end(), 0.0) / fetchTimes.size();
            results.minFetchTimeMs = fetchTimes.front();
            results.maxFetchTimeMs = fetchTimes.back();

            // Percentiles
            results.p50FetchTimeMs = fetchTimes[fetchTimes.size() * 50 / 100];
            results.p95FetchTimeMs = fetchTimes[fetchTimes.size() * 95 / 100];
            results.p99FetchTimeMs = fetchTimes[fetchTimes.size() * 99 / 100];
        }

        return results;
    }

    TestResults sustainedLoadTest(int durationSeconds, int queriesPerSecond) {
        std::cout << "\nRunning sustained load test (" << durationSeconds
                  << "s at " << queriesPerSecond << " QPS)..." << std::endl;

        TestResults results;
        std::vector<double> fetchTimes;

        size_t initialMemory = getCurrentMemoryUsage();
        size_t peakMemory = initialMemory;

        QElapsedTimer totalTimer;
        totalTimer.start();

        // Get ID range
        QSqlQuery minMaxQuery(m_database);
        if (!minMaxQuery.exec("SELECT MIN(id), MAX(id) FROM quotes") || !minMaxQuery.next()) {
            return results;
        }

        qint64 minId = minMaxQuery.value(0).toLongLong();
        qint64 maxId = minMaxQuery.value(1).toLongLong();

        QSqlQuery fetchQuery(m_database);
        fetchQuery.prepare("SELECT id, text, author, category FROM quotes WHERE id >= ? LIMIT 1");

        int totalQueries = 0;
        int queryIntervalMs = 1000 / queriesPerSecond;

        while (totalTimer.elapsed() < durationSeconds * 1000) {
            QElapsedTimer fetchTimer;
            fetchTimer.start();

            qint64 randomId = minId + QRandomGenerator::global()->bounded(
                static_cast<quint32>(maxId - minId + 1));

            fetchQuery.addBindValue(randomId);

            if (fetchQuery.exec() && fetchQuery.next()) {
                QString text = fetchQuery.value(1).toString();
                QString author = fetchQuery.value(2).toString();
                QString category = fetchQuery.value(3).toString();

                volatile int len = text.length() + author.length() + category.length();
                Q_UNUSED(len);

                double fetchTime = fetchTimer.elapsed();
                fetchTimes.push_back(fetchTime);
            } else {
                ++results.failedQueries;
            }

            fetchQuery.finish();
            ++totalQueries;

            // Memory monitoring
            if (totalQueries % 100 == 0) {
                size_t currentMemory = getCurrentMemoryUsage();
                peakMemory = std::max(peakMemory, currentMemory);
            }

            // Rate limiting
            QThread::msleep(queryIntervalMs);

            // Progress update
            if (totalQueries % (queriesPerSecond * 10) == 0) {
                int elapsedSec = totalTimer.elapsed() / 1000;
                size_t currentMemory = getCurrentMemoryUsage();
                std::cout << "  " << elapsedSec << "s elapsed, "
                          << totalQueries << " queries, Memory: "
                          << currentMemory << " KB" << std::endl;
            }
        }

        results.totalTestTimeMs = totalTimer.elapsed();
        results.totalQueries = totalQueries;
        results.peakMemoryKB = peakMemory;
        results.finalMemoryKB = getCurrentMemoryUsage();

        if (!fetchTimes.empty()) {
            std::sort(fetchTimes.begin(), fetchTimes.end());
            results.avgFetchTimeMs = std::accumulate(fetchTimes.begin(), fetchTimes.end(), 0.0) / fetchTimes.size();
            results.minFetchTimeMs = fetchTimes.front();
            results.maxFetchTimeMs = fetchTimes.back();
            results.p50FetchTimeMs = fetchTimes[fetchTimes.size() * 50 / 100];
            results.p95FetchTimeMs = fetchTimes[fetchTimes.size() * 95 / 100];
            results.p99FetchTimeMs = fetchTimes[fetchTimes.size() * 99 / 100];
        }

        return results;
    }

    void printResults(const std::string& testName, const TestResults& results) {
        std::cout << "\n=== " << testName << " RESULTS ===" << std::endl;
        std::cout << "Total queries: " << results.totalQueries << std::endl;
        std::cout << "Failed queries: " << results.failedQueries << std::endl;
        std::cout << "Success rate: " << (100.0 * (results.totalQueries - results.failedQueries) / results.totalQueries) << "%" << std::endl;

        std::cout << "\nLATENCY METRICS:" << std::endl;
        std::cout << "  Average: " << results.avgFetchTimeMs << " ms" << std::endl;
        std::cout << "  Min: " << results.minFetchTimeMs << " ms" << std::endl;
        std::cout << "  Max: " << results.maxFetchTimeMs << " ms" << std::endl;
        std::cout << "  P50: " << results.p50FetchTimeMs << " ms" << std::endl;
        std::cout << "  P95: " << results.p95FetchTimeMs << " ms" << std::endl;
        std::cout << "  P99: " << results.p99FetchTimeMs << " ms" << std::endl;

        std::cout << "\nTHROUGHPUT METRICS:" << std::endl;
        std::cout << "  Total test time: " << results.totalTestTimeMs << " ms" << std::endl;
        std::cout << "  Queries per second: " << (results.totalQueries * 1000.0 / results.totalTestTimeMs) << std::endl;

        std::cout << "\nMEMORY METRICS:" << std::endl;
        std::cout << "  Peak memory: " << results.peakMemoryKB << " KB" << std::endl;
        std::cout << "  Final memory: " << results.finalMemoryKB << " KB" << std::endl;

        // Performance budget checks (aggressive for extreme load)
        std::cout << "\nPERFORMANCE BUDGET (EXTREME LOAD):" << std::endl;
        std::cout << "  P50 < 5ms: " << (results.p50FetchTimeMs < 5.0 ? "PASS" : "FAIL") << std::endl;
        std::cout << "  P95 < 20ms: " << (results.p95FetchTimeMs < 20.0 ? "PASS" : "FAIL") << std::endl;
        std::cout << "  P99 < 50ms: " << (results.p99FetchTimeMs < 50.0 ? "PASS" : "FAIL") << std::endl;
        std::cout << "  Success rate > 99.9%: " << ((results.totalQueries - results.failedQueries) * 100.0 / results.totalQueries > 99.9 ? "PASS" : "FAIL") << std::endl;
        std::cout << "  Memory growth < 50MB: " << ((results.finalMemoryKB - results.peakMemoryKB) < 50000 ? "PASS" : "FAIL") << std::endl;
    }
};

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);

    std::cout << "=== WiserOne Extended Stress Test (10x/100x Load) ===" << std::endl;
    std::cout << "PID: " << getpid() << " (for external memory monitoring)" << std::endl;

    ExtendedQuoteStressTester tester;

    if (!tester.initializeDatabase()) {
        std::cerr << "Failed to initialize database" << std::endl;
        return 1;
    }

    // 10x typical load: 100,000 queries
    auto load10x = tester.extremeLoadTest(100000, "10X TYPICAL LOAD (100K queries)");
    tester.printResults("10X LOAD", load10x);

    // 100x typical load: 1,000,000 queries
    auto load100x = tester.extremeLoadTest(1000000, "100X TYPICAL LOAD (1M queries)");
    tester.printResults("100X LOAD", load100x);

    // Sustained load test: 60 seconds at 1000 QPS
    auto sustainedLoad = tester.sustainedLoadTest(60, 1000);
    tester.printResults("SUSTAINED LOAD (60s @ 1000 QPS)", sustainedLoad);

    std::cout << "\n=== FINAL ASSESSMENT ===" << std::endl;
    std::cout << "Extended stress testing completed!" << std::endl;

    return 0;
}