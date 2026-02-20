// Stress test for WiserOne quote database operations
// Mimics the QuoteManager operations under heavy load

#include <QtCore/QCoreApplication>
#include <QtSql/QSqlDatabase>
#include <QtSql/QSqlQuery>
#include <QtSql/QSqlError>
#include <QRandomGenerator>
#include <QDir>
#include <QStandardPaths>
#include <QElapsedTimer>
#include <iostream>
#include <chrono>
#include <vector>
#include <algorithm>

class QuoteStressTester {
private:
    QSqlDatabase m_database;
    QString m_dbPath;

    struct TestResults {
        double avgFetchTimeMs = 0.0;
        double maxFetchTimeMs = 0.0;
        double initTimeMs = 0.0;
        int totalQueries = 0;
        int failedQueries = 0;
        double totalTestTimeMs = 0.0;
    };

public:
    QuoteStressTester() {
        // Use temporary database
        m_dbPath = QDir::temp().filePath("stress_test_quotes.db");
        QFile::remove(m_dbPath); // Clean slate

        m_database = QSqlDatabase::addDatabase("QSQLITE", "stress_test");
        m_database.setDatabaseName(m_dbPath);
    }

    ~QuoteStressTester() {
        m_database.close();
        QFile::remove(m_dbPath);
    }

    bool initializeDatabase() {
        QElapsedTimer timer;
        timer.start();

        if (!m_database.open()) {
            std::cerr << "Failed to open database: "
                      << m_database.lastError().text().toStdString() << std::endl;
            return false;
        }

        // Enable WAL mode (same as app)
        QSqlQuery pragma(m_database);
        pragma.exec("PRAGMA journal_mode=WAL");
        pragma.exec("PRAGMA synchronous=NORMAL");
        pragma.exec("PRAGMA cache_size=10000"); // Increase cache for stress test

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

        // Seed with test data (scale up to stress test)
        std::vector<std::tuple<QString, QString, QString>> quotes;
        for (int i = 0; i < 10000; ++i) { // 10k quotes for stress test
            quotes.emplace_back(
                QString("Quote text number %1 with some longer content to simulate real quotes").arg(i),
                QString("Author %1").arg(i % 100), // 100 different authors
                QString("category%1").arg(i % 20)   // 20 categories
            );
        }

        m_database.transaction();
        query.prepare("INSERT INTO quotes (text, author, category) VALUES (?, ?, ?)");

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
        }

        if (!m_database.commit()) {
            std::cerr << "Failed to commit transaction" << std::endl;
            return false;
        }

        auto initTime = timer.elapsed();
        std::cout << "Database initialized with 10,000 quotes in "
                  << initTime << "ms" << std::endl;

