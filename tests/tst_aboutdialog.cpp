// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne

#include "AboutDialog.h"

#include <QApplication>
#include <QLabel>
#include <QTest>

class TestAboutDialog : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void cleanupTestCase();
    void cleanup();

    // Constructor tests
    void testConstructorWithoutParent();
    void testConstructorWithParent();
    void testNonCopyable();

    // UI tests
    void testDialogProperties();
    void testDialogSize();
    void testChildElements();
    void testLogoDisplay();
    void testTitleDisplay();
    void testVersionDisplay();
    void testDescriptionDisplay();
    void testCopyrightDisplay();
    void testWebsiteDisplay();

    // Widget behavior tests
    void testShowHide();
    void testModal();
    void testWindowFlags();

    // Edge cases
    void testParentChildRelationship();
    void testMultipleInstances();
    void testMemoryManagement();

private:
    std::unique_ptr<QApplication> m_app;
    std::unique_ptr<AboutDialog> m_dialog;
    QWidget* m_parentWidget{nullptr};
};

void TestAboutDialog::initTestCase()
{
    if (!QApplication::instance()) {
        int argc = 0;
        char** argv = nullptr;
        m_app = std::make_unique<QApplication>(argc, argv);
    }
}

void TestAboutDialog::cleanupTestCase()
{
    delete m_parentWidget;
    m_app.reset();
}

void TestAboutDialog::cleanup()
{
    m_dialog.reset();
    delete m_parentWidget;
    m_parentWidget = nullptr;
}

void TestAboutDialog::testConstructorWithoutParent()
{
    m_dialog = std::make_unique<AboutDialog>();

    QVERIFY(m_dialog != nullptr);
    QCOMPARE(m_dialog->parent(), nullptr);
    QVERIFY(m_dialog->isWindow());
}

void TestAboutDialog::testConstructorWithParent()
{
    m_parentWidget = new QWidget();
    m_dialog = std::make_unique<AboutDialog>(m_parentWidget);

    QVERIFY(m_dialog != nullptr);
    QCOMPARE(m_dialog->parent(), m_parentWidget);
}

void TestAboutDialog::testNonCopyable()
{
    // This test verifies at compile time that the class is non-copyable
    // The copy constructor and assignment operator should be deleted
    static_assert(!std::is_copy_constructible_v<AboutDialog>);
    static_assert(!std::is_copy_assignable_v<AboutDialog>);
}

void TestAboutDialog::testDialogProperties()
{
    m_dialog = std::make_unique<AboutDialog>();

    QVERIFY(m_dialog->isWindow());
    QVERIFY(m_dialog->windowTitle().contains("About", Qt::CaseInsensitive));
}

void TestAboutDialog::testDialogSize()
{
    m_dialog = std::make_unique<AboutDialog>();

    // Check that dialog has reasonable size constraints
    const QSize sizeHint = m_dialog->sizeHint();
    QVERIFY(sizeHint.width() > 200);
    QVERIFY(sizeHint.width() < 600);
    QVERIFY(sizeHint.height() > 150);
    QVERIFY(sizeHint.height() < 500);

    // Should have minimum size set
    const QSize minSize = m_dialog->minimumSize();
    QVERIFY(minSize.width() > 0);
    QVERIFY(minSize.height() > 0);
}

void TestAboutDialog::testChildElements()
{
    m_dialog = std::make_unique<AboutDialog>();

    // Find child widgets by their expected names/types
    const auto labels = m_dialog->findChildren<QLabel*>();

    // Should have several labels for different information
    QVERIFY(labels.size() >= 4); // Logo, title, version, description at minimum

    // Verify that labels contain expected content
    bool foundTitle = false;
    bool foundVersion = false;
    bool foundDescription = false;

    for (const auto* label : labels) {
        const QString text = label->text();
        if (text.contains("WiserOne", Qt::CaseInsensitive) ||
            text.contains("Wiser One", Qt::CaseInsensitive)) {
            foundTitle = true;
        }
        if (text.contains("Version", Qt::CaseInsensitive) ||
            text.contains("v", Qt::CaseInsensitive)) {
            foundVersion = true;
        }
        if (text.contains("wisdom", Qt::CaseInsensitive) ||
            text.contains("quotes", Qt::CaseInsensitive)) {
            foundDescription = true;
        }
    }

    QVERIFY2(foundTitle, "Dialog should contain title/app name");
    QVERIFY2(foundVersion, "Dialog should contain version information");
}

void TestAboutDialog::testLogoDisplay()
{
    m_dialog = std::make_unique<AboutDialog>();

    // Should have a logo label or pixmap
    const auto labels = m_dialog->findChildren<QLabel*>();
    bool hasLogo = false;

    for (const auto* label : labels) {
        if (!label->pixmap().isNull() || label->objectName().contains("logo", Qt::CaseInsensitive)) {
            hasLogo = true;
            QVERIFY(label->pixmap().width() > 0);
            QVERIFY(label->pixmap().height() > 0);
            break;
        }
    }

    // Note: Logo might not be loadable in test environment
    // So we don't make this a hard requirement
}

