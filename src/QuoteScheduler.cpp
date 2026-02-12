// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#include "QuoteScheduler.h"

#include "ErrorLogger.h"

#include <QSettings>
#include <QTime>

#include <algorithm>

QuoteScheduler::QuoteScheduler(QObject* parent)
    : QObject(parent)
    , m_timer(std::make_unique<QTimer>(this))
{
    m_timer->setSingleShot(true);
    connect(m_timer.get(), &QTimer::timeout, this, &QuoteScheduler::onTimerFired);

    loadSettings();
}

void QuoteScheduler::setEnabled(bool enabled)
{
    m_enabled = enabled;
    if (m_enabled) {
        scheduleNextNotification();
    } else {
        m_timer->stop();
    }
    saveSettings();
}

void QuoteScheduler::setScheduledTimes(const std::vector<QTime>& times)
{
    m_scheduledTimes = times;
    std::sort(m_scheduledTimes.begin(), m_scheduledTimes.end());
    if (m_enabled) {
        scheduleNextNotification();
    }
    saveSettings();
}

void QuoteScheduler::loadSettings()
{
    QSettings settings;
    settings.beginGroup(QStringLiteral("Notifications"));

    m_enabled = settings.value(QStringLiteral("enabled"), false).toBool();

    const int count = settings.beginReadArray(QStringLiteral("scheduledTimes"));
    m_scheduledTimes.clear();
    m_scheduledTimes.reserve(static_cast<size_t>(count));
    for (int i = 0; i < count; ++i) {
        settings.setArrayIndex(i);
        const auto time = settings.value(QStringLiteral("time")).toTime();
        if (time.isValid()) {
            m_scheduledTimes.push_back(time);
        }
    }
    settings.endArray();

    // Default: 9:00 AM if no times configured
    if (m_scheduledTimes.empty()) {
        m_scheduledTimes.push_back(QTime(9, 0));
    }

    std::sort(m_scheduledTimes.begin(), m_scheduledTimes.end());
    settings.endGroup();

    if (m_enabled) {
        scheduleNextNotification();
    }
}

void QuoteScheduler::saveSettings() const
{
    QSettings settings;
    settings.beginGroup(QStringLiteral("Notifications"));

    settings.setValue(QStringLiteral("enabled"), m_enabled);

    settings.beginWriteArray(QStringLiteral("scheduledTimes"),
                             static_cast<int>(m_scheduledTimes.size()));
    for (size_t i = 0; i < m_scheduledTimes.size(); ++i) {
        settings.setArrayIndex(static_cast<int>(i));
        settings.setValue(QStringLiteral("time"), m_scheduledTimes[i]);
    }
    settings.endArray();

    settings.endGroup();
}

void QuoteScheduler::onTimerFired()
{
    emit notificationDue();
    scheduleNextNotification();
}

void QuoteScheduler::scheduleNextNotification()
{
    if (!m_enabled || m_scheduledTimes.empty()) {
        m_timer->stop();
        return;
    }

    const QTime next = findNextScheduledTime();
    if (!next.isValid()) {
        return;
    }

    const int ms = msUntil(next);
    m_timer->start(ms);
}

QTime QuoteScheduler::findNextScheduledTime() const
{
    if (m_scheduledTimes.empty()) {
        return {};
    }

    const QTime now = QTime::currentTime();

    // Find the first scheduled time that's still in the future today
    for (const auto& time : m_scheduledTimes) {
        if (time > now) {
            return time;
        }
    }

    // All times have passed today, wrap to tomorrow's first time
    return m_scheduledTimes.front();
}

int QuoteScheduler::msUntil(const QTime& target) const
{
    const QTime now = QTime::currentTime();
    int ms = now.msecsTo(target);

    // If target is in the past, it's tomorrow
    if (ms <= 0) {
        ms += MS_PER_DAY;
    }

    return ms;
}
