// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#ifndef ABOUTDIALOG_H
#define ABOUTDIALOG_H

#include <QDialog>

class QLabel;

/**
 * @brief About dialog showing application information
 *
 * Displays application logo, name, version, and links.
 * Styled similar to GNOME Vitals extension preferences.
 */
class AboutDialog : public QDialog {
    Q_OBJECT

public:
    /**
     * @brief Construct a new About Dialog
     * @param parent Parent widget for modal behavior (optional)
     *
     * Creates a modal dialog showing:
     * - Application logo and name
     * - Version information
     * - Copyright and license info
     * - Website link
     *
     * @code{cpp}
     * auto about = new AboutDialog(this);
     * about->exec(); // Show modal
     * about->deleteLater();
     * @endcode
     */
    explicit AboutDialog(QWidget* parent = nullptr);

    /**
     * @brief Destructor - default cleanup
     */
    ~AboutDialog() override = default;

    AboutDialog(const AboutDialog&) = delete;
    AboutDialog& operator=(const AboutDialog&) = delete;

private:
    void setupUI();

    QLabel* m_logoLabel{nullptr};
    QLabel* m_titleLabel{nullptr};
    QLabel* m_versionLabel{nullptr};
    QLabel* m_descriptionLabel{nullptr};
    QLabel* m_copyrightLabel{nullptr};
    QLabel* m_websiteLabel{nullptr};

    static constexpr int DIALOG_WIDTH = 320;
    static constexpr int LOGO_SIZE = 80;
};

#endif  // ABOUTDIALOG_H