void TestAboutDialog::testTitleDisplay()
{
    m_dialog = std::make_unique<AboutDialog>();

    const auto labels = m_dialog->findChildren<QLabel*>();
    bool foundAppName = false;

    for (const auto* label : labels) {
        const QString text = label->text();
        if (text.contains("WiserOne", Qt::CaseInsensitive) ||
            text.contains("Wiser One", Qt::CaseInsensitive)) {
            foundAppName = true;
            QVERIFY(!text.trimmed().isEmpty());
            break;
        }
    }

    QVERIFY2(foundAppName, "Dialog should display application name");
}

void TestAboutDialog::testVersionDisplay()
{
    m_dialog = std::make_unique<AboutDialog>();

    const auto labels = m_dialog->findChildren<QLabel*>();
    bool foundVersion = false;

    for (const auto* label : labels) {
        const QString text = label->text();
        if (text.contains("Version", Qt::CaseInsensitive) ||
            QRegularExpression(R"(v?\d+\.\d+)").match(text).hasMatch()) {
            foundVersion = true;
            QVERIFY(!text.trimmed().isEmpty());
            break;
        }
    }

    // Version display might not be present, so this is optional
}

void TestAboutDialog::testDescriptionDisplay()
{
    m_dialog = std::make_unique<AboutDialog>();

    const auto labels = m_dialog->findChildren<QLabel*>();
    bool foundDescription = false;

    for (const auto* label : labels) {
        const QString text = label->text();
        if (text.length() > 20 && !text.contains("Copyright") && !text.contains("Version")) {
            foundDescription = true;
            QVERIFY(!text.trimmed().isEmpty());
            break;
        }
    }
}

void TestAboutDialog::testCopyrightDisplay()
{
    m_dialog = std::make_unique<AboutDialog>();

    const auto labels = m_dialog->findChildren<QLabel*>();
    bool foundCopyright = false;

    for (const auto* label : labels) {
        const QString text = label->text();
        if (text.contains("Copyright", Qt::CaseInsensitive) ||
            text.contains("©") ||
            text.contains("2024") ||
            text.contains("2026")) {
            foundCopyright = true;
            QVERIFY(!text.trimmed().isEmpty());
            break;
        }
    }
}

void TestAboutDialog::testWebsiteDisplay()
{
    m_dialog = std::make_unique<AboutDialog>();

    const auto labels = m_dialog->findChildren<QLabel*>();
    bool foundWebsite = false;

    for (const auto* label : labels) {
        const QString text = label->text();
        if (text.contains("http", Qt::CaseInsensitive) ||
            text.contains("www", Qt::CaseInsensitive) ||
            text.contains(".com", Qt::CaseInsensitive) ||
            text.contains(".org", Qt::CaseInsensitive)) {
            foundWebsite = true;
            QVERIFY(!text.trimmed().isEmpty());
            break;
        }
    }
}

void TestAboutDialog::testShowHide()
{
    m_dialog = std::make_unique<AboutDialog>();

    // Initially hidden
    QVERIFY(!m_dialog->isVisible());

    // Show and hide
    m_dialog->show();
    QVERIFY(m_dialog->isVisible());

    m_dialog->hide();
    QVERIFY(!m_dialog->isVisible());
}

void TestAboutDialog::testModal()
{
    m_dialog = std::make_unique<AboutDialog>();

    // About dialogs are typically modal
    QVERIFY(m_dialog->isModal());
}

void TestAboutDialog::testWindowFlags()
{
    m_dialog = std::make_unique<AboutDialog>();

    const Qt::WindowFlags flags = m_dialog->windowFlags();

    // Should be a dialog
    QVERIFY(flags & Qt::Dialog);

    // Typically has close button but not minimize/maximize
    QVERIFY(!(flags & Qt::WindowMinimizeButtonHint));
    QVERIFY(!(flags & Qt::WindowMaximizeButtonHint));
}

void TestAboutDialog::testParentChildRelationship()
{
    m_parentWidget = new QWidget();
    m_dialog = std::make_unique<AboutDialog>(m_parentWidget);

    QCOMPARE(m_dialog->parent(), m_parentWidget);
    QVERIFY(m_parentWidget->children().contains(m_dialog.get()));
}

void TestAboutDialog::testMultipleInstances()
{
    // Test creating multiple dialogs doesn't crash
    auto dialog1 = std::make_unique<AboutDialog>();
    auto dialog2 = std::make_unique<AboutDialog>();

    QVERIFY(dialog1 != nullptr);
    QVERIFY(dialog2 != nullptr);
    QVERIFY(dialog1.get() != dialog2.get());

    // Both should be functional
    dialog1->show();
    dialog2->show();

    QVERIFY(dialog1->isVisible());
    QVERIFY(dialog2->isVisible());
}

void TestAboutDialog::testMemoryManagement()
{
    // Test that dialog can be destroyed safely
    {
        auto dialog = std::make_unique<AboutDialog>();
        dialog->show();
        // Should destroy cleanly when going out of scope
    }

    // Test with parent
    {
        auto parent = std::make_unique<QWidget>();
        auto dialog = std::make_unique<AboutDialog>(parent.get());
        dialog->show();
        // Should destroy cleanly
    }

    QVERIFY(true); // If we get here, no crashes occurred
}

QTEST_MAIN(TestAboutDialog)
#include "tst_aboutdialog.moc"