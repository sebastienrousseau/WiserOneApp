// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#include "QuoteManager.h"

#include <QSet>
#include <QStandardPaths>
#include <QtTest>

#include <memory>

class TestQuoteManager : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void cleanupTestCase();

    // Quote struct tests
    void testQuoteIsValid_data();
    void testQuoteIsValid();
    void testQuoteEquality();

    // QuoteManager tests
    void testConstruction();
    void testGetRandomQuote();
    void testTryGetRandomQuote();
    void testGetRandomQuoteReturnsDifferentQuotes();
    void testHasQuotes();
    void testQuoteCount();
    void testQuoteHasRequiredFields();
    void testFallbackQuoteWhenEmpty();
    void testCategories();
    void testGetRandomQuoteByCategory();

private:
    std::unique_ptr<QuoteManager> m_manager;
};

void TestQuoteManager::initTestCase()
{
    // Use test-specific data location
    QStandardPaths::setTestModeEnabled(true);
    m_manager = std::make_unique<QuoteManager>();
}

void TestQuoteManager::cleanupTestCase()
{
    m_manager.reset();
}

void TestQuoteManager::testQuoteIsValid_data()
{
    QTest::addColumn<QString>("text");
    QTest::addColumn<bool>("expectedValid");

    QTest::newRow("empty text") << QString() << false;
    QTest::newRow("whitespace only") << QStringLiteral("   ") << false;
    QTest::newRow("valid text") << QStringLiteral("Hello world") << true;
}

void TestQuoteManager::testQuoteIsValid()
{
    QFETCH(QString, text);
    QFETCH(bool, expectedValid);

    Quote quote{.id = 0, .text = text.trimmed(), .author = {}, .category = {}};
    QCOMPARE(quote.isValid(), expectedValid);
}

void TestQuoteManager::testQuoteEquality()
{
    Quote quote1{.id = 1, .text = QStringLiteral("Test"), .author = QStringLiteral("Author"), .category = {}};
    Quote quote2{.id = 1, .text = QStringLiteral("Test"), .author = QStringLiteral("Author"), .category = {}};
    Quote quote3{.id = 2, .text = QStringLiteral("Different"), .author = QStringLiteral("Author"), .category = {}};

    QVERIFY(quote1 == quote2);
    QVERIFY(!(quote1 == quote3));
}

void TestQuoteManager::testConstruction()
{
    QuoteManager manager;
    // Should not throw, should initialize properly with seeded quotes
    QVERIFY(manager.hasQuotes());
}

void TestQuoteManager::testGetRandomQuote()
{
    Quote quote = m_manager->getRandomQuote();

    // Should always return a valid quote (seeded or fallback)
    QVERIFY(quote.isValid());
    QVERIFY(!quote.text.isEmpty());
    QVERIFY(!quote.author.isEmpty());
}

void TestQuoteManager::testTryGetRandomQuote()
{
    auto result = m_manager->tryGetRandomQuote();

    QVERIFY(result.has_value());
    QVERIFY(result->isValid());
    QVERIFY(!result->text.isEmpty());
}

void TestQuoteManager::testGetRandomQuoteReturnsDifferentQuotes()
{
    if (m_manager->quoteCount() < 2) {
        QSKIP("Not enough quotes to test randomness");
    }

    QSet<QString> uniqueQuotes;
    constexpr int ITERATIONS = 30;

    for (int i = 0; i < ITERATIONS; ++i) {
        Quote quote = m_manager->getRandomQuote();
        uniqueQuotes.insert(quote.text);
    }

    // With random selection, we should see multiple unique quotes
    QVERIFY2(uniqueQuotes.size() > 1,
             "Expected multiple unique quotes from random selection");
}

void TestQuoteManager::testHasQuotes()
{
    // Should have quotes from initial seeding
    QVERIFY(m_manager->hasQuotes());
}

void TestQuoteManager::testQuoteCount()
{
    const auto count = m_manager->quoteCount();

    // Should have 120 initial quotes seeded
    QVERIFY(count >= 100);
    QCOMPARE(m_manager->hasQuotes(), count > 0);
}

void TestQuoteManager::testQuoteHasRequiredFields()
{
    Quote quote = m_manager->getRandomQuote();

    QVERIFY(!quote.text.isEmpty());
    QVERIFY(!quote.author.isEmpty());
    QVERIFY(quote.id > 0);
}

void TestQuoteManager::testFallbackQuoteWhenEmpty()
{
    // Even with a fresh manager, should get valid quote (seeded)
    QuoteManager manager;
    Quote quote = manager.getRandomQuote();

    QVERIFY(quote.isValid());
    QVERIFY(!quote.author.isEmpty());
}

void TestQuoteManager::testCategories()
{
    QStringList cats = m_manager->categories();

    // Should have multiple categories from initial quotes
    QVERIFY(cats.size() >= 5);
    QVERIFY(cats.contains(QStringLiteral("wisdom")));
    QVERIFY(cats.contains(QStringLiteral("innovation")));
    QVERIFY(cats.contains(QStringLiteral("growth")));
}

void TestQuoteManager::testGetRandomQuoteByCategory()
{
    auto result = m_manager->getRandomQuoteByCategory(QStringLiteral("wisdom"));

    QVERIFY(result.has_value());
    QCOMPARE(result->category, QStringLiteral("wisdom"));
    QVERIFY(result->isValid());
}

QTEST_MAIN(TestQuoteManager)
#include "tst_quotemanager.moc"