        return true;
    }

    TestResults stressTestRandomQueries(int numQueries) {
        std::cout << "Running " << numQueries << " random quote queries..." << std::endl;

        TestResults results;
        std::vector<double> fetchTimes;
        fetchTimes.reserve(numQueries);

        QElapsedTimer totalTimer;
        totalTimer.start();

        QSqlQuery minMaxQuery(m_database);
        if (!minMaxQuery.exec("SELECT MIN(id), MAX(id) FROM quotes") || !minMaxQuery.next()) {
            std::cerr << "Failed to get ID range" << std::endl;
            return results;
        }

        qint64 minId = minMaxQuery.value(0).toLongLong();
        qint64 maxId = minMaxQuery.value(1).toLongLong();

        QSqlQuery fetchQuery(m_database);
        fetchQuery.prepare("SELECT id, text, author, category FROM quotes WHERE id >= ? LIMIT 1");

        for (int i = 0; i < numQueries; ++i) {
            QElapsedTimer fetchTimer;
            fetchTimer.start();

            // Generate random ID (same logic as app)
            qint64 randomId = minId + QRandomGenerator::global()->bounded(
                static_cast<quint32>(maxId - minId + 1));

            fetchQuery.addBindValue(randomId);

            if (fetchQuery.exec() && fetchQuery.next()) {
                // Simulate processing the result
                QString text = fetchQuery.value(1).toString();
                QString author = fetchQuery.value(2).toString();
                QString category = fetchQuery.value(3).toString();

                // Force evaluation to avoid lazy loading optimization
                volatile int len = text.length() + author.length() + category.length();
                Q_UNUSED(len);

                double fetchTime = fetchTimer.elapsed();
                fetchTimes.push_back(fetchTime);
            } else {
                ++results.failedQueries;
                std::cerr << "Query failed: "
                          << fetchQuery.lastError().text().toStdString() << std::endl;
            }

            fetchQuery.finish();

            // Progress indicator
            if ((i + 1) % (numQueries / 10) == 0) {
                std::cout << "  Progress: " << ((i + 1) * 100 / numQueries) << "%" << std::endl;
            }
        }

        results.totalTestTimeMs = totalTimer.elapsed();
        results.totalQueries = numQueries;

        if (!fetchTimes.empty()) {
            results.avgFetchTimeMs = std::accumulate(fetchTimes.begin(), fetchTimes.end(), 0.0) / fetchTimes.size();
            results.maxFetchTimeMs = *std::max_element(fetchTimes.begin(), fetchTimes.end());
        }

        return results;
    }

    TestResults stressCategoryQueries(int numQueries) {
        std::cout << "Running " << numQueries << " category-filtered queries..." << std::endl;

        TestResults results;
        std::vector<double> fetchTimes;
        fetchTimes.reserve(numQueries);

        QElapsedTimer totalTimer;
        totalTimer.start();

        QSqlQuery categoryQuery(m_database);
        categoryQuery.prepare("SELECT id, text, author, category FROM quotes WHERE category = ? ORDER BY RANDOM() LIMIT 1");

        for (int i = 0; i < numQueries; ++i) {
            QElapsedTimer fetchTimer;
            fetchTimer.start();

            QString category = QString("category%1").arg(i % 20); // Cycle through categories
            categoryQuery.addBindValue(category);

            if (categoryQuery.exec() && categoryQuery.next()) {
                // Process result
                QString text = categoryQuery.value(1).toString();
                QString author = categoryQuery.value(2).toString();

                volatile int len = text.length() + author.length();
                Q_UNUSED(len);

                double fetchTime = fetchTimer.elapsed();
                fetchTimes.push_back(fetchTime);
            } else {
                ++results.failedQueries;
            }

            categoryQuery.finish();

            if ((i + 1) % (numQueries / 10) == 0) {
                std::cout << "  Progress: " << ((i + 1) * 100 / numQueries) << "%" << std::endl;
            }
        }

        results.totalTestTimeMs = totalTimer.elapsed();
        results.totalQueries = numQueries;

        if (!fetchTimes.empty()) {
            results.avgFetchTimeMs = std::accumulate(fetchTimes.begin(), fetchTimes.end(), 0.0) / fetchTimes.size();
            results.maxFetchTimeMs = *std::max_element(fetchTimes.begin(), fetchTimes.end());
        }

        return results;
    }

    void printResults(const std::string& testName, const TestResults& results) {
        std::cout << "\n=== " << testName << " RESULTS ===" << std::endl;
        std::cout << "Total queries: " << results.totalQueries << std::endl;
        std::cout << "Failed queries: " << results.failedQueries << std::endl;
        std::cout << "Success rate: " << (100.0 * (results.totalQueries - results.failedQueries) / results.totalQueries) << "%" << std::endl;
        std::cout << "Average fetch time: " << results.avgFetchTimeMs << " ms" << std::endl;
        std::cout << "Maximum fetch time: " << results.maxFetchTimeMs << " ms" << std::endl;
        std::cout << "Total test time: " << results.totalTestTimeMs << " ms" << std::endl;
        std::cout << "Queries per second: " << (results.totalQueries * 1000.0 / results.totalTestTimeMs) << std::endl;

        // Performance budget checks
        std::cout << "\nPERFORMANCE BUDGET:" << std::endl;
        std::cout << "  Avg fetch < 1ms: " << (results.avgFetchTimeMs < 1.0 ? "PASS" : "FAIL") << std::endl;
        std::cout << "  Max fetch < 10ms: " << (results.maxFetchTimeMs < 10.0 ? "PASS" : "FAIL") << std::endl;
        std::cout << "  Success rate > 99%: " << ((results.totalQueries - results.failedQueries) * 100.0 / results.totalQueries > 99.0 ? "PASS" : "FAIL") << std::endl;
    }
};

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);

    std::cout << "=== WiserOne Database Stress Test ===" << std::endl;

    QuoteStressTester tester;

    if (!tester.initializeDatabase()) {
        std::cerr << "Failed to initialize database" << std::endl;
        return 1;
    }

    // Normal load test (1000 queries)
    auto normalResults = tester.stressTestRandomQueries(1000);
    tester.printResults("NORMAL LOAD (1K queries)", normalResults);

    // High load test (10,000 queries)
    auto highResults = tester.stressTestRandomQueries(10000);
    tester.printResults("HIGH LOAD (10K queries)", highResults);

    // Category query stress test
    auto categoryResults = tester.stressCategoryQueries(5000);
    tester.printResults("CATEGORY QUERIES (5K)", categoryResults);

    std::cout << "\n=== SUMMARY ===" << std::endl;
    std::cout << "Database stress testing completed successfully!" << std::endl;

    return 0;
}