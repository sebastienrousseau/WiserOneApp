// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#ifndef TRAYICON_H
#define TRAYICON_H

#include "QuoteManager.h"

#include <QAction>
#include <QMenu>
#include <QSystemTrayIcon>
#include <QTimer>

#include <memory>

class AboutDialog;
class QSvgRenderer;

/**
 * @brief System tray icon manager for The Wiser One app
 *
 * Handles the system tray icon, context menu with quote display
 * and action items (refresh, website, settings).
 */
class TrayIcon : public QObject {
    Q_OBJECT

public:
    /**
     * @brief Construct a new TrayIcon
     * @param parent Parent QObject for ownership (optional)
     *
     * @code{cpp}
     * auto trayIcon = std::make_unique<TrayIcon>(this);
     * if (trayIcon->show()) {
     *     qDebug() << "Tray icon shown successfully";
     * }
     * @endcode
     */
    explicit TrayIcon(QObject* parent = nullptr);

    /**
     * @brief Destructor - cleans up tray icon and menu
     */
    ~TrayIcon() override;

    TrayIcon(const TrayIcon&) = delete;
    TrayIcon& operator=(const TrayIcon&) = delete;

    /**
     * @brief Show the tray icon in the system tray
     * @return true if successfully shown, false if tray unavailable
     *
     * Must be called after construction to make the icon visible.
     * Will fail if system tray is not available on the platform.
     */
    [[nodiscard]] bool show();

    /**
     * @brief Check if system tray is available
     * @return true if system tray is supported and available
     *
     * @code{cpp}
     * if (!TrayIcon::isAvailable()) {
     *     qWarning() << "System tray not available";
     *     // Show main window instead
     * }
     * @endcode
     */
    [[nodiscard]] static bool isAvailable() noexcept;

    /**
     * @brief Check if the system is using dark theme
     * @return true if dark theme detected, false for light theme
     *
     * Uses platform-specific APIs to detect theme preference.
     * Used for selecting appropriate icon variants.
     */
    [[nodiscard]] static bool isDarkThemeStatic();

signals:
    void quoteDisplayed(const QString& quote, const QString& author);
    void websiteRequested();
    void quitRequested();

protected:
    bool eventFilter(QObject* watched, QEvent* event) override;

private slots:
    void onTrayActivated(QSystemTrayIcon::ActivationReason reason);
    void handleQuitAction();
    void handleRefresh();
    void handleWebsite();
    void handleSettings();
    void handleMenuAboutToShow();
    void updateIconForTheme();

private:
    void setupMenu();
    void setupConnections();
    [[nodiscard]] QIcon createSymbolicIcon() const;
    [[nodiscard]] bool isDarkTheme() const noexcept;
    void updateQuoteDisplay();

    std::unique_ptr<QSystemTrayIcon> m_trayIcon;
    std::unique_ptr<QMenu> m_contextMenu;
    std::unique_ptr<QuoteManager> m_quoteManager;
    std::unique_ptr<AboutDialog> m_aboutDialog;

    // Menu actions
    QAction* m_quoteAction{nullptr};
    QAction* m_authorAction{nullptr};

    bool m_lastKnownDarkMode{false};
    std::unique_ptr<QTimer> m_themeCheckTimer;

    // SVG icon caching for performance
    mutable QByteArray m_cachedSvgData;
    mutable QByteArray m_cachedDarkSvg;
    mutable QByteArray m_cachedLightSvg;
    mutable std::unique_ptr<QSvgRenderer> m_cachedDarkRenderer;
    mutable std::unique_ptr<QSvgRenderer> m_cachedLightRenderer;

    static constexpr int ICON_SIZE = 22;
};

#endif  // TRAYICON_H
