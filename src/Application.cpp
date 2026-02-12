// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#include "Application.h"

#include "ErrorLogger.h"
#include "TrayIcon.h"

Application::Application(QObject* parent)
    : QObject(parent)
{
}

Application::~Application() = default;

QString Application::errorMessage(AppError error) noexcept
{
    switch (error) {
    case AppError::TrayUnavailable:
        return QStringLiteral("System tray is not available on this system");
    case AppError::TrayShowFailed:
        return QStringLiteral("Failed to show system tray icon");
    }
    return QStringLiteral("Unknown error");
}

bool Application::initialize()
{
    return tryInitialize().has_value();
}

std::expected<void, AppError> Application::tryInitialize()
{
    if (m_initialized) {
        return {};
    }

    // Check if system tray is available
    if (!TrayIcon::isAvailable()) {
        const auto error = AppError::TrayUnavailable;
        const auto message = errorMessage(error);
        ErrorLogger::instance().log(
            QStringLiteral("Application.cpp"),
            QStringLiteral("tryInitialize"),
            message);
        emit initializationFailed(message);
        return std::unexpected(error);
    }

    // Create and show tray icon
    m_trayIcon = std::make_unique<TrayIcon>(this);

    if (!m_trayIcon->show()) {
        const auto error = AppError::TrayShowFailed;
        const auto message = errorMessage(error);
        ErrorLogger::instance().log(
            QStringLiteral("Application.cpp"),
            QStringLiteral("tryInitialize"),
            message);
        emit initializationFailed(message);
        m_trayIcon.reset();
        return std::unexpected(error);
    }

    m_initialized = true;
    emit initialized();
    return {};
}

bool Application::isInitialized() const noexcept
{
    return m_initialized;
}
