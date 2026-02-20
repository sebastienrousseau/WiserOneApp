// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#ifndef INOTIFICATIONSERVICE_H
#define INOTIFICATIONSERVICE_H

#include <QString>

/**
 * @brief Interface for platform-specific notification services
 *
 * Abstracts the notification delivery mechanism so that each platform
 * (macOS, Linux, Windows) can provide its own implementation using
 * native APIs. Notifications appear in the notification center/list,
 * keeping the top panel clean and uncluttered.
 */
class INotificationService {
public:
    virtual ~INotificationService() = default;

    /**
     * @brief Send a quote notification to the system notification center
     * @param title Notification title (e.g., "The Wiser One")
     * @param quote The quote text
     * @param author The quote author
     * @return true if notification was sent successfully
     */
    [[nodiscard]] virtual bool sendQuoteNotification(
        const QString& title,
        const QString& quote,
        const QString& author) = 0;

    /**
     * @brief Check if notifications are supported on this platform
     * @return true if the notification service is available
     */
    [[nodiscard]] virtual bool isAvailable() const = 0;

    /**
     * @brief Request notification permission from the OS (if needed)
     * @return true if permission was granted or already available
     */
    [[nodiscard]] virtual bool requestPermission() = 0;

protected:
    INotificationService() = default;
    INotificationService(const INotificationService&) = delete;
    INotificationService& operator=(const INotificationService&) = delete;
    INotificationService(INotificationService&&) = delete;
    INotificationService& operator=(INotificationService&&) = delete;
};

#endif  // INOTIFICATIONSERVICE_H
