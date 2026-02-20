// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#ifndef ERRORLOGGER_H
#define ERRORLOGGER_H

#include <QMutex>
#include <QString>
#include <QStringView>

#include <expected>
#include <string_view>

/**
 * @brief Error types for logging operations
 */
enum class LogError {
    FileOpenFailed,  ///< Could not open log file
    WriteFailed      ///< Could not write to log file
};

/**
 * @brief Thread-safe singleton logger for error tracking
 *
 * Logs errors to ~/Documents/appLog.txt with timestamps.
 * Uses mutex for thread safety.
 */
class ErrorLogger {
public:
    /**
     * @brief Get the singleton instance
     * @return Reference to the singleton ErrorLogger
     */
    [[nodiscard]] static ErrorLogger& instance() noexcept;

    /**
     * @brief Log an error message
     * @param file Source file name
     * @param method Method/function name
     * @param error Error description
     */
    void log(const QString& file, const QString& method, const QString& error);

    /**
     * @brief Log with QStringView for better performance with literals
     * @param file Source file name
     * @param method Method/function name
     * @param error Error description
     */
    void log(QStringView file, QStringView method, const QString& error);

    /**
     * @brief Log with result indicating success/failure
     * @param file Source file name
     * @param method Method/function name
     * @param error Error description
     * @return Expected void on success, LogError on failure
     */
    [[nodiscard]] std::expected<void, LogError> tryLog(
        QStringView file, QStringView method, const QString& error);

    /**
     * @brief Get the log file path
     * @return Absolute path to the log file
     */
    [[nodiscard]] QString logFilePath() const noexcept;

    /**
     * @brief Clear the log file
     * @return Expected void on success, LogError on failure
     */
    [[nodiscard]] std::expected<void, LogError> clearLog();

    // Non-copyable, non-movable singleton
    ErrorLogger(const ErrorLogger&) = delete;
    ErrorLogger& operator=(const ErrorLogger&) = delete;
    ErrorLogger(ErrorLogger&&) = delete;
    ErrorLogger& operator=(ErrorLogger&&) = delete;

private:
    ErrorLogger();
    ~ErrorLogger() = default;

    [[nodiscard]] std::expected<void, LogError> writeEntry(
        QStringView file, QStringView method, const QString& error);

    mutable QMutex m_mutex;
    QString m_logFilePath;

    static constexpr std::string_view TIMESTAMP_FORMAT = "yyyy-MM-dd HH:mm:ss";
};

#endif  // ERRORLOGGER_H
