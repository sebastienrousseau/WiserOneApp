// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#ifndef ABOUTDIALOG_H
#define ABOUTDIALOG_H

#include <QDialog>
#include <QTime>

#include <vector>

class QCheckBox;
class QLabel;
class QListWidget;
class QuoteScheduler;
class QTimeEdit;

/**
 * @brief About dialog showing application information and notification settings
 *
 * Displays application logo, name, version, and links.
 * Also provides notification scheduling configuration.
 */
class AboutDialog : public QDialog {
    Q_OBJECT

public:
    /**
     * @brief Construct a new About Dialog
     * @param scheduler Pointer to the QuoteScheduler for notification settings
     * @param parent Parent widget for modal behavior (optional)
     */
    explicit AboutDialog(QuoteScheduler* scheduler, QWidget* parent = nullptr);

    ~AboutDialog() override = default;

    AboutDialog(const AboutDialog&) = delete;
    AboutDialog& operator=(const AboutDialog&) = delete;

protected:
    void showEvent(QShowEvent* event) override;

private slots:
    void onNotificationsToggled(bool enabled);
    void onAddTime();
    void onRemoveTime();

private:
    void setupUI();
    void setupAboutTab(QWidget* tab);
    void setupNotificationsTab(QWidget* tab);
    void updateLogo();
    void refreshTimeList();

    QuoteScheduler* m_scheduler;

    // About tab
    QLabel* m_logoLabel{nullptr};
    QLabel* m_titleLabel{nullptr};
    QLabel* m_versionLabel{nullptr};
    QLabel* m_descriptionLabel{nullptr};
    QLabel* m_copyrightLabel{nullptr};
    QLabel* m_websiteLabel{nullptr};

    // Notifications tab
    QCheckBox* m_enableCheckbox{nullptr};
    QListWidget* m_timeList{nullptr};
    QTimeEdit* m_timeEdit{nullptr};

    static constexpr int DIALOG_WIDTH = 380;
    static constexpr int LOGO_SIZE = 80;
};

#endif  // ABOUTDIALOG_H
