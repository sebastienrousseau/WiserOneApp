// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#ifndef QUOTEMANAGER_H
#define QUOTEMANAGER_H

#include <QSqlDatabase>
#include <QString>

#include <cstdint>
#include <expected>
#include <functional>
#include <optional>
#include <vector>

/**
 * @brief Represents a single quote with metadata
 */
struct Quote {
    std::int64_t id{0};
    QString text;
    QString author;
    QString category;

    /**
     * @brief Check if the quote has valid content
     * @return true if text is not empty
     */
    [[nodiscard]] constexpr bool isValid() const noexcept { return !text.isEmpty(); }

    /**
     * @brief Default comparison operator
     */
    [[nodiscard]] bool operator==(const Quote&) const = default;
};

/**
 * @brief Error types for quote operations
 */
enum class QuoteError {
    DatabaseError,   ///< Database connection or query failed
    EmptyCollection  ///< No quotes found in database
};

/**
 * @brief Manages quotes using SQLite for fast random access
 *
 * Optimized for large collections (1000+ quotes):
 * - O(1) random quote retrieval
 * - Lazy loading (one quote at a time)
 * - History tracking to avoid consecutive repeats
 * - Categories for future filtering
 */
class QuoteManager {
public:
    /// Result type for operations that may fail
    using QuoteResult = std::expected<Quote, QuoteError>;

    QuoteManager();
    ~QuoteManager();

    // Non-copyable, non-movable (owns database connection)
    QuoteManager(const QuoteManager&) = delete;
    QuoteManager& operator=(const QuoteManager&) = delete;
    QuoteManager(QuoteManager&&) = delete;
    QuoteManager& operator=(QuoteManager&&) = delete;

    /**
     * @brief Get a random quote from the database
     * @return A randomly selected quote, or fallback if none available
     */
    [[nodiscard]] Quote getRandomQuote();

    /**
     * @brief Get a random quote with error information
     * @return Expected containing quote or error
     */
    [[nodiscard]] QuoteResult tryGetRandomQuote();

    /**
     * @brief Get a random quote from a specific category
     * @param category Category name to filter by
     * @return Expected containing quote or error
     */
    [[nodiscard]] QuoteResult getRandomQuoteByCategory(const QString& category);

    /**
     * @brief Check if the database has any quotes
     * @return true if quotes are available
     */
    [[nodiscard]] bool hasQuotes() const;

    /**
     * @brief Get the total number of quotes in the database
     * @return Number of quotes
     */
    [[nodiscard]] std::int64_t quoteCount() const;

    /**
     * @brief Get all available categories
     * @return List of unique category names
     */
    [[nodiscard]] QStringList categories() const;

private:
    [[nodiscard]] bool initializeDatabase();
    [[nodiscard]] bool createSchema();
    [[nodiscard]] bool seedInitialQuotes();
    [[nodiscard]] std::optional<Quote> fetchQuoteById(std::int64_t id) const;
    [[nodiscard]] std::int64_t getRandomId() const;
    [[nodiscard]] QString getDatabasePath() const;

    QSqlDatabase m_database;
    QString m_connectionName;
    Quote m_fallbackQuote;
    mutable std::int64_t m_lastId{0};
    mutable std::int64_t m_cachedCount{-1};

    // Performance optimization: cache quote IDs for fast random access
    mutable std::vector<std::int64_t> m_cachedIds;
    mutable bool m_idsLoaded{false};
};

#endif  // QUOTEMANAGER_H
