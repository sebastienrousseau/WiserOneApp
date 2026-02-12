// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#ifndef IQUOTEPROVIDER_H
#define IQUOTEPROVIDER_H

#include <QString>
#include <QStringList>

#include <cstdint>
#include <expected>

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
 * @brief Interface for quote providers
 *
 * Abstracts the data layer for quote retrieval and management.
 * Implementations can provide different backends (SQLite, in-memory, network, etc.)
 * while maintaining a consistent interface for consumers.
 */
class IQuoteProvider {
public:
    /// Result type for operations that may fail
    using QuoteResult = std::expected<Quote, QuoteError>;

    virtual ~IQuoteProvider() = default;

    /**
     * @brief Get a random quote from the collection
     * @return A randomly selected quote, or fallback if none available
     */
    [[nodiscard]] virtual Quote getRandomQuote() = 0;

    /**
     * @brief Get a random quote with error information
     * @return Expected containing quote or error
     */
    [[nodiscard]] virtual QuoteResult tryGetRandomQuote() = 0;

    /**
     * @brief Get a random quote from a specific category
     * @param category Category name to filter by
     * @return Expected containing quote or error
     */
    [[nodiscard]] virtual QuoteResult getRandomQuoteByCategory(const QString& category) = 0;

    /**
     * @brief Check if the provider has any quotes
     * @return true if quotes are available
     */
    [[nodiscard]] virtual bool hasQuotes() const = 0;

    /**
     * @brief Get the total number of quotes in the collection
     * @return Number of quotes
     */
    [[nodiscard]] virtual std::int64_t quoteCount() const = 0;

    /**
     * @brief Get all available categories
     * @return List of unique category names
     */
    [[nodiscard]] virtual QStringList categories() const = 0;

protected:
    // Protected constructor - only derived classes can instantiate
    IQuoteProvider() = default;

    // Non-copyable, non-movable (interface should be managed by reference/pointer)
    IQuoteProvider(const IQuoteProvider&) = delete;
    IQuoteProvider& operator=(const IQuoteProvider&) = delete;
    IQuoteProvider(IQuoteProvider&&) = delete;
    IQuoteProvider& operator=(IQuoteProvider&&) = delete;
};

#endif  // IQUOTEPROVIDER_H