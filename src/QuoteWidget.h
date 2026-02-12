// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#ifndef QUOTEWIDGET_H
#define QUOTEWIDGET_H

#include "IQuoteProvider.h"

#include <memory>

#include <QAccessible>
#include <QLabel>
#include <QPushButton>
#include <QSvgWidget>
#include <QVBoxLayout>
#include <QWidget>

class AboutDialog;

/**
 * @brief Quote display popup widget
 *
 * A frameless popup window that displays quotes with a logo
 * and action buttons (refresh, website, settings).
 */
class QuoteWidget : public QWidget {
    Q_OBJECT

public:
    /**
     * @brief Construct a new QuoteWidget with default quote provider
     * @param parent Parent widget
     */
    explicit QuoteWidget(QWidget* parent = nullptr);

    /**
     * @brief Construct a new QuoteWidget with custom quote provider
     * @param provider Quote provider instance
     * @param parent Parent widget
     */
    explicit QuoteWidget(std::unique_ptr<IQuoteProvider> provider, QWidget* parent = nullptr);
    ~QuoteWidget() override;

    // Non-copyable (QWidget)
    QuoteWidget(const QuoteWidget&) = delete;
    QuoteWidget& operator=(const QuoteWidget&) = delete;

    /**
     * @brief Show the widget with a new random quote
     */
    void showWithNewQuote();

    /**
     * @brief Position the widget near a specific point
     * @param point Screen position to position near
     */
    void positionNear(const QPoint& point);

signals:
    void refreshRequested();
    void websiteRequested();
    void settingsRequested();

protected:
    void focusOutEvent(QFocusEvent* event) override;
    bool event(QEvent* event) override;
    void mousePressEvent(QMouseEvent* event) override;
    void keyPressEvent(QKeyEvent* event) override;

private:
    void setupUI();
    void setupButtonBar(QVBoxLayout* mainLayout);
    void setupAccessibility();
    [[nodiscard]] QPushButton* createActionButton(const QString& iconPath, const QString& tooltip);
    void updateQuote();
    void openWebsite();
    void showAboutDialog();
    [[nodiscard]] bool isPointOnLogo(const QPoint& point) const;
    [[nodiscard]] bool isPointOnButtonBar(const QPoint& point) const;

    QSvgWidget* m_logoWidget{nullptr};
    QLabel* m_quoteLabel{nullptr};
    QLabel* m_authorLabel{nullptr};
    QWidget* m_buttonBar{nullptr};
    QPushButton* m_refreshButton{nullptr};
    QPushButton* m_webButton{nullptr};
    QPushButton* m_settingsButton{nullptr};
    AboutDialog* m_aboutDialog{nullptr};
    std::unique_ptr<IQuoteProvider> m_quoteProvider;

    static constexpr int WINDOW_WIDTH = 300;
    static constexpr int WINDOW_HEIGHT = 340;
    static constexpr int LOGO_SIZE = 80;
    static constexpr int TOP_MARGIN = 16;
    static constexpr int SIDE_MARGIN = 16;
    static constexpr int LOGO_QUOTE_GAP = 8;
    static constexpr int BUTTON_SIZE = 36;
    static constexpr int BUTTON_ICON_SIZE = 16;
    static constexpr int BUTTON_SPACING = 24;
};

#endif  // QUOTEWIDGET_H
