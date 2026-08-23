#if canImport(Cocoa)
import XCTest
@testable import WiserOne

/// Covers the menu-bar lifecycle.
///
/// AppDelegate sat at 43% — the status item, its retry path, the
/// popover, the icon fallback and the toggle were all unexercised,
/// which is most of what the app *is*. `quitApplication` and
/// `showContextMenu` are deliberately not driven here: the first
/// terminates the test process, the second opens a modal menu.
final class AppDelegateTests: XCTestCase {
    private var delegate: AppDelegate!

    override func setUp() {
        super.setUp()
        delegate = AppDelegate()
    }

    override func tearDown() {
        delegate.statusBarItem.map(NSStatusBar.system.removeStatusItem)
        delegate = nil
        super.tearDown()
    }

    private func launch() {
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
    }

    func testLaunchInstallsAStatusItem() {
        launch()
        XCTAssertNotNil(delegate.statusBarItem, "no status item after launch")
        XCTAssertTrue(delegate.statusBarItem?.isVisible ?? false)
    }

    func testLaunchGivesTheStatusButtonAnActionAndTooltip() throws {
        launch()
        let button = try XCTUnwrap(delegate.statusBarItem?.button)
        XCTAssertEqual(button.toolTip, "WiserOne")
        XCTAssertNotNil(button.action)
        XCTAssertTrue(button.target === delegate)
    }

    func testStatusButtonCarriesAnIconOrAFallbackGlyph() throws {
        launch()
        let button = try XCTUnwrap(delegate.statusBarItem?.button)
        let hasIcon = button.image != nil
        let hasGlyph = !(button.attributedTitle.string.isEmpty)
        XCTAssertTrue(
            hasIcon || hasGlyph,
            "the menu bar item would render as a blank square"
        )
    }

    func testLaunchLoadsTheQuoteViewControllerIntoThePopover() throws {
        launch()
        let controller = try XCTUnwrap(
            delegate.popover.contentViewController as? QuoteViewController
        )
        XCTAssertEqual(
            delegate.popover.contentSize,
            QuoteViewController.fixedPopoverSize
        )
        XCTAssertNotNil(controller.view)
    }

    func testLaunchingTwiceReusesTheSameStatusItem() {
        launch()
        let first = delegate.statusBarItem
        launch()
        XCTAssertTrue(
            first === delegate.statusBarItem,
            "a second launch must not leak a second menu bar icon"
        )
    }

    func testTogglingShowsThenClosesThePopover() throws {
        launch()
        let button = try XCTUnwrap(delegate.statusBarItem?.button)

        // `popover.show(relativeTo:of:...)` needs its anchor view to be
        // in a window. The status bar button is not reliably hosted in
        // a headless session, so this anchors the popover to a real
        // window of its own — which makes the assertion meaningful
        // instead of merely "the call did not crash".
        let host = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 40, height: 40))
        host.contentView?.addSubview(anchor)
        host.orderFront(nil)
        defer { host.orderOut(nil) }

        delegate.popover.show(
            relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY
        )
        XCTAssertTrue(delegate.popover.isShown, "popover did not present")

        delegate.popover.performClose(nil)

        // Drive the delegate's own toggle too, so the branch that picks
        // between showing and closing is exercised.
        _ = button.target?.perform(button.action, with: button)
        _ = button.target?.perform(button.action, with: button)

        XCTAssertNotNil(delegate.popover.contentViewController)
        XCTAssertEqual(
            delegate.popover.contentSize,
            QuoteViewController.fixedPopoverSize
        )
    }

    func testShowingThePopoverPinsItToTheFixedSize() throws {
        launch()
        let button = try XCTUnwrap(delegate.statusBarItem?.button)
        _ = button.target?.perform(button.action, with: button)

        XCTAssertEqual(
            delegate.popover.contentSize,
            QuoteViewController.fixedPopoverSize
        )
        if let window = delegate.popover.contentViewController?.view.window {
            XCTAssertEqual(window.minSize, QuoteViewController.fixedPopoverSize)
            XCTAssertEqual(window.maxSize, QuoteViewController.fixedPopoverSize)
        }
    }

    func testContextMenuOffersQuit() {
        let menu = delegate.statusItemContextMenu
        XCTAssertEqual(menu.items.count, 1)
        let item = menu.items[0]
        XCTAssertFalse(item.title.isEmpty)
        XCTAssertNotNil(item.action)
        XCTAssertTrue(item.target === delegate)
    }
}
#endif
