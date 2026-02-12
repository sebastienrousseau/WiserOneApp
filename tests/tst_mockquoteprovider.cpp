// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#include "MockQuoteProvider.h"

#include <QtTest>

#include <memory>

/**
 * @brief Tests for MockQuoteProvider to verify test infrastructure works
 */
class TestMockQuoteProvider : public QObject {
    Q_OBJECT

private slots:
    void init();
    void cleanup();

    // Basic functionality tests
    void testEmptyProviderReturnsFallback();
    void testAddQuote();
    void testAddMultipleQuotes();
    void testClearQuotes();
    void testHasQuotes();
    void testQuoteCount();
    void testCategories();

    // Error simulation tests
    void testSimulateError();
    void testStopSimulatingError();

    // Call counting tests
    void testCallCounting();
    void testResetCallCounts();

    // Callback tests
    void testGetRandomQuoteCallback();
    void testTryGetRandomQuoteCallback();
    void testGetRandomQuoteByCategoryCallback();

    // Category filtering tests
    void testGetRandomQuoteByCategory();
    void testGetRandomQuoteByCategoryNotFound();
    void testLastRequestedCategory();

private:
    std::unique_ptr<MockQuoteProvider> m_mock;
};

void TestMockQuoteProvider::init()
{
    m_mock = std::make_unique<MockQuoteProvider>();
}

void TestMockQuoteProvider::cleanup()
{
    m_mock.reset();
}

void TestMockQuoteProvider::testEmptyProviderReturnsFallback()
{
    Quote quote = m_mock->getRandomQuote();
    QCOMPARE(quote.text, QStringLiteral("Mock fallback quote"));
    QCOMPARE(quote.author, QStringLiteral("Mock Author"));
}

void TestMockQuoteProvider::testAddQuote()
{
    Quote testQuote{
        .id = 1,
        .text = QStringLiteral("Test quote"),
        .author = QStringLiteral("Test Author"),
        .category = QStringLiteral("test")};

    m_mock->addQuote(testQuote);

    Quote result = m_mock->getRandomQuote();
    QCOMPARE(result.text, testQuote.text);
    QCOMPARE(result.author, testQuote.author);
}

void TestMockQuoteProvider::testAddMultipleQuotes()
{
    std::vector<Quote> quotes = {
        {.id = 1, .text = QStringLiteral("Quote 1"), .author = QStringLiteral("Author 1"), .category = QStringLiteral("cat1")},
        {.id = 2, .text = QStringLiteral("Quote 2"), .author = QStringLiteral("Author 2"), .category = QStringLiteral("cat2")}};

    m_mock->addQuotes(quotes);

    QCOMPARE(m_mock->quoteCount(), 2);
}

void TestMockQuoteProvider::testClearQuotes()
{
    m_mock->addQuote(
        {.id = 1, .text = QStringLiteral("Test"), .author = QStringLiteral("Author"), .category = {}});
    QVERIFY(m_mock->hasQuotes());

    m_mock->clearQuotes();
    QVERIFY(!m_mock->hasQuotes());
}

void TestMockQuoteProvider::testHasQuotes()
{
    QVERIFY(!m_mock->hasQuotes());

    m_mock->addQuote(
        {.id = 1, .text = QStringLiteral("Test"), .author = QStringLiteral("Author"), .category = {}});
    QVERIFY(m_mock->hasQuotes());
}

void TestMockQuoteProvider::testQuoteCount()
{
    QCOMPARE(m_mock->quoteCount(), 0);

    m_mock->addQuote(
        {.id = 1, .text = QStringLiteral("Test"), .author = QStringLiteral("Author"), .category = {}});
    QCOMPARE(m_mock->quoteCount(), 1);

    m_mock->addQuote(
        {.id = 2, .text = QStringLiteral("Test 2"), .author = QStringLiteral("Author"), .category = {}});
    QCOMPARE(m_mock->quoteCount(), 2);
}

void TestMockQuoteProvider::testCategories()
{
    m_mock->addQuote(
        {.id = 1, .text = QStringLiteral("Q1"), .author = QStringLiteral("A"), .category = QStringLiteral("wisdom")});
    m_mock->addQuote(
        {.id = 2, .text = QStringLiteral("Q2"), .author = QStringLiteral("A"), .category = QStringLiteral("growth")});
    m_mock->addQuote(
        {.id = 3, .text = QStringLiteral("Q3"), .author = QStringLiteral("A"), .category = QStringLiteral("wisdom")});

    QStringList cats = m_mock->categories();
    QCOMPARE(cats.size(), 2);
    QVERIFY(cats.contains(QStringLiteral("wisdom")));
    QVERIFY(cats.contains(QStringLiteral("growth")));
}

void TestMockQuoteProvider::testSimulateError()
{
    m_mock->addQuote(
        {.id = 1, .text = QStringLiteral("Test"), .author = QStringLiteral("Author"), .category = {}});

    m_mock->simulateError(QuoteError::DatabaseError);

    auto result = m_mock->tryGetRandomQuote();
    QVERIFY(!result.has_value());
    QCOMPARE(result.error(), QuoteError::DatabaseError);
}

