// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#include "ErrorLogger.h"

#include <QFile>
#include <QTextStream>
#include <QtConcurrent>
#include <QtTest>

class TestErrorLogger : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void cleanupTestCase();
    void cleanup();

    void testSingletonInstance();
    void testLogFilePath();
    void testLogCreatesFile();
    void testLogWritesCorrectFormat();
    void testLogWithQStringView();
    void testTryLog();
    void testClearLog();
    void testMultipleLogEntries();
    void testThreadSafety();

private:
    [[nodiscard]] QString readLogFile();
    QString m_originalLogPath;
};

void TestErrorLogger::initTestCase()
{
    m_originalLogPath = ErrorLogger::instance().logFilePath();
}

void TestErrorLogger::cleanupTestCase()
{
    // Clean up test log file
    std::ignore = ErrorLogger::instance().clearLog();
}

void TestErrorLogger::cleanup()
{
    // Clear log after each test
    std::ignore = ErrorLogger::instance().clearLog();
}

QString TestErrorLogger::readLogFile()
{
    QFile file(ErrorLogger::instance().logFilePath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }
    return QTextStream(&file).readAll();
}

void TestErrorLogger::testSingletonInstance()
{
    ErrorLogger& instance1 = ErrorLogger::instance();
    ErrorLogger& instance2 = ErrorLogger::instance();

    QCOMPARE(&instance1, &instance2);
}

void TestErrorLogger::testLogFilePath()
{
    const QString path = ErrorLogger::instance().logFilePath();

    QVERIFY(!path.isEmpty());
    QVERIFY(path.endsWith(QLatin1String("appLog.txt")));
}

void TestErrorLogger::testLogCreatesFile()
{
    std::ignore = ErrorLogger::instance().clearLog();

    ErrorLogger::instance().log(
        QStringLiteral("TestFile.cpp"),
        QStringLiteral("testMethod"),
        QStringLiteral("Test error message"));

    QFile logFile(ErrorLogger::instance().logFilePath());
    QVERIFY(logFile.exists());
}

void TestErrorLogger::testLogWritesCorrectFormat()
{
    ErrorLogger::instance().log(
        QStringLiteral("TestFile.cpp"),
        QStringLiteral("testMethod"),
        QStringLiteral("Test error"));

    const QString content = readLogFile();

    QVERIFY(content.contains(QLatin1String("File: TestFile.cpp")));
    QVERIFY(content.contains(QLatin1String("Method: testMethod")));
    QVERIFY(content.contains(QLatin1String("Error: Test error")));
    // Should have timestamp format YYYY-MM-DD HH:mm:ss
    QVERIFY(content.contains(QRegularExpression(QStringLiteral(R"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})"))));
}

void TestErrorLogger::testLogWithQStringView()
{
    ErrorLogger::instance().log(
        QStringView(u"ViewFile.cpp"),
        QStringView(u"viewMethod"),
        QStringLiteral("View error"));

    const QString content = readLogFile();

    QVERIFY(content.contains(QLatin1String("File: ViewFile.cpp")));
    QVERIFY(content.contains(QLatin1String("Method: viewMethod")));
}

void TestErrorLogger::testTryLog()
{
    auto result = ErrorLogger::instance().tryLog(
        QStringView(u"TryFile.cpp"),
        QStringView(u"tryMethod"),
        QStringLiteral("Try error"));

    QVERIFY(result.has_value());

    const QString content = readLogFile();
    QVERIFY(content.contains(QLatin1String("File: TryFile.cpp")));
}

void TestErrorLogger::testClearLog()
{
    ErrorLogger::instance().log(
        QStringLiteral("Test.cpp"),
        QStringLiteral("test"),
        QStringLiteral("error"));

    QFile logFile(ErrorLogger::instance().logFilePath());
    QVERIFY(logFile.exists());

    auto result = ErrorLogger::instance().clearLog();
    QVERIFY(result.has_value());

    QVERIFY(!logFile.exists());
}

void TestErrorLogger::testMultipleLogEntries()
{
    constexpr int NUM_ENTRIES = 5;

    for (int i = 0; i < NUM_ENTRIES; ++i) {
        ErrorLogger::instance().log(
            QStringLiteral("Test.cpp"),
            QStringLiteral("test"),
            QStringLiteral("Error %1").arg(i));
    }

    const QString content = readLogFile();
    const auto lineCount = content.count(QLatin1Char('\n'));

    QCOMPARE(lineCount, NUM_ENTRIES);
}

void TestErrorLogger::testThreadSafety()
{
    constexpr int NUM_THREADS = 4;
    constexpr int LOGS_PER_THREAD = 25;

    QList<QFuture<void>> futures;

    for (int t = 0; t < NUM_THREADS; ++t) {
        futures.append(QtConcurrent::run([t]() {
            for (int i = 0; i < LOGS_PER_THREAD; ++i) {
                ErrorLogger::instance().log(
                    QStringLiteral("Thread%1.cpp").arg(t),
                    QStringLiteral("method"),
                    QStringLiteral("Log entry %1").arg(i));
            }
        }));
    }

    for (auto& future : futures) {
        future.waitForFinished();
    }

    const QString content = readLogFile();
    const auto lineCount = content.count(QLatin1Char('\n'));

    QCOMPARE(lineCount, NUM_THREADS * LOGS_PER_THREAD);
}

QTEST_MAIN(TestErrorLogger)
#include "tst_errorlogger.moc"
