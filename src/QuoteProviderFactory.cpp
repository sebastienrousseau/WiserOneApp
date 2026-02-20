// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#include "QuoteProviderFactory.h"
#include "QuoteManager.h"

#include <functional>

std::unique_ptr<IQuoteProvider> QuoteProviderFactory::createDefault()
{
    if (s_customFactory) {
        return s_customFactory();
    }
    return std::make_unique<QuoteManager>();
}

std::unique_ptr<IQuoteProvider> QuoteProviderFactory::createForTesting()
{
    // Use custom factory if set (for mock injection)
    if (s_customFactory) {
        return s_customFactory();
    }
    // Default to regular QuoteManager for integration tests
    return std::make_unique<QuoteManager>();
}

void QuoteProviderFactory::setTestFactory(std::function<std::unique_ptr<IQuoteProvider>()> factory)
{
    s_customFactory = std::move(factory);
}

void QuoteProviderFactory::resetToDefault()
{
    s_customFactory = nullptr;
}