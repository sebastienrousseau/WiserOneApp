// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#ifndef QUOTEPROVIDERFACTORY_H
#define QUOTEPROVIDERFACTORY_H

#include "interfaces/IQuoteProvider.h"

#include <memory>

/**
 * @brief Factory for creating quote provider instances
 *
 * Provides a centralized way to create quote providers with different implementations.
 * Supports dependency injection by allowing override of the default provider.
 */
class QuoteProviderFactory {
public:
    /**
     * @brief Create the default quote provider instance
     * @return Unique pointer to a quote provider
     */
    [[nodiscard]] static std::unique_ptr<IQuoteProvider> createDefault();

    /**
     * @brief Create a quote provider for testing
     * @return Unique pointer to a mock/test quote provider
     */
    [[nodiscard]] static std::unique_ptr<IQuoteProvider> createForTesting();

    /**
     * @brief Set a custom provider factory function for testing
     * @param factory Function that creates quote provider instances
     */
    static void setTestFactory(std::function<std::unique_ptr<IQuoteProvider>()> factory);

    /**
     * @brief Reset to the default factory behavior
     */
    static void resetToDefault();

private:
    static inline std::function<std::unique_ptr<IQuoteProvider>()> s_customFactory{};
};

#endif  // QUOTEPROVIDERFACTORY_H