#if canImport(Cocoa)
import Cocoa
import XCTest
@testable import WiserOne

@MainActor
final class WiserOneUITests: XCTestCase {
    func testQuoteViewControllerLoadsContentAndKeepsFixedSize() {
        let sut = QuoteViewController()

        sut.loadView()
        sut.viewWillAppear()

        XCTAssertEqual(sut.preferredContentSize, QuoteViewController.fixedPopoverSize)
        XCTAssertFalse(sut.quoteTextView.string.isEmpty)
        XCTAssertFalse(sut.authorTextField.stringValue.isEmpty)
        XCTAssertTrue(sut.authorTextField.stringValue.hasPrefix("— "))
    }

    func testRefreshForMenuBarClickKeepsContentValid() {
        let sut = QuoteViewController()

        sut.loadView()
        sut.viewWillAppear()
        let initialQuote = sut.quoteTextView.string

        sut.refreshForMenuBarClick()
        sut.refreshForMenuBarClick()

        XCTAssertEqual(sut.preferredContentSize, QuoteViewController.fixedPopoverSize)
        XCTAssertFalse(sut.quoteTextView.string.isEmpty)
        XCTAssertFalse(sut.authorTextField.stringValue.isEmpty)
        XCTAssertTrue(sut.authorTextField.stringValue.hasPrefix("— "))

        // With multi-file datasets, quote text should rotate on repeated menu-bar clicks.
        XCTAssertNotEqual(sut.quoteTextView.string, initialQuote)
    }

    func testRefreshBeforeViewLoadStillRendersQuote() {
        let sut = QuoteViewController()

        // Mirrors menu-bar refresh calls that can happen before explicit view access.
        sut.refreshForMenuBarClick()
        sut.viewWillAppear()

        XCTAssertFalse(sut.quoteTextView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertFalse(sut.authorTextField.stringValue.isEmpty)
    }

    func testAppDelegateInitializesStatusItemAndPopoverController() {
        let sut = AppDelegate()

        sut.applicationDidFinishLaunching(Notification(name: Notification.Name("WiserOneUITestLaunch")))

        XCTAssertNotNil(sut.statusBarItem)
        XCTAssertTrue(sut.popover.animates)
        XCTAssertEqual(sut.popover.contentSize, QuoteViewController.fixedPopoverSize)
        XCTAssertTrue(sut.popover.contentViewController is QuoteViewController)
        XCTAssertEqual(sut.statusItemContextMenu.items.count, 1)
        XCTAssertEqual(sut.statusItemContextMenu.items.first?.title, "Quit WiserOne")
    }
}
#endif
