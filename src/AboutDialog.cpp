// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#include "AboutDialog.h"

#include <QApplication>
#include <QDesktopServices>
#include <QFile>
#include <QFont>
#include <QGuiApplication>
#include <QHBoxLayout>
#include <QLabel>
#include <QPainter>
#include <QPushButton>
#include <QRegularExpression>
#include <QScreen>
#include <QStyleHints>
#include <QSvgRenderer>
#include <QShowEvent>
#include <QUrl>
#include <QVBoxLayout>

namespace {
constexpr const char* WISERONE_TITLE = "The Wiser One";
constexpr const char* WISERONE_VERSION = "0.0.2";
constexpr const char* WISERONE_DESCRIPTION = "Daily nuggets of wisdom\nin a clean, minimalist design";
constexpr const char* WISERONE_COPYRIGHT = "2024-2026 WiserOne";
constexpr const char* WISERONE_WEBSITE = "https://wiserone.com";
constexpr const char* LOGO_RESOURCE = ":/logo.svg";

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

    // Also handle paths without explicit fill (add fill attribute)
    if (!svgString.contains(QStringLiteral("fill="))) {
        svgString.replace(QStringLiteral("<path "),
                         QStringLiteral("<path fill=\"%1\" ").arg(colorStr));
    }

    return svgString.toUtf8();
}

[[nodiscard]] bool isDarkTheme()
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
    const auto colorScheme = QGuiApplication::styleHints()->colorScheme();
    if (colorScheme == Qt::ColorScheme::Dark) {
        return true;
    }
    if (colorScheme == Qt::ColorScheme::Light) {
        return false;
    }
#endif
    const QPalette palette = QGuiApplication::palette();
    const QColor windowColor = palette.color(QPalette::Window);
    const QColor textColor = palette.color(QPalette::WindowText);

    auto luminance = [](const QColor& c) {
        return 0.299 * c.redF() + 0.587 * c.greenF() + 0.114 * c.blueF();
    };

    return luminance(textColor) > luminance(windowColor);
}

[[nodiscard]] QPixmap createThemedLogo(int size)
{
    QFile svgFile(QString::fromUtf8(LOGO_RESOURCE));
    if (!svgFile.open(QIODevice::ReadOnly)) {
        return {};
    }

    const QByteArray svgData = svgFile.readAll();

    // Use explicit dark/light detection for reliable macOS support
    const QColor logoColor = isDarkTheme() ? Qt::white : Qt::black;
    const QByteArray coloredSvg = recolorSvg(svgData, logoColor);

    QSvgRenderer renderer(coloredSvg);
    if (!renderer.isValid()) {
        return {};
    }

    const qreal dpr = QGuiApplication::primaryScreen()->devicePixelRatio();
    const int pixelSize = static_cast<int>(size * dpr);

    QPixmap pixmap(pixelSize, pixelSize);
    pixmap.setDevicePixelRatio(dpr);
    pixmap.fill(Qt::transparent);

    QPainter painter(&pixmap);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);
    renderer.render(&painter, QRectF(0, 0, size, size));

    return pixmap;
}

}  // namespace

AboutDialog::AboutDialog(QWidget* parent)
    : QDialog(parent, Qt::Dialog | Qt::WindowCloseButtonHint)
{
    setWindowTitle(tr("About"));
    setFixedWidth(DIALOG_WIDTH);
    setWindowIcon(QIcon(createThemedLogo(32)));
    setupUI();
    adjustSize();
}

void AboutDialog::setupUI()
{
    auto* mainLayout = new QVBoxLayout(this);
    mainLayout->setSpacing(12);
    mainLayout->setContentsMargins(24, 24, 24, 24);

    // Logo - centered, themed
    m_logoLabel = new QLabel(this);
    m_logoLabel->setPixmap(createThemedLogo(LOGO_SIZE));
    m_logoLabel->setFixedSize(LOGO_SIZE, LOGO_SIZE);
    m_logoLabel->setAlignment(Qt::AlignCenter);

    auto* logoLayout = new QHBoxLayout();
    logoLayout->addStretch();
    logoLayout->addWidget(m_logoLabel);
    logoLayout->addStretch();
    mainLayout->addLayout(logoLayout);

    mainLayout->addSpacing(8);

    // Title
    m_titleLabel = new QLabel(QString::fromUtf8(WISERONE_TITLE), this);
    QFont titleFont = QApplication::font();
    titleFont.setPointSize(18);
    titleFont.setWeight(QFont::Bold);
    m_titleLabel->setFont(titleFont);
    m_titleLabel->setAlignment(Qt::AlignCenter);
    mainLayout->addWidget(m_titleLabel);

    // Version
    m_versionLabel = new QLabel(tr("Version %1").arg(QString::fromUtf8(WISERONE_VERSION)), this);
    QFont versionFont = QApplication::font();
    versionFont.setPointSize(11);
    m_versionLabel->setFont(versionFont);
    m_versionLabel->setAlignment(Qt::AlignCenter);
    QPalette versionPal = m_versionLabel->palette();
    versionPal.setColor(QPalette::WindowText, versionPal.color(QPalette::WindowText).darker(130));
    m_versionLabel->setPalette(versionPal);
    mainLayout->addWidget(m_versionLabel);

    mainLayout->addSpacing(8);

    // Description
    m_descriptionLabel = new QLabel(QString::fromUtf8(WISERONE_DESCRIPTION), this);
    m_descriptionLabel->setAlignment(Qt::AlignCenter);
    m_descriptionLabel->setWordWrap(true);
    mainLayout->addWidget(m_descriptionLabel);

    mainLayout->addSpacing(12);

    // Website link
    m_websiteLabel = new QLabel(this);
    m_websiteLabel->setText(
        QStringLiteral("<a href=\"%1\" style=\"color: #3584e4;\">%1</a>")
            .arg(QString::fromUtf8(WISERONE_WEBSITE)));
    m_websiteLabel->setOpenExternalLinks(true);
    m_websiteLabel->setAlignment(Qt::AlignCenter);
    mainLayout->addWidget(m_websiteLabel);

    mainLayout->addSpacing(8);

    // Copyright
    m_copyrightLabel = new QLabel(QStringLiteral("\u00A9 %1").arg(QString::fromUtf8(WISERONE_COPYRIGHT)), this);
    QFont copyrightFont = QApplication::font();
    copyrightFont.setPointSize(10);
    m_copyrightLabel->setFont(copyrightFont);
    m_copyrightLabel->setAlignment(Qt::AlignCenter);
    QPalette copyrightPal = m_copyrightLabel->palette();
    copyrightPal.setColor(QPalette::WindowText, copyrightPal.color(QPalette::WindowText).darker(150));
    m_copyrightLabel->setPalette(copyrightPal);
    mainLayout->addWidget(m_copyrightLabel);

    mainLayout->addSpacing(16);

    // Close button
    auto* buttonLayout = new QHBoxLayout();
    buttonLayout->addStretch();
    auto* closeButton = new QPushButton(tr("Close"), this);
    closeButton->setMinimumWidth(80);
    connect(closeButton, &QPushButton::clicked, this, &QDialog::accept);
    buttonLayout->addWidget(closeButton);
    buttonLayout->addStretch();
    mainLayout->addLayout(buttonLayout);

    setLayout(mainLayout);
}

void AboutDialog::showEvent(QShowEvent* event)
{
    QDialog::showEvent(event);
    updateLogo();
}

void AboutDialog::updateLogo()
{
    m_logoLabel->setPixmap(createThemedLogo(LOGO_SIZE));
    setWindowIcon(QIcon(createThemedLogo(32)));
}
