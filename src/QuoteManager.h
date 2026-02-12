// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#ifndef QUOTEMANAGER_H
#define QUOTEMANAGER_H

#include "interfaces/IQuoteProvider.h"

#include <QSqlDatabase>
#include <QString>

#include <cstdint>
#include <expected>
#include <functional>
#include <optional>
#include <vector>

// Quote struct and QuoteError enum are now defined in IQuoteProvider.h

/**
 * @brief SQLite-based quote provider implementation
 *
 * Manages quotes using SQLite for fast random access.
 * Optimized for large collections (1000+ quotes):
 * - O(1) random quote retrieval
 * - Lazy loading (one quote at a time)
 * - History tracking to avoid consecutive repeats
 * - Categories for filtering
 */
class QuoteManager : public IQuoteProvider {
public:
    QuoteManager();
    ~QuoteManager();

    // Non-copyable, non-movable (owns database connection)
    QuoteManager(const QuoteManager&) = delete;
    QuoteManager& operator=(const QuoteManager&) = delete;
    QuoteManager(QuoteManager&&) = delete;
    QuoteManager& operator=(QuoteManager&&) = delete;

    // IQuoteProvider interface implementation
    [[nodiscard]] Quote getRandomQuote() override;
    [[nodiscard]] QuoteResult tryGetRandomQuote() override;
    [[nodiscard]] QuoteResult getRandomQuoteByCategory(const QString& category) override;
    [[nodiscard]] bool hasQuotes() const override;
    [[nodiscard]] std::int64_t quoteCount() const override;
    [[nodiscard]] QStringList categories() const override;

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
