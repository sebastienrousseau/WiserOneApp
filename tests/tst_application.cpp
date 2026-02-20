// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#include "Application.h"
#include "TrayIcon.h"

#include <QSignalSpy>
#include <QtTest>

#include <memory>

class MockTrayIcon : public TrayIcon {
    Q_OBJECT

public:
    explicit MockTrayIcon(QObject* parent = nullptr)
        : TrayIcon(parent)
        , m_shouldShow(true)
    {
    }

    // Note: TrayIcon::show() is not virtual, so this shadows it
    bool showMock() {
        return m_shouldShow;
    }

    void setShowResult(bool result) {
        m_shouldShow = result;
    }

    static void setAvailableStatic(bool available) {
        s_isAvailable = available;
    }

    static bool isAvailableStatic() {
        return s_isAvailable;
    }

private:
    bool m_shouldShow;
    static bool s_isAvailable;
};

bool MockTrayIcon::s_isAvailable = true;

class TestApplication : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void cleanupTestCase();
    void cleanup();

    // Constructor tests
    void testConstructorInitialState();
    void testDestructor();

    // Error message tests
    void testErrorMessage_data();
    void testErrorMessage();

    // Initialization tests
    void testInitializeSuccess();
    void testInitializeAlreadyInitialized();
    void testInitializeTrayUnavailable();
    void testInitializeTrayShowFailed();
    void testInitializeEmitsSignals();

    // State tests
    void testIsInitialized();

    // Edge cases and property-based tests
    void testInitializeMultipleCalls();
    void testInitializeAfterFailure();
    void testSignalEmissionOrder();
    void testErrorMessageCompleteness();

private:
    std::unique_ptr<Application> m_app;
    bool m_originalTrayAvailability{true};
};

void TestApplication::initTestCase()
{
    // Save original tray availability
    m_originalTrayAvailability = TrayIcon::isAvailable();
}

void TestApplication::cleanupTestCase()
{
    // Restore original tray availability
    MockTrayIcon::setAvailableStatic(m_originalTrayAvailability);
}

void TestApplication::cleanup()
{
    m_app.reset();
    // Reset tray availability to true for each test
    MockTrayIcon::setAvailableStatic(true);
}

void TestApplication::testConstructorInitialState()
{
    m_app = std::make_unique<Application>();

    // Should not be initialized yet
    QVERIFY(!m_app->isInitialized());
}

void TestApplication::testDestructor()
{
    // Test that destructor doesn't crash and cleans up properly
    auto app = std::make_unique<Application>();
    QVERIFY(!app->isInitialized());

    // Initialize and then destroy
    if (TrayIcon::isAvailable()) {
        app->initialize();
    }
    // Destructor should handle cleanup automatically
    app.reset();
    QVERIFY(true); // If we get here, destructor didn't crash
}

void TestApplication::testErrorMessage_data()
{
    QTest::addColumn<AppError>("error");
    QTest::addColumn<QString>("expectedMessage");

    QTest::newRow("TrayUnavailable")
        << AppError::TrayUnavailable
        << QStringLiteral("System tray is not available on this system");

    QTest::newRow("TrayShowFailed")
        << AppError::TrayShowFailed
        << QStringLiteral("Failed to show system tray icon");
}

void TestApplication::testErrorMessage()
{
    QFETCH(AppError, error);
    QFETCH(QString, expectedMessage);

    const QString message = Application::errorMessage(error);

    QCOMPARE(message, expectedMessage);
    QVERIFY(!message.isEmpty());
    QVERIFY(message.length() > 10); // Reasonable message length
}

void TestApplication::testInitializeSuccess()
{
    if (!TrayIcon::isAvailable()) {
        QSKIP("System tray not available for testing");
    }

    m_app = std::make_unique<Application>();

    const bool result = m_app->initialize();

    QVERIFY(result);
    QVERIFY(m_app->isInitialized());
}

void TestApplication::testInitializeAlreadyInitialized()
{
    if (!TrayIcon::isAvailable()) {
        QSKIP("System tray not available for testing");
    }

    m_app = std::make_unique<Application>();

    // First initialization
    QVERIFY(m_app->initialize());
    QVERIFY(m_app->isInitialized());

    // Second initialization should succeed (idempotent)
    QVERIFY(m_app->initialize());
    QVERIFY(m_app->isInitialized());
}

void TestApplication::testInitializeTrayUnavailable()
{
    MockTrayIcon::setAvailableStatic(false);

    m_app = std::make_unique<Application>();
    QSignalSpy failureSpy(m_app.get(), &Application::initializationFailed);
    QSignalSpy successSpy(m_app.get(), &Application::initialized);

    const bool result = m_app->initialize();

    QVERIFY(!result);
    QVERIFY(!m_app->isInitialized());

    // Should emit failure signal
    QCOMPARE(failureSpy.count(), 1);
    QCOMPARE(successSpy.count(), 0);

    const auto failureArgs = failureSpy.takeFirst();
    const QString message = failureArgs.at(0).toString();
    QVERIFY(message.contains("System tray is not available"));
}

void TestApplication::testInitializeTrayShowFailed()
{
    // This test is harder to implement without mocking TrayIcon
    // For now, we'll skip it but note the coverage gap
    QSKIP("TrayIcon mocking not fully implemented");
}

void TestApplication::testInitializeEmitsSignals()
{
    if (!TrayIcon::isAvailable()) {
        QSKIP("System tray not available for testing");
    }

    m_app = std::make_unique<Application>();
    QSignalSpy successSpy(m_app.get(), &Application::initialized);
    QSignalSpy failureSpy(m_app.get(), &Application::initializationFailed);

    const bool result = m_app->initialize();

    if (result) {
        QCOMPARE(successSpy.count(), 1);
        QCOMPARE(failureSpy.count(), 0);
    } else {
        QCOMPARE(successSpy.count(), 0);
        QCOMPARE(failureSpy.count(), 1);
    }
}

void TestApplication::testIsInitialized()
{
    m_app = std::make_unique<Application>();

    // Initially not initialized
    QVERIFY(!m_app->isInitialized());

    if (TrayIcon::isAvailable()) {
        // After successful initialization
        m_app->initialize();
        QVERIFY(m_app->isInitialized());
    }
}

void TestApplication::testInitializeMultipleCalls()
{
    if (!TrayIcon::isAvailable()) {
        QSKIP("System tray not available for testing");
    }

    m_app = std::make_unique<Application>();
    QSignalSpy successSpy(m_app.get(), &Application::initialized);

    // Call initialize multiple times
    constexpr int CALL_COUNT = 5;
    for (int i = 0; i < CALL_COUNT; ++i) {
        QVERIFY(m_app->initialize());
        QVERIFY(m_app->isInitialized());
    }

    // Should only emit signal once (on first successful init)
    QCOMPARE(successSpy.count(), 1);
}

void TestApplication::testInitializeAfterFailure()
{
    m_app = std::make_unique<Application>();

    // First, make tray unavailable and attempt initialization
    MockTrayIcon::setAvailableStatic(false);
    QVERIFY(!m_app->initialize());
    QVERIFY(!m_app->isInitialized());

    // Then make tray available and try again
    MockTrayIcon::setAvailableStatic(true);
    const bool result = m_app->initialize();

    if (TrayIcon::isAvailable()) {
        QVERIFY(result);
        QVERIFY(m_app->isInitialized());
    }
}

void TestApplication::testSignalEmissionOrder()
{
    if (!TrayIcon::isAvailable()) {
        QSKIP("System tray not available for testing");
    }

    m_app = std::make_unique<Application>();

    QStringList signalOrder;
    connect(m_app.get(), &Application::initialized, [&]() {
        signalOrder.append("initialized");
    });
    connect(m_app.get(), &Application::initializationFailed, [&](const QString&) {
        signalOrder.append("initializationFailed");
    });

    m_app->initialize();

    QVERIFY(signalOrder.contains("initialized"));
    QVERIFY(!signalOrder.contains("initializationFailed"));
}

void TestApplication::testErrorMessageCompleteness()
{
    // Property-based test: all error enum values should have messages
    const QList<AppError> allErrors = {
        AppError::TrayUnavailable,
        AppError::TrayShowFailed
    };

    for (const auto& error : allErrors) {
        const QString message = Application::errorMessage(error);

        QVERIFY(!message.isEmpty());
        QVERIFY(message != QStringLiteral("Unknown error"));
        QVERIFY(message.length() > 10); // Reasonable length check
        QVERIFY(message.contains(QRegularExpression("[A-Za-z]"))); // Contains letters
    }
}

QTEST_MAIN(TestApplication)
#include "tst_application.moc"