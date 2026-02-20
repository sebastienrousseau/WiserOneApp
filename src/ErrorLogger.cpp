// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#include "ErrorLogger.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QMutexLocker>
#include <QStandardPaths>
#include <QTextStream>

namespace {
constexpr auto LOG_FILENAME = "appLog.txt";
}  // namespace

ErrorLogger& ErrorLogger::instance() noexcept
{
    static ErrorLogger instance;
    return instance;
}

ErrorLogger::ErrorLogger()
    : m_logFilePath(QDir(QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation))
                        .filePath(QLatin1String(LOG_FILENAME)))
{
}

QString ErrorLogger::logFilePath() const noexcept
{
    return m_logFilePath;
}

void ErrorLogger::log(const QString& file, const QString& method, const QString& error)
{
    if (!writeEntry(file, method, error).has_value()) {
        // Fallback to stderr if file logging fails
        QTextStream(stderr) << QStringLiteral("[LOG FALLBACK] %1::%2 - %3\n")
                                   .arg(file, method, error);
    }
}

void ErrorLogger::log(QStringView file, QStringView method, const QString& error)
{
    if (!writeEntry(file, method, error).has_value()) {
        // Fallback to stderr if file logging fails
        QTextStream(stderr) << QStringLiteral("[LOG FALLBACK] %1::%2 - %3\n")
                                   .arg(file.toString(), method.toString(), error);
    }
}

std::expected<void, LogError> ErrorLogger::tryLog(
    QStringView file, QStringView method, const QString& error)
{
    return writeEntry(file, method, error);
}

std::expected<void, LogError> ErrorLogger::writeEntry(
    QStringView file, QStringView method, const QString& error)
{
    const QMutexLocker locker(&m_mutex);

    QFile logFile(m_logFilePath);
    if (!logFile.open(QIODevice::Append | QIODevice::Text)) {
        return std::unexpected(LogError::FileOpenFailed);
    }

    QTextStream stream(&logFile);
    stream << QDateTime::currentDateTime().toString(
              QLatin1String(TIMESTAMP_FORMAT.data(), static_cast<qsizetype>(TIMESTAMP_FORMAT.size())))
           << QStringLiteral(" - File: ") << file
           << QStringLiteral(" - Method: ") << method
           << QStringLiteral(" - Error: ") << error
           << QLatin1Char('\n');

    return {};
}

std::expected<void, LogError> ErrorLogger::clearLog()
{
    const QMutexLocker locker(&m_mutex);

    QFile logFile(m_logFilePath);
    if (logFile.exists() && !logFile.remove()) {
        return std::unexpected(LogError::WriteFailed);
    }
    return {};
}
