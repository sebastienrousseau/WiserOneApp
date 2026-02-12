// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#include "QuoteWidget.h"

#include "AboutDialog.h"
#include "ErrorLogger.h"
#include "QuoteProviderFactory.h"

#include <QApplication>
#include <QDesktopServices>
#include <QFile>
#include <QFocusEvent>
#include <QFont>
#include <QGraphicsDropShadowEffect>
#include <QHBoxLayout>
#include <QKeyEvent>
#include <QMouseEvent>
#include <QPainter>
#include <QPalette>
#include <QRegularExpression>
#include <QScreen>
#include <QSvgRenderer>
#include <QUrl>

#include <string_view>

namespace {
constexpr std::string_view WEBSITE_URL = "https://wiserone.com";
constexpr std::string_view LOGO_RESOURCE = ":/logo.svg";
constexpr std::string_view REFRESH_ICON = ":/icons/refresh-symbolic.svg";
constexpr std::string_view WEB_ICON = ":/icons/web-symbolic.svg";
constexpr std::string_view SETTINGS_ICON = ":/icons/settings-symbolic.svg";

[[nodiscard]] inline QString toQString(std::string_view sv) noexcept
{
    return QString::fromUtf8(sv.data(), static_cast<qsizetype>(sv.size()));
}

/**
 * @brief Recolor SVG fill color for theme adaptation
 */
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

/**
 * @brief Create a pixmap from SVG with theme-appropriate color
 */
[[nodiscard]] QIcon createThemedIcon(const QString& svgPath, int size)
{
    QFile svgFile(svgPath);
    if (!svgFile.open(QIODevice::ReadOnly)) {
        return {};
    }

    const QByteArray svgData = svgFile.readAll();
    const QColor iconColor = QApplication::palette().color(QPalette::WindowText);
    const QByteArray coloredSvg = recolorSvg(svgData, iconColor);

    QSvgRenderer renderer(coloredSvg);
    if (!renderer.isValid()) {
        return {};
    }

    const qreal dpr = QApplication::primaryScreen()->devicePixelRatio();
    const int pixelSize = static_cast<int>(size * dpr);

    QPixmap pixmap(pixelSize, pixelSize);
    pixmap.setDevicePixelRatio(dpr);
    pixmap.fill(Qt::transparent);

    QPainter painter(&pixmap);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);
    renderer.render(&painter, QRectF(0, 0, size, size));

    return QIcon(pixmap);
}

}  // namespace

QuoteWidget::QuoteWidget(QWidget* parent)
    : QWidget(parent, Qt::Window | Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint)
    , m_quoteProvider(QuoteProviderFactory::createDefault())
{
    setupUI();
    setupAccessibility();
    setFocusPolicy(Qt::StrongFocus);
    setWindowTitle(QStringLiteral("The Wiser One"));

    // Center on screen
    if (QScreen* screen = QApplication::primaryScreen()) {
        const QRect screenGeometry = screen->availableGeometry();
        move(screenGeometry.center() - rect().center());
    }
}

QuoteWidget::QuoteWidget(std::unique_ptr<IQuoteProvider> provider, QWidget* parent)
    : QWidget(parent, Qt::Window | Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint)
    , m_quoteProvider(std::move(provider))
{
    setupUI();
    setupAccessibility();
    setFocusPolicy(Qt::StrongFocus);
    setWindowTitle(QStringLiteral("The Wiser One"));

    // Center on screen
    if (QScreen* screen = QApplication::primaryScreen()) {
        const QRect screenGeometry = screen->availableGeometry();
        move(screenGeometry.center() - rect().center());
    }
}

QuoteWidget::~QuoteWidget()
{
    delete m_aboutDialog;
}

