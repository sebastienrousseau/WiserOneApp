// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#include "NotificationManager.h"

#include "ErrorLogger.h"

NotificationManager::NotificationManager(QSystemTrayIcon* trayIcon)
    : m_trayIcon(trayIcon)
{
}

bool NotificationManager::sendQuoteNotification(
    const QString& title,
    const QString& quote,
    const QString& author)
{
    if (!isAvailable()) {
        ErrorLogger::instance().log(
            QStringLiteral("NotificationManager.cpp"),
            QStringLiteral("sendQuoteNotification"),
            QStringLiteral("Notification service not available"));
        return false;
    }

    const QString body = QStringLiteral("\"%1\"\n\n— %2").arg(quote, author);

    m_trayIcon->showMessage(
        title,
        body,
        QSystemTrayIcon::Information,
        10000  // 10 second display timeout
    );

    return true;
}

bool NotificationManager::isAvailable() const
{
    return m_trayIcon != nullptr
        && m_trayIcon->supportsMessages();
}

bool NotificationManager::requestPermission()
{
    // QSystemTrayIcon doesn't require explicit permission on any platform.
    // On macOS, the first showMessage call triggers the OS permission prompt.
    return isAvailable();
}