void TestMockQuoteProvider::testStopSimulatingError()
{
    m_mock->addQuote(
        {.id = 1, .text = QStringLiteral("Test"), .author = QStringLiteral("Author"), .category = {}});

    m_mock->simulateError(QuoteError::DatabaseError);
    m_mock->stopSimulatingError();

    auto result = m_mock->tryGetRandomQuote();
    QVERIFY(result.has_value());
}

void TestMockQuoteProvider::testCallCounting()
{
    QCOMPARE(m_mock->getRandomQuoteCallCount(), 0);
    QCOMPARE(m_mock->tryGetRandomQuoteCallCount(), 0);
    QCOMPARE(m_mock->hasQuotesCallCount(), 0);

    m_mock->getRandomQuote();
    QCOMPARE(m_mock->getRandomQuoteCallCount(), 1);

    m_mock->tryGetRandomQuote();
    QCOMPARE(m_mock->tryGetRandomQuoteCallCount(), 1);

    m_mock->hasQuotes();
    m_mock->hasQuotes();
    QCOMPARE(m_mock->hasQuotesCallCount(), 2);
}

void TestMockQuoteProvider::testResetCallCounts()
{
    m_mock->getRandomQuote();
    m_mock->tryGetRandomQuote();
    m_mock->hasQuotes();

    m_mock->resetCallCounts();

    QCOMPARE(m_mock->getRandomQuoteCallCount(), 0);
    QCOMPARE(m_mock->tryGetRandomQuoteCallCount(), 0);
    QCOMPARE(m_mock->hasQuotesCallCount(), 0);
}

void TestMockQuoteProvider::testGetRandomQuoteCallback()
{
    Quote customQuote{
        .id = 99,
        .text = QStringLiteral("Custom callback quote"),
        .author = QStringLiteral("Callback"),
        .category = {}};

    m_mock->setGetRandomQuoteCallback([customQuote]() { return customQuote; });

    Quote result = m_mock->getRandomQuote();
    QCOMPARE(result.text, customQuote.text);
    QCOMPARE(result.id, customQuote.id);
}

void TestMockQuoteProvider::testTryGetRandomQuoteCallback()
{
    m_mock->setTryGetRandomQuoteCallback(
        []() -> IQuoteProvider::QuoteResult { return std::unexpected(QuoteError::EmptyCollection); });

    auto result = m_mock->tryGetRandomQuote();
    QVERIFY(!result.has_value());
    QCOMPARE(result.error(), QuoteError::EmptyCollection);
}

void TestMockQuoteProvider::testGetRandomQuoteByCategoryCallback()
{
    m_mock->setGetRandomQuoteByCategoryCallback(
        [](const QString& category) -> IQuoteProvider::QuoteResult {
            return Quote{
                .id = 1,
                .text = QStringLiteral("Quote for ") + category,
                .author = QStringLiteral("Author"),
                .category = category};
        });

    auto result = m_mock->getRandomQuoteByCategory(QStringLiteral("wisdom"));
    QVERIFY(result.has_value());
    QCOMPARE(result->text, QStringLiteral("Quote for wisdom"));
    QCOMPARE(result->category, QStringLiteral("wisdom"));
}

void TestMockQuoteProvider::testGetRandomQuoteByCategory()
{
    m_mock->addQuote(
        {.id = 1, .text = QStringLiteral("Wisdom quote"), .author = QStringLiteral("A"), .category = QStringLiteral("wisdom")});
    m_mock->addQuote(
        {.id = 2, .text = QStringLiteral("Growth quote"), .author = QStringLiteral("B"), .category = QStringLiteral("growth")});

    auto result = m_mock->getRandomQuoteByCategory(QStringLiteral("wisdom"));
    QVERIFY(result.has_value());
    QCOMPARE(result->category, QStringLiteral("wisdom"));
}

void TestMockQuoteProvider::testGetRandomQuoteByCategoryNotFound()
{
    m_mock->addQuote(
        {.id = 1, .text = QStringLiteral("Test"), .author = QStringLiteral("A"), .category = QStringLiteral("wisdom")});

    auto result = m_mock->getRandomQuoteByCategory(QStringLiteral("nonexistent"));
    QVERIFY(!result.has_value());
    QCOMPARE(result.error(), QuoteError::EmptyCollection);
}

void TestMockQuoteProvider::testLastRequestedCategory()
{
    m_mock->getRandomQuoteByCategory(QStringLiteral("wisdom"));
    QCOMPARE(m_mock->lastRequestedCategory(), QStringLiteral("wisdom"));

    m_mock->getRandomQuoteByCategory(QStringLiteral("growth"));
    QCOMPARE(m_mock->lastRequestedCategory(), QStringLiteral("growth"));
}

QTEST_MAIN(TestMockQuoteProvider)
#include "tst_mockquoteprovider.moc"
