// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#ifndef APPLICATION_H
#define APPLICATION_H

#include <QObject>

#include <expected>
#include <memory>

class TrayIcon;

/**
 * @brief Error types for application initialization
 */
enum class AppError {
    TrayUnavailable,  ///< System tray is not available
    TrayShowFailed    ///< Failed to show tray icon
};

/**
 * @brief Main application controller for The Wiser One
 *
 * Manages the application lifecycle and coordinates components.
 */
class Application : public QObject {
    Q_OBJECT

public:
    /**
     * @brief Construct a new Application
     * @param parent Parent QObject for ownership
     */
    explicit Application(QObject* parent = nullptr);
    ~Application() override;

    // Non-copyable, non-movable (QObject derived)
    Application(const Application&) = delete;
    Application& operator=(const Application&) = delete;

    /**
     * @brief Initialize the application
     * @return true if initialization successful
     */
    [[nodiscard]] bool initialize();

    /**
     * @brief Initialize with detailed error information
     * @return Expected void on success, AppError on failure
     */
    [[nodiscard]] std::expected<void, AppError> tryInitialize();

    /**
     * @brief Check if the application is properly initialized
     * @return true if initialized successfully
     */
    [[nodiscard]] bool isInitialized() const noexcept;

    /**
     * @brief Get human-readable error message for AppError
     * @param error The error to describe
     * @return Error message string
     */
    [[nodiscard]] static QString errorMessage(AppError error) noexcept;

signals:
    /**
     * @brief Emitted when initialization succeeds
     */
    void initialized();

    /**
     * @brief Emitted when initialization fails
     * @param reason Human-readable failure reason
     */
    void initializationFailed(const QString& reason);

private:
    std::unique_ptr<TrayIcon> m_trayIcon;
    bool m_initialized{false};
};

#endif  // APPLICATION_H
