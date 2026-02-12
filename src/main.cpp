// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#include "Application.h"

#include <QApplication>
#include <QIcon>
#include <QLibraryInfo>
#include <QLocale>
#include <QMessageBox>
#include <QStyleFactory>
#include <QTranslator>

#include <string_view>

#ifdef Q_OS_UNIX
#include <fcntl.h>
#include <unistd.h>

#include <array>
#include <cstdio>
#include <cstring>
#endif

namespace {

#ifdef Q_OS_UNIX
/**
 * @brief Temporarily suppress GTK theme warnings during initialization
 *
 * GTK theme parsing warnings are cosmetic and don't affect functionality.
 * We capture stderr during Qt initialization and filter out these warnings.
 */
class StderrFilter {
public:
    StderrFilter()
    {
        // Save original stderr
        m_originalStderr = dup(STDERR_FILENO);
        if (m_originalStderr == -1) {
            return; // Cannot proceed without backup of stderr
        }

        // Create pipe for capturing
        if (pipe(m_pipe.data()) != 0) {
            // Cleanup original stderr on pipe failure
            close(m_originalStderr);
            m_originalStderr = -1;
            return;
        }

        // Redirect stderr to pipe
        if (dup2(m_pipe[1], STDERR_FILENO) == -1) {
            // Cleanup on dup2 failure
            close(m_pipe[0]);
            close(m_pipe[1]);
            close(m_originalStderr);
            m_originalStderr = -1;
            m_pipe[0] = m_pipe[1] = -1;
            return;
        }

        close(m_pipe[1]);
        m_pipe[1] = -1; // Mark as closed
        m_active = true;
    }

    ~StderrFilter() noexcept
    {
        try {
            cleanup();
        } catch (...) {
            // Swallow exceptions in destructor to prevent std::terminate
        }
    }

private:
    void cleanup() noexcept
    {
        if (!m_active && m_originalStderr == -1) {
            return; // Nothing to clean up
        }

        if (m_active) {
            // Restore original stderr
            fflush(stderr);
            if (m_originalStderr != -1) {
                dup2(m_originalStderr, STDERR_FILENO);
            }

            // Read captured content and filter
            if (m_pipe[0] != -1) {
                std::array<char, 4096> buffer{};
                ssize_t bytesRead = 0;

                // Make read non-blocking
                fcntl(m_pipe[0], F_SETFL, O_NONBLOCK);

                while ((bytesRead = read(m_pipe[0], buffer.data(), buffer.size() - 1)) > 0) {
                    buffer[static_cast<size_t>(bytesRead)] = '\0';

                    // Filter out GTK theme warnings
                    if (std::strstr(buffer.data(), "Theme parsing error") == nullptr &&
                        std::strstr(buffer.data(), "Gtk-WARNING") == nullptr) {
                        // Write non-GTK messages to stderr
                        [[maybe_unused]] auto _ = write(STDERR_FILENO, buffer.data(),
                                                         static_cast<size_t>(bytesRead));
                    }
                }
            }
        }

        // Always cleanup file descriptors, even on partial initialization
        if (m_originalStderr != -1) {
            close(m_originalStderr);
            m_originalStderr = -1;
        }
        if (m_pipe[0] != -1) {
            close(m_pipe[0]);
            m_pipe[0] = -1;
        }
        if (m_pipe[1] != -1) {
            close(m_pipe[1]);
            m_pipe[1] = -1;
        }

        m_active = false;
    }

    int m_originalStderr{-1};
    std::array<int, 2> m_pipe{-1, -1};
    bool m_active{false};
};
#endif

constexpr std::string_view APPLICATION_NAME = "The Wiser One";
constexpr std::string_view APPLICATION_VERSION = "0.0.2";
constexpr std::string_view ORGANIZATION_NAME = "WiserOne";
constexpr std::string_view ORGANIZATION_DOMAIN = "wiserone.com";

/**
 * @brief Convert string_view to QString
 */
[[nodiscard]] inline QString toQString(std::string_view sv) noexcept
{
    return QString::fromUtf8(sv.data(), static_cast<qsizetype>(sv.size()));
}

/**
 * @brief Configure application metadata
 */
void configureApplication(QApplication& app)
{
    app.setApplicationName(toQString(APPLICATION_NAME));
    app.setApplicationVersion(toQString(APPLICATION_VERSION));
    app.setOrganizationName(toQString(ORGANIZATION_NAME));
    app.setOrganizationDomain(toQString(ORGANIZATION_DOMAIN));

    // Set application icon (used in window decorations, taskbar, etc.)
    QIcon appIcon;
    appIcon.addFile(QStringLiteral(":/icons/icon-16.png"), QSize(16, 16));
    appIcon.addFile(QStringLiteral(":/icons/icon-32.png"), QSize(32, 32));
    appIcon.addFile(QStringLiteral(":/icons/icon-128.png"), QSize(128, 128));
    appIcon.addFile(QStringLiteral(":/icons/icon-256.png"), QSize(256, 256));
    appIcon.addFile(QStringLiteral(":/icons/icon-512.png"), QSize(512, 512));
    app.setWindowIcon(appIcon);

    // Tray app: don't quit when all windows are closed
    app.setQuitOnLastWindowClosed(false);
}

/**
 * @brief Load translations for the current locale
 */
void loadTranslations(QApplication& app)
{
    const QLocale locale;

    // Load Qt's built-in translations
    if (auto* qtTranslator = new QTranslator(&app);
        qtTranslator->load(locale,
                           QStringLiteral("qtbase"),
                           QStringLiteral("_"),
                           QLibraryInfo::path(QLibraryInfo::TranslationsPath))) {
        app.installTranslator(qtTranslator);
    }

    // Load application translations
    if (auto* appTranslator = new QTranslator(&app);
        appTranslator->load(locale,
                            QStringLiteral("wiserone"),
                            QStringLiteral("_"),
                            QStringLiteral(":/translations"))) {
        app.installTranslator(appTranslator);
    }
}

}  // namespace

/**
 * @brief Application entry point
 */
int main(int argc, char* argv[])
{
    // Use Fusion style for consistent cross-platform appearance
    qputenv("QT_STYLE_OVERRIDE", "Fusion");

#ifdef Q_OS_UNIX
    // Filter stderr during Qt initialization to suppress cosmetic GTK warnings
    StderrFilter stderrFilter;
#endif

    QApplication app(argc, argv);
    configureApplication(app);
    loadTranslations(app);

    Application wiserApp;

    if (auto result = wiserApp.tryInitialize(); !result.has_value()) {
        QMessageBox::critical(
            nullptr,
            QObject::tr("The Wiser One"),
            QObject::tr("Failed to initialize application.\n"
                        "System tray may not be available."));
        return 1;
    }

    return app.exec();
}
