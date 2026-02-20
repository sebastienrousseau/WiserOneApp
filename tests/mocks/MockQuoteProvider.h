// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#ifndef MOCKQUOTEPROVIDER_H
#define MOCKQUOTEPROVIDER_H

#include "interfaces/IQuoteProvider.h"

#include <QStringList>

#include <functional>
#include <vector>

/**
 * @brief Mock implementation of IQuoteProvider for testing
 *
 * Provides a fully controllable quote provider for unit tests.
 * Allows setting up specific quotes, simulating errors, and
 * verifying interactions.
 */
class MockQuoteProvider : public IQuoteProvider {
public:
    MockQuoteProvider() = default;
    ~MockQuoteProvider() override = default;

    // IQuoteProvider interface implementation
    [[nodiscard]] Quote getRandomQuote() override
    {
        ++m_getRandomQuoteCalls;
        if (m_getRandomQuoteCallback) {
            return m_getRandomQuoteCallback();
        }
        if (m_quotes.empty()) {
            return m_fallbackQuote;
        }
        m_currentIndex = (m_currentIndex + 1) % static_cast<int>(m_quotes.size());
        return m_quotes[static_cast<size_t>(m_currentIndex)];
    }

    [[nodiscard]] QuoteResult tryGetRandomQuote() override
    {
        ++m_tryGetRandomQuoteCalls;
        if (m_simulateError) {
            return std::unexpected(m_errorToSimulate);
        }
        if (m_tryGetRandomQuoteCallback) {
            return m_tryGetRandomQuoteCallback();
        }
        if (m_quotes.empty()) {
            return std::unexpected(QuoteError::EmptyCollection);
        }
        return getRandomQuote();
    }

    [[nodiscard]] QuoteResult getRandomQuoteByCategory(const QString& category) override
    {
        ++m_getRandomQuoteByCategoryCalls;
        m_lastRequestedCategory = category;
        if (m_simulateError) {
            return std::unexpected(m_errorToSimulate);
        }
        if (m_getRandomQuoteByCategoryCallback) {
            return m_getRandomQuoteByCategoryCallback(category);
        }
        for (const auto& quote : m_quotes) {
            if (quote.category == category) {
                return quote;
            }
        }
        return std::unexpected(QuoteError::EmptyCollection);
    }

    [[nodiscard]] bool hasQuotes() const override
    {
        ++m_hasQuotesCalls;
        return !m_quotes.empty();
    }

    [[nodiscard]] std::int64_t quoteCount() const override
    {
        ++m_quoteCountCalls;
        return static_cast<std::int64_t>(m_quotes.size());
    }

    [[nodiscard]] QStringList categories() const override
    {
        ++m_categoriesCalls;
        QStringList cats;
        for (const auto& quote : m_quotes) {
            if (!cats.contains(quote.category)) {
                cats.append(quote.category);
            }
        }
        return cats;
    }

    // ==========================================================================
    // Test Setup Methods
    // ==========================================================================

    /**
     * @brief Add a quote to the mock provider
     * @param quote Quote to add
     */
    void addQuote(const Quote& quote) { m_quotes.push_back(quote); }

    /**
     * @brief Add multiple quotes at once
     * @param quotes Vector of quotes to add
     */
    void addQuotes(const std::vector<Quote>& quotes)
    {
        m_quotes.insert(m_quotes.end(), quotes.begin(), quotes.end());
    }

    /**
     * @brief Clear all quotes from the mock
     */
    void clearQuotes() { m_quotes.clear(); }

    /**
     * @brief Set the fallback quote returned when no quotes available
     * @param quote Fallback quote
     */
    void setFallbackQuote(const Quote& quote) { m_fallbackQuote = quote; }

    /**
     * @brief Configure the mock to simulate an error
     * @param error Error to simulate
     */
    void simulateError(QuoteError error)
    {
        m_simulateError = true;
        m_errorToSimulate = error;
    }

    /**
     * @brief Stop simulating errors
     */
    void stopSimulatingError() { m_simulateError = false; }

