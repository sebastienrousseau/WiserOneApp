// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#ifndef NOTIFICATIONMANAGER_H
#define NOTIFICATIONMANAGER_H

#include "interfaces/INotificationService.h"

#include <QSystemTrayIcon>

#include <memory>

/**
 * @brief Cross-platform notification manager using QSystemTrayIcon
 *
 * Uses Qt's built-in QSystemTrayIcon::showMessage which routes to
 * the native notification center on all platforms:
 * - macOS: NSUserNotification / UNUserNotificationCenter
 * - Linux: D-Bus notifications (freedesktop.org)
 * - Windows: Windows toast notifications
 *
 * Notifications appear in the notification list/center, keeping
 * the top panel clean and uncluttered.
 */
class NotificationManager : public INotificationService {
public:
    /**
     * @brief Construct NotificationManager
     * @param trayIcon Pointer to the system tray icon (must outlive this object)
     */
    explicit NotificationManager(QSystemTrayIcon* trayIcon);
    ~NotificationManager() override = default;

    [[nodiscard]] bool sendQuoteNotification(
        const QString& title,
        const QString& quote,
        const QString& author) override;

    [[nodiscard]] bool isAvailable() const override;
    [[nodiscard]] bool requestPermission() override;

private:
    QSystemTrayIcon* m_trayIcon;
};

#endif  // NOTIFICATIONMANAGER_H
