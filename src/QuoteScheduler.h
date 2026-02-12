// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#ifndef QUOTESCHEDULER_H
#define QUOTESCHEDULER_H

#include <QObject>
#include <QTime>
#include <QTimer>

#include <memory>
#include <vector>

/**
 * @brief Schedules quote notifications at user-configured times
 *
 * Manages a list of scheduled times and fires a signal when
 * a notification should be sent. Uses QTimer to wake up at the
 * next scheduled time. Settings are persisted via QSettings.
 */
class QuoteScheduler : public QObject {
    Q_OBJECT

public:
    explicit QuoteScheduler(QObject* parent = nullptr);
    ~QuoteScheduler() override = default;

    /**
     * @brief Set whether notifications are enabled
     * @param enabled true to enable scheduled notifications
     */
    void setEnabled(bool enabled);

    /**
     * @brief Check if notifications are enabled
     */
    [[nodiscard]] bool isEnabled() const noexcept { return m_enabled; }

    /**
     * @brief Set the list of scheduled notification times
     * @param times List of times to deliver notifications
     */
    void setScheduledTimes(const std::vector<QTime>& times);

    /**
     * @brief Get the current list of scheduled times
     */
    [[nodiscard]] const std::vector<QTime>& scheduledTimes() const noexcept { return m_scheduledTimes; }

    /**
     * @brief Load settings from QSettings
     */
    void loadSettings();

    /**
     * @brief Save settings to QSettings
     */
    void saveSettings() const;

signals:
    /**
     * @brief Emitted when a scheduled notification should be sent
     */
    void notificationDue();

private slots:
    void onTimerFired();

private:
    void scheduleNextNotification();
    [[nodiscard]] QTime findNextScheduledTime() const;
    [[nodiscard]] int msUntil(const QTime& target) const;

    std::unique_ptr<QTimer> m_timer;
    std::vector<QTime> m_scheduledTimes;
    bool m_enabled{false};

    static constexpr int MS_PER_DAY = 24 * 60 * 60 * 1000;
};

#endif  // QUOTESCHEDULER_H
