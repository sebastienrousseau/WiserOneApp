// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#include "AboutDialog.h"

#include "QuoteScheduler.h"

#include <QApplication>
#include <QCheckBox>
#include <QDesktopServices>
#include <QFile>
#include <QFont>
#include <QGuiApplication>
#include <QHBoxLayout>
#include <QLabel>
#include <QListWidget>
#include <QPainter>
#include <QPushButton>
#include <QRegularExpression>
#include <QScreen>
#include <QShowEvent>
#include <QStyleHints>
#include <QSvgRenderer>
#include <QTabWidget>
#include <QTimeEdit>
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

AboutDialog::AboutDialog(QuoteScheduler* scheduler, QWidget* parent)
    : QDialog(parent, Qt::Dialog | Qt::WindowCloseButtonHint)
    , m_scheduler(scheduler)
{
    setWindowTitle(tr("Settings"));
    setFixedWidth(DIALOG_WIDTH);
    setWindowIcon(QIcon(createThemedLogo(32)));
    setupUI();
    adjustSize();
}

void AboutDialog::setupUI()
{
    auto* mainLayout = new QVBoxLayout(this);
    mainLayout->setSpacing(8);
    mainLayout->setContentsMargins(12, 12, 12, 12);

    auto* tabWidget = new QTabWidget(this);

    // About tab
    auto* aboutTab = new QWidget();
    setupAboutTab(aboutTab);
    tabWidget->addTab(aboutTab, tr("About"));

    // Notifications tab
    auto* notifTab = new QWidget();
    setupNotificationsTab(notifTab);
    tabWidget->addTab(notifTab, tr("Notifications"));

    mainLayout->addWidget(tabWidget);

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

void AboutDialog::setupAboutTab(QWidget* tab)
{
    auto* layout = new QVBoxLayout(tab);
    layout->setSpacing(12);
    layout->setContentsMargins(16, 16, 16, 16);

    // Logo - centered, themed
    m_logoLabel = new QLabel(tab);
    m_logoLabel->setPixmap(createThemedLogo(LOGO_SIZE));
    m_logoLabel->setFixedSize(LOGO_SIZE, LOGO_SIZE);
    m_logoLabel->setAlignment(Qt::AlignCenter);

    auto* logoLayout = new QHBoxLayout();
    logoLayout->addStretch();
    logoLayout->addWidget(m_logoLabel);
    logoLayout->addStretch();
    layout->addLayout(logoLayout);

    layout->addSpacing(8);

    // Title
    m_titleLabel = new QLabel(QString::fromUtf8(WISERONE_TITLE), tab);
    QFont titleFont = QApplication::font();
    titleFont.setPointSize(18);
    titleFont.setWeight(QFont::Bold);
    m_titleLabel->setFont(titleFont);
    m_titleLabel->setAlignment(Qt::AlignCenter);
    layout->addWidget(m_titleLabel);

    // Version
    m_versionLabel = new QLabel(tr("Version %1").arg(QString::fromUtf8(WISERONE_VERSION)), tab);
    QFont versionFont = QApplication::font();
    versionFont.setPointSize(11);
    m_versionLabel->setFont(versionFont);
    m_versionLabel->setAlignment(Qt::AlignCenter);
    layout->addWidget(m_versionLabel);

    layout->addSpacing(8);

    // Description
    m_descriptionLabel = new QLabel(QString::fromUtf8(WISERONE_DESCRIPTION), tab);
    m_descriptionLabel->setAlignment(Qt::AlignCenter);
    m_descriptionLabel->setWordWrap(true);
    layout->addWidget(m_descriptionLabel);

    layout->addSpacing(12);

    // Website link
    m_websiteLabel = new QLabel(tab);
    m_websiteLabel->setText(
        QStringLiteral("<a href=\"%1\" style=\"color: #3584e4;\">%1</a>")
            .arg(QString::fromUtf8(WISERONE_WEBSITE)));
    m_websiteLabel->setOpenExternalLinks(true);
    m_websiteLabel->setAlignment(Qt::AlignCenter);
    layout->addWidget(m_websiteLabel);

    layout->addSpacing(8);

    // Copyright
    m_copyrightLabel = new QLabel(QStringLiteral("\u00A9 %1").arg(QString::fromUtf8(WISERONE_COPYRIGHT)), tab);
    QFont copyrightFont = QApplication::font();
    copyrightFont.setPointSize(10);
    m_copyrightLabel->setFont(copyrightFont);
    m_copyrightLabel->setAlignment(Qt::AlignCenter);
    layout->addWidget(m_copyrightLabel);

    layout->addStretch();
}

void AboutDialog::setupNotificationsTab(QWidget* tab)
{
    auto* layout = new QVBoxLayout(tab);
    layout->setSpacing(12);
    layout->setContentsMargins(16, 16, 16, 16);

    // Enable/disable toggle
    m_enableCheckbox = new QCheckBox(tr("Enable daily quote notifications"), tab);
    if (m_scheduler) {
        m_enableCheckbox->setChecked(m_scheduler->isEnabled());
    }
    connect(m_enableCheckbox, &QCheckBox::toggled,
            this, &AboutDialog::onNotificationsToggled);
    layout->addWidget(m_enableCheckbox);

    layout->addSpacing(8);

    // Scheduled times label
    auto* timesLabel = new QLabel(tr("Notification times:"), tab);
    QFont timesFont = QApplication::font();
    timesFont.setWeight(QFont::DemiBold);
    timesLabel->setFont(timesFont);
    layout->addWidget(timesLabel);

    // Time list
    m_timeList = new QListWidget(tab);
    m_timeList->setMaximumHeight(120);
    layout->addWidget(m_timeList);

    // Add time controls
    auto* addLayout = new QHBoxLayout();
    m_timeEdit = new QTimeEdit(QTime(9, 0), tab);
    m_timeEdit->setDisplayFormat(QStringLiteral("HH:mm"));
    addLayout->addWidget(m_timeEdit);

    auto* addButton = new QPushButton(tr("Add"), tab);
    connect(addButton, &QPushButton::clicked, this, &AboutDialog::onAddTime);
    addLayout->addWidget(addButton);

    auto* removeButton = new QPushButton(tr("Remove"), tab);
    connect(removeButton, &QPushButton::clicked, this, &AboutDialog::onRemoveTime);
    addLayout->addWidget(removeButton);

    layout->addLayout(addLayout);

    layout->addStretch();

    // Populate the time list
    refreshTimeList();

    // Set initial enabled state of controls
    const bool enabled = m_enableCheckbox->isChecked();
    m_timeList->setEnabled(enabled);
    m_timeEdit->setEnabled(enabled);
}

void AboutDialog::showEvent(QShowEvent* event)
{
    QDialog::showEvent(event);
    updateLogo();

    // Refresh notification state from scheduler
    if (m_scheduler && m_enableCheckbox) {
        m_enableCheckbox->setChecked(m_scheduler->isEnabled());
        refreshTimeList();
    }
}

void AboutDialog::updateLogo()
{
    m_logoLabel->setPixmap(createThemedLogo(LOGO_SIZE));
    setWindowIcon(QIcon(createThemedLogo(32)));

    const bool dark = isDarkTheme();
    const QColor mutedColor = dark ? QColor(200, 200, 200) : QColor(80, 80, 80);

    QPalette versionPal = m_versionLabel->palette();
    versionPal.setColor(QPalette::WindowText, mutedColor);
    m_versionLabel->setPalette(versionPal);

    QPalette copyrightPal = m_copyrightLabel->palette();
    copyrightPal.setColor(QPalette::WindowText, mutedColor);
    m_copyrightLabel->setPalette(copyrightPal);
}

void AboutDialog::onNotificationsToggled(bool enabled)
{
    if (m_scheduler) {
        m_scheduler->setEnabled(enabled);
    }
    m_timeList->setEnabled(enabled);
    m_timeEdit->setEnabled(enabled);
}

void AboutDialog::onAddTime()
{
    if (!m_scheduler) {
        return;
    }

    const QTime newTime = m_timeEdit->time();
    auto times = m_scheduler->scheduledTimes();

    // Don't add duplicates
    for (const auto& t : times) {
        if (t == newTime) {
            return;
        }
    }

    times.push_back(newTime);
    m_scheduler->setScheduledTimes(times);
    refreshTimeList();
}

void AboutDialog::onRemoveTime()
{
    if (!m_scheduler || !m_timeList->currentItem()) {
        return;
    }

    const int row = m_timeList->currentRow();
    auto times = m_scheduler->scheduledTimes();

    if (row >= 0 && static_cast<size_t>(row) < times.size()) {
        times.erase(times.begin() + row);
        m_scheduler->setScheduledTimes(times);
        refreshTimeList();
    }
}

void AboutDialog::refreshTimeList()
{
    if (!m_timeList || !m_scheduler) {
        return;
    }

    m_timeList->clear();
    for (const auto& time : m_scheduler->scheduledTimes()) {
        m_timeList->addItem(time.toString(QStringLiteral("HH:mm")));
    }
}
