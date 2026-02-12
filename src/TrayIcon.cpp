// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#include "TrayIcon.h"

#include "AboutDialog.h"
#include "ErrorLogger.h"

#include <QApplication>
#include <QDesktopServices>
#include <QEvent>
#include <QFile>
#include <QGuiApplication>
#include <QPainter>
#include <QProcess>
#include <QRegularExpression>
#include <QScreen>
#include <QStyleHints>
#include <QSvgRenderer>
#include <QUrl>

#include <string_view>

namespace {

constexpr std::string_view WEBSITE_URL = "https://wiserone.com";
constexpr std::string_view ICON_RESOURCE = ":/icons/icon-symbolic.svg";

[[nodiscard]] QByteArray recolorSvg(const QByteArray& svgData, const QColor& newColor)
{
    QString svgString = QString::fromUtf8(svgData);
    static const QRegularExpression fillAttrRegex(
        QStringLiteral("fill=\"#[0-9a-fA-F]{6}\""));
    static const QRegularExpression fillStyleRegex(
        QStringLiteral("fill:#[0-9a-fA-F]{6}"));

    const QString colorStr = newColor.name();
    svgString.replace(fillAttrRegex, QStringLiteral("fill=\"%1\"").arg(colorStr));
    svgString.replace(fillStyleRegex, QStringLiteral("fill:%1").arg(colorStr));

    return svgString.toUtf8();
}

[[nodiscard]] inline QString toQString(std::string_view sv) noexcept
{
    return QString::fromUtf8(sv.data(), static_cast<qsizetype>(sv.size()));
}

}  // namespace

TrayIcon::TrayIcon(QObject* parent)
    : QObject(parent)
    , m_trayIcon(std::make_unique<QSystemTrayIcon>(this))
    , m_contextMenu(std::make_unique<QMenu>())
    , m_quoteManager(std::make_unique<QuoteManager>())
    , m_lastKnownDarkMode(isDarkTheme())
{
    m_trayIcon->setIcon(createSymbolicIcon());
    m_trayIcon->setToolTip(tr("The Wiser One"));

    setupMenu();
    setupConnections();
    updateQuoteDisplay();

    qApp->installEventFilter(this);

#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
    connect(QGuiApplication::styleHints(), &QStyleHints::colorSchemeChanged,
            this, &TrayIcon::updateIconForTheme);
#endif

    // Timer to check theme changes (some DEs don't emit signals)
    m_themeCheckTimer = std::make_unique<QTimer>(this);
    connect(m_themeCheckTimer.get(), &QTimer::timeout, this, &TrayIcon::updateIconForTheme);
    m_themeCheckTimer->start(2000);  // Check every 2 seconds
}

TrayIcon::~TrayIcon() = default;

bool TrayIcon::eventFilter(QObject* watched, QEvent* event)
{
    if (event->type() == QEvent::ApplicationPaletteChange) [[unlikely]] {
        updateIconForTheme();
    }
    return QObject::eventFilter(watched, event);
}

void TrayIcon::setupMenu()
{
    // Quote display - enabled but no action (so it's not greyed out)
    m_quoteAction = m_contextMenu->addAction(QString());
    QFont quoteFont = m_quoteAction->font();
    quoteFont.setPointSize(14);
    quoteFont.setWeight(QFont::DemiBold);
    m_quoteAction->setFont(quoteFont);

    m_authorAction = m_contextMenu->addAction(QString());
    QFont authorFont = m_authorAction->font();
    authorFont.setPointSize(11);
    authorFont.setItalic(true);
    m_authorAction->setFont(authorFont);

    m_contextMenu->addSeparator();

    // Action items with icons (like Vitals)
    // Refresh - same icon as Vitals: view-refresh-symbolic
    auto* refreshAction = m_contextMenu->addAction(
        QIcon::fromTheme(QStringLiteral("view-refresh-symbolic")),
        tr("Refresh"));
    connect(refreshAction, &QAction::triggered, this, &TrayIcon::handleRefresh);

    // Website - web browser icon
    auto* webAction = m_contextMenu->addAction(
        QIcon::fromTheme(QStringLiteral("web-browser-symbolic")),
        tr("Website"));
    connect(webAction, &QAction::triggered, this, &TrayIcon::handleWebsite);

    // Settings/About - same icon as Vitals: preferences-system-symbolic
    auto* settingsAction = m_contextMenu->addAction(
        QIcon::fromTheme(QStringLiteral("preferences-system-symbolic")),
        tr("About"));
    connect(settingsAction, &QAction::triggered, this, &TrayIcon::handleSettings);

    m_contextMenu->addSeparator();

    // Quit action
    auto* const quitAction = m_contextMenu->addAction(tr("Quit"));
    connect(quitAction, &QAction::triggered, this, &TrayIcon::handleQuitAction);

    m_trayIcon->setContextMenu(m_contextMenu.get());
}

void TrayIcon::setupConnections()
{
    connect(m_contextMenu.get(), &QMenu::aboutToShow,
            this, &TrayIcon::handleMenuAboutToShow);

    connect(m_trayIcon.get(), &QSystemTrayIcon::activated,
            this, &TrayIcon::onTrayActivated);
}

bool TrayIcon::isDarkTheme() const noexcept
{
#ifdef Q_OS_LINUX
    // Check GNOME/freedesktop color scheme setting
    QProcess process;
    process.start(QStringLiteral("gsettings"),
                  {QStringLiteral("get"),
                   QStringLiteral("org.gnome.desktop.interface"),
                   QStringLiteral("color-scheme")});
    if (process.waitForFinished(100)) {
        const QString output = QString::fromUtf8(process.readAllStandardOutput()).trimmed();
        if (output.contains(QStringLiteral("dark"), Qt::CaseInsensitive)) {
            return true;
        }
        if (output.contains(QStringLiteral("light"), Qt::CaseInsensitive) ||
            output.contains(QStringLiteral("default"), Qt::CaseInsensitive)) {
            return false;
        }
    }
#endif

    // Fallback: check Qt palette
    const QPalette palette = QGuiApplication::palette();
    const QColor windowColor = palette.color(QPalette::Window);
    const QColor textColor = palette.color(QPalette::WindowText);

    auto luminance = [](const QColor& c) {
        return 0.299 * c.redF() + 0.587 * c.greenF() + 0.114 * c.blueF();
    };

    return luminance(textColor) > luminance(windowColor);
}

void TrayIcon::updateIconForTheme()
{
    const bool currentDark = isDarkTheme();
    if (currentDark != m_lastKnownDarkMode) {
        m_lastKnownDarkMode = currentDark;
        m_trayIcon->setIcon(createSymbolicIcon());
    }
}

bool TrayIcon::isDarkThemeStatic()
{
    const QPalette palette = QGuiApplication::palette();
    const QColor windowColor = palette.color(QPalette::Window);
    const QColor textColor = palette.color(QPalette::WindowText);

    auto luminance = [](const QColor& c) {
        return 0.299 * c.redF() + 0.587 * c.greenF() + 0.114 * c.blueF();
    };

    return luminance(textColor) > luminance(windowColor);
}

QIcon TrayIcon::createSymbolicIcon() const
{
    QFile svgFile(toQString(ICON_RESOURCE));
    if (!svgFile.open(QIODevice::ReadOnly)) {
        ErrorLogger::instance().log(
            QStringLiteral("TrayIcon.cpp"),
            QStringLiteral("createSymbolicIcon"),
            QStringLiteral("Failed to open SVG icon file"));
        return {};
    }

    const QByteArray svgData = svgFile.readAll();
    // Dark theme = white icon, Light theme = black icon
    const QColor iconColor = m_lastKnownDarkMode ? Qt::white : Qt::black;
    const QByteArray coloredSvg = recolorSvg(svgData, iconColor);

    QSvgRenderer renderer(coloredSvg);
    if (!renderer.isValid()) {
        ErrorLogger::instance().log(
            QStringLiteral("TrayIcon.cpp"),
            QStringLiteral("createSymbolicIcon"),
            QStringLiteral("Failed to parse SVG icon"));
        return {};
    }

    const qreal dpr = QApplication::primaryScreen()->devicePixelRatio();
    const int pixelSize = static_cast<int>(ICON_SIZE * dpr);

    QPixmap pixmap(pixelSize, pixelSize);
    pixmap.setDevicePixelRatio(dpr);
    pixmap.fill(Qt::transparent);

    QPainter painter(&pixmap);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);
    renderer.render(&painter, QRectF(0, 0, ICON_SIZE, ICON_SIZE));

    return QIcon(pixmap);
}

bool TrayIcon::show()
{
    if (!isAvailable()) {
        ErrorLogger::instance().log(
            QStringLiteral("TrayIcon.cpp"),
            QStringLiteral("show"),
            QStringLiteral("System tray is not available"));
        return false;
    }
    m_trayIcon->show();
    return true;
}

bool TrayIcon::isAvailable() noexcept
{
    return QSystemTrayIcon::isSystemTrayAvailable();
}

void TrayIcon::onTrayActivated([[maybe_unused]] QSystemTrayIcon::ActivationReason reason)
{
    // Menu handles all interactions on Linux
}

void TrayIcon::handleQuitAction()
{
    emit quitRequested();
    QApplication::quit();
}

void TrayIcon::handleRefresh()
{
    updateQuoteDisplay();
}

void TrayIcon::handleWebsite()
{
    emit websiteRequested();

    const QUrl url(toQString(WEBSITE_URL));
    if (!url.isValid() || url.scheme().compare(QLatin1String("https"), Qt::CaseInsensitive) != 0) {
        ErrorLogger::instance().log(
            QStringLiteral("TrayIcon.cpp"),
            QStringLiteral("handleWebsite"),
            QStringLiteral("Invalid or non-HTTPS URL rejected"));
        return;
    }
    if (!QDesktopServices::openUrl(url)) {
        ErrorLogger::instance().log(
            QStringLiteral("TrayIcon.cpp"),
            QStringLiteral("handleWebsite"),
            QStringLiteral("Failed to open URL"));
    }
}

void TrayIcon::handleSettings()
{
    if (!m_aboutDialog) {
        m_aboutDialog = std::make_unique<AboutDialog>();
    }
    m_aboutDialog->exec();
}

void TrayIcon::handleMenuAboutToShow()
{
    updateQuoteDisplay();
}

void TrayIcon::updateQuoteDisplay()
{
    const Quote& quote = m_quoteManager->getRandomQuote();
    m_quoteAction->setText(tr("\"%1\"").arg(quote.text));
    m_authorAction->setText(tr("— %1").arg(quote.author));
    emit quoteDisplayed(quote.text, quote.author);
}