void QuoteWidget::setupUI()
{
    setFixedSize(WINDOW_WIDTH, WINDOW_HEIGHT);

    // Use system palette for colors (supports dark/light mode)
    setAutoFillBackground(true);

    // Main layout
    auto* mainLayout = new QVBoxLayout(this);
    mainLayout->setContentsMargins(SIDE_MARGIN, TOP_MARGIN, SIDE_MARGIN, SIDE_MARGIN);
    mainLayout->setSpacing(0);

    // Logo widget - centered
    m_logoWidget = new QSvgWidget(toQString(LOGO_RESOURCE), this);
    m_logoWidget->setFixedSize(LOGO_SIZE, LOGO_SIZE);
    m_logoWidget->setCursor(Qt::PointingHandCursor);

    // Center the logo
    auto* logoLayout = new QHBoxLayout();
    logoLayout->addStretch();
    logoLayout->addWidget(m_logoWidget);
    logoLayout->addStretch();
    mainLayout->addLayout(logoLayout);

    // Gap between logo and quote
    mainLayout->addSpacing(LOGO_QUOTE_GAP);

    // Quote label - 20pt light font, centered, word wrap
    m_quoteLabel = new QLabel(this);
    QFont quoteFont = QApplication::font();
    quoteFont.setPointSize(20);
    quoteFont.setWeight(QFont::Light);
    m_quoteLabel->setFont(quoteFont);
    m_quoteLabel->setAlignment(Qt::AlignHCenter | Qt::AlignTop);
    m_quoteLabel->setWordWrap(true);
    m_quoteLabel->setTextFormat(Qt::PlainText);

    mainLayout->addWidget(m_quoteLabel, 1);

    // Author label - smaller, centered
    m_authorLabel = new QLabel(this);
    QFont authorFont = QApplication::font();
    authorFont.setPointSize(12);
    authorFont.setWeight(QFont::Light);
    m_authorLabel->setFont(authorFont);
    m_authorLabel->setAlignment(Qt::AlignHCenter | Qt::AlignTop);

    mainLayout->addWidget(m_authorLabel);
    mainLayout->addStretch();

    // Button bar at bottom
    setupButtonBar(mainLayout);

    setLayout(mainLayout);
}

void QuoteWidget::setupButtonBar(QVBoxLayout* mainLayout)
{
    m_buttonBar = new QWidget(this);
    auto* buttonLayout = new QHBoxLayout(m_buttonBar);
    buttonLayout->setContentsMargins(0, 8, 0, 0);
    buttonLayout->setSpacing(BUTTON_SPACING);

    buttonLayout->addStretch();

    // Refresh button (left)
    m_refreshButton = createActionButton(toQString(REFRESH_ICON), tr("Refresh"));
    connect(m_refreshButton, &QPushButton::clicked, this, [this]() {
        updateQuote();
        emit refreshRequested();
    });
    buttonLayout->addWidget(m_refreshButton);

    // Website button (center)
    m_webButton = createActionButton(toQString(WEB_ICON), tr("Visit Website"));
    connect(m_webButton, &QPushButton::clicked, this, [this]() {
        openWebsite();
        emit websiteRequested();
    });
    buttonLayout->addWidget(m_webButton);

    // Settings button (right)
    m_settingsButton = createActionButton(toQString(SETTINGS_ICON), tr("About"));
    connect(m_settingsButton, &QPushButton::clicked, this, [this]() {
        showAboutDialog();
        emit settingsRequested();
    });
    buttonLayout->addWidget(m_settingsButton);

    buttonLayout->addStretch();

    mainLayout->addWidget(m_buttonBar);
}

QPushButton* QuoteWidget::createActionButton(const QString& iconPath, const QString& tooltip)
{
    auto* button = new QPushButton(this);
    button->setFixedSize(BUTTON_SIZE, BUTTON_SIZE);
    button->setIcon(createThemedIcon(iconPath, BUTTON_ICON_SIZE));
    button->setIconSize(QSize(BUTTON_ICON_SIZE, BUTTON_ICON_SIZE));
    button->setToolTip(tooltip);
    button->setCursor(Qt::PointingHandCursor);
    button->setFocusPolicy(Qt::TabFocus);

    // Circular button style like Vitals
    button->setStyleSheet(QStringLiteral(
        "QPushButton {"
        "  border-radius: %1px;"
        "  border: 1px solid transparent;"
        "  background-color: transparent;"
        "  padding: 8px;"
        "}"
        "QPushButton:hover {"
        "  border-color: #777777;"
        "  background-color: rgba(127, 127, 127, 30);"
        "}"
        "QPushButton:pressed {"
        "  background-color: rgba(127, 127, 127, 60);"
        "}")
        .arg(BUTTON_SIZE / 2));

    return button;
}

void QuoteWidget::showWithNewQuote()
{
    updateQuote();

    // Center on screen each time
    if (QScreen* screen = QApplication::primaryScreen()) {
        const QRect screenGeometry = screen->availableGeometry();
        move(screenGeometry.center() - rect().center());
    }

    show();
    raise();
    activateWindow();
}

void QuoteWidget::updateQuote()
{
    const Quote& quote = m_quoteProvider->getRandomQuote();
    m_quoteLabel->setText(QStringLiteral("\"%1\"").arg(quote.text));
    m_authorLabel->setText(quote.author);
}

void QuoteWidget::positionNear(const QPoint& point)
{
    QScreen* screen = QApplication::screenAt(point);
    if (screen == nullptr) {
        screen = QApplication::primaryScreen();
    }

    const QRect screenGeometry = screen->availableGeometry();
    int x = point.x() - width() / 2;
    int y = point.y();

    // Adjust to keep on screen
    if (x + width() > screenGeometry.right()) {
        x = screenGeometry.right() - width();
    }
    if (x < screenGeometry.left()) {
        x = screenGeometry.left();
    }

    // Position below the point if there's room, otherwise above
    if (y + height() > screenGeometry.bottom()) {
        y = point.y() - height();
    }

    move(x, y);
}

void QuoteWidget::focusOutEvent([[maybe_unused]] QFocusEvent* event)
{
    // Don't auto-hide on focus out - let user click to close
}

bool QuoteWidget::event(QEvent* event)
{
    return QWidget::event(event);
}

void QuoteWidget::keyPressEvent(QKeyEvent* event)
{
    if (event->key() == Qt::Key_Escape) {
        hide();
    }
    QWidget::keyPressEvent(event);
}

void QuoteWidget::mousePressEvent(QMouseEvent* event)
{
    // Don't close if clicking on button bar or logo
    if (isPointOnButtonBar(event->pos())) {
        return;
    }

    if (isPointOnLogo(event->pos())) {
        openWebsite();
    } else {
        // Click outside logo and buttons closes the window
        hide();
    }
    QWidget::mousePressEvent(event);
}

bool QuoteWidget::isPointOnLogo(const QPoint& point) const
{
    if (m_logoWidget != nullptr) {
        const QPoint logoPos = m_logoWidget->mapTo(this, QPoint(0, 0));
        const QRect absoluteLogoRect(logoPos, m_logoWidget->size());
        return absoluteLogoRect.contains(point);
    }
    return false;
}

bool QuoteWidget::isPointOnButtonBar(const QPoint& point) const
{
    if (m_buttonBar != nullptr) {
        const QPoint barPos = m_buttonBar->mapTo(this, QPoint(0, 0));
        const QRect absoluteBarRect(barPos, m_buttonBar->size());
        return absoluteBarRect.contains(point);
    }
    return false;
}

void QuoteWidget::openWebsite()
{
    const QUrl url(toQString(WEBSITE_URL));
    if (!url.isValid() || url.scheme().compare(QLatin1String("https"), Qt::CaseInsensitive) != 0) {
        ErrorLogger::instance().log(
            QStringLiteral("QuoteWidget.cpp"),
            QStringLiteral("openWebsite"),
            QStringLiteral("Invalid or non-HTTPS URL rejected: %1").arg(toQString(WEBSITE_URL)));
        return;
    }
    if (!QDesktopServices::openUrl(url)) {
        ErrorLogger::instance().log(
            QStringLiteral("QuoteWidget.cpp"),
            QStringLiteral("openWebsite"),
            QStringLiteral("Failed to open URL: %1").arg(toQString(WEBSITE_URL)));
    }
}

void QuoteWidget::showAboutDialog()
{
    if (m_aboutDialog == nullptr) {
        m_aboutDialog = new AboutDialog(this);
    }
    m_aboutDialog->exec();
}

void QuoteWidget::setupAccessibility()
{
    // Set accessibility properties for the main widget
    setAccessibleName(tr("The Wiser One Quote Widget"));
    setAccessibleDescription(tr("Displays inspirational quotes with refresh, website, and settings buttons"));

    // Set accessibility properties for quote display elements
    if (m_quoteLabel) {
        m_quoteLabel->setAccessibleName(tr("Quote Text"));
        m_quoteLabel->setAccessibleDescription(tr("Current inspirational quote"));
    }

    if (m_authorLabel) {
        m_authorLabel->setAccessibleName(tr("Quote Author"));
        m_authorLabel->setAccessibleDescription(tr("Author of the current quote"));
    }

    // Set accessibility properties for buttons with proper roles
    if (m_refreshButton) {
        m_refreshButton->setAccessibleName(tr("Refresh Quote"));
        m_refreshButton->setAccessibleDescription(tr("Get a new random quote"));
        m_refreshButton->setFocusPolicy(Qt::TabFocus);
    }

    if (m_webButton) {
        m_webButton->setAccessibleName(tr("Visit Website"));
        m_webButton->setAccessibleDescription(tr("Open WiserOne website in default browser"));
        m_webButton->setFocusPolicy(Qt::TabFocus);
    }

    if (m_settingsButton) {
        m_settingsButton->setAccessibleName(tr("About"));
        m_settingsButton->setAccessibleDescription(tr("Show about dialog with application information"));
        m_settingsButton->setFocusPolicy(Qt::TabFocus);
    }

    // Set accessible role for the logo area
    if (m_logoWidget) {
        m_logoWidget->setAccessibleName(tr("WiserOne Logo"));
        m_logoWidget->setAccessibleDescription(tr("WiserOne application logo, click to visit website"));
        m_logoWidget->setFocusPolicy(Qt::TabFocus);
    }
}