    /**
     * @brief Set a custom callback for getRandomQuote
     * @param callback Function to call
     */
    void setGetRandomQuoteCallback(std::function<Quote()> callback)
    {
        m_getRandomQuoteCallback = std::move(callback);
    }

    /**
     * @brief Set a custom callback for tryGetRandomQuote
     * @param callback Function to call
     */
    void setTryGetRandomQuoteCallback(std::function<QuoteResult()> callback)
    {
        m_tryGetRandomQuoteCallback = std::move(callback);
    }

    /**
     * @brief Set a custom callback for getRandomQuoteByCategory
     * @param callback Function to call
     */
    void setGetRandomQuoteByCategoryCallback(
        std::function<QuoteResult(const QString&)> callback)
    {
        m_getRandomQuoteByCategoryCallback = std::move(callback);
    }

    // ==========================================================================
    // Verification Methods
    // ==========================================================================

    /**
     * @brief Get number of times getRandomQuote was called
     */
    [[nodiscard]] int getRandomQuoteCallCount() const { return m_getRandomQuoteCalls; }

    /**
     * @brief Get number of times tryGetRandomQuote was called
     */
    [[nodiscard]] int tryGetRandomQuoteCallCount() const { return m_tryGetRandomQuoteCalls; }

    /**
     * @brief Get number of times getRandomQuoteByCategory was called
     */
    [[nodiscard]] int getRandomQuoteByCategoryCallCount() const
    {
        return m_getRandomQuoteByCategoryCalls;
    }

    /**
     * @brief Get number of times hasQuotes was called
     */
    [[nodiscard]] int hasQuotesCallCount() const { return m_hasQuotesCalls; }

    /**
     * @brief Get number of times quoteCount was called
     */
    [[nodiscard]] int quoteCountCallCount() const { return m_quoteCountCalls; }

    /**
     * @brief Get number of times categories was called
     */
    [[nodiscard]] int categoriesCallCount() const { return m_categoriesCalls; }

    /**
     * @brief Get the last category requested via getRandomQuoteByCategory
     */
    [[nodiscard]] QString lastRequestedCategory() const { return m_lastRequestedCategory; }

    /**
     * @brief Reset all call counters
     */
    void resetCallCounts()
    {
        m_getRandomQuoteCalls = 0;
        m_tryGetRandomQuoteCalls = 0;
        m_getRandomQuoteByCategoryCalls = 0;
        m_hasQuotesCalls = 0;
        m_quoteCountCalls = 0;
        m_categoriesCalls = 0;
        m_lastRequestedCategory.clear();
    }

    /**
     * @brief Verify that a method was called a specific number of times
     * @param methodName Name of method for error messages
     * @param actual Actual call count
     * @param expected Expected call count
     * @return true if counts match
     */
    [[nodiscard]] static bool verifyCalls(const char* methodName, int actual, int expected)
    {
        if (actual != expected) {
            qWarning("MockQuoteProvider: %s called %d times, expected %d",
                     methodName, actual, expected);
            return false;
        }
        return true;
    }

private:
    std::vector<Quote> m_quotes;
    Quote m_fallbackQuote{
        .id = 0,
        .text = QStringLiteral("Mock fallback quote"),
        .author = QStringLiteral("Mock Author"),
        .category = QStringLiteral("test")};
    int m_currentIndex{-1};

    // Error simulation
    bool m_simulateError{false};
    QuoteError m_errorToSimulate{QuoteError::DatabaseError};

    // Callbacks for custom behavior
    std::function<Quote()> m_getRandomQuoteCallback;
    std::function<QuoteResult()> m_tryGetRandomQuoteCallback;
    std::function<QuoteResult(const QString&)> m_getRandomQuoteByCategoryCallback;

    // Call counters (mutable for const methods)
    mutable int m_getRandomQuoteCalls{0};
    mutable int m_tryGetRandomQuoteCalls{0};
    mutable int m_getRandomQuoteByCategoryCalls{0};
    mutable int m_hasQuotesCalls{0};
    mutable int m_quoteCountCalls{0};
    mutable int m_categoriesCalls{0};
    QString m_lastRequestedCategory;
};

#endif  // MOCKQUOTEPROVIDER_H
