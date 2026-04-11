// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//  AppDelegate.swift
//  The Wiser One
//
//  Created by Sebastien Rousseau on 27/01/2024.
//

#if canImport(Cocoa)
import Cocoa

// MARK: - Error Definitions

/// Enumerates possible errors within the application for more precise error handling.
enum AppError: Error {
    case statusBarItemButtonNotAvailable
}

// MARK: - AppDelegate

/// The main class responsible for initializing and managing the application's status bar item and its associated popover.
class AppDelegate: NSObject, NSApplicationDelegate {
    private static let minMenuIconSize: CGFloat = 12
    private static let maxMenuIconSize: CGFloat = 32
    private static let menuIconSize: CGFloat = 24
    private static let maxStatusItemSetupAttempts = 10
    private static let statusItemRetryDelay: TimeInterval = 0.2

    var statusBarItem: NSStatusItem?
    private var statusItemSetupAttempts = 0
    private(set) lazy var statusItemContextMenu: NSMenu = {
        let menu = NSMenu(title: "WiserOne")
        let quitItem = NSMenuItem(
            title: "Quit WiserOne",
            action: #selector(quitApplication(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        return menu
    }()

    // Lazy initialization of popover with default behavior set via property.
    lazy var popover: NSPopover = {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        return popover
    }()

    // MARK: - Application Lifecycle

    /// Called when the application has completed its launch setup.
    /// Initializes the status bar item and configures the popover.
    func applicationDidFinishLaunching(_: Notification) {
        _ = NSApplication.shared.setActivationPolicy(.accessory)
        setupPopover()
        setupStatusBarItemWithRetry()
    }

    // MARK: - Status Bar Setup

    /// Initializes and configures the status bar item.
    /// - Throws: `AppError.statusBarItemButtonNotAvailable` if unable to access the status bar item button.
    private func setupStatusBarItem() throws {
        if statusBarItem == nil {
            statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        }
        statusBarItem?.isVisible = true
        guard let button = statusBarItem?.button else {
            throw AppError.statusBarItemButtonNotAvailable
        }
        configureButton(button)
    }

    /// Sets up the status item with bounded retries to avoid a silent launch state.
    private func setupStatusBarItemWithRetry() {
        assert(Thread.isMainThread, "Status item retries must run on the main thread.")
        do {
            try setupStatusBarItem()
            statusItemSetupAttempts = 0
        } catch {
            statusItemSetupAttempts += 1
            if statusItemSetupAttempts < Self.maxStatusItemSetupAttempts {
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.statusItemRetryDelay) { [weak self] in
                    self?.setupStatusBarItemWithRetry()
                }
                return
            }
            handleError(error)
        }
    }

    /// Configures the status bar button with a custom icon and action.
    /// - Parameter button: The `NSStatusBarButton` to configure.
    private func configureButton(_ button: NSStatusBarButton) {
        assert(Thread.isMainThread, "Status bar button configuration must run on the main thread.")
        if let image = createStatusBarImage() {
            button.image = image
            button.imageScaling = .scaleProportionallyDown
            button.imagePosition = .imageOnly
            button.attributedTitle = NSAttributedString(string: "")
        } else {
            button.image = nil
            button.attributedTitle = createFallbackStatusBarTitle()
        }
        button.toolTip = "WiserOne"
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    // MARK: - Popover Management

    /// Prepares the popover for use with application-specific content.
    private func setupPopover() {
        updatePopoverContent(with: QuoteViewController())
    }

    /// Updates the popover's content with a specific `QuoteViewController`.
    /// - Parameter viewController: The `QuoteViewController` instance to display within the popover.
    private func updatePopoverContent(with viewController: QuoteViewController) {
        popover.contentViewController = viewController
        popover.contentSize = QuoteViewController.fixedPopoverSize
    }

    // MARK: - Popover Display Handling

    /// Toggles the popover's visibility based on its current state.
    @objc private func togglePopover(_ sender: Any?) {
        assert(statusBarItem != nil, "Status item must exist before popover toggling.")
        guard let button = statusBarItem?.button else { return }
        if isContextClickEvent(NSApp.currentEvent) {
            showContextMenu(from: button)
            return
        }
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(from: button)
        }
    }

    /// Displays the popover anchored to the provided view.
    /// - Parameter view: The `NSView` from which to anchor the popover.
    private func showPopover(from view: NSView) {
        assert(Thread.isMainThread, "Popover presentation must run on the main thread.")
        if let quoteViewController = popover.contentViewController as? QuoteViewController {
            quoteViewController.refreshForMenuBarClick()
        }
        popover.contentSize = QuoteViewController.fixedPopoverSize
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: NSRectEdge.minY)
        if let window = popover.contentViewController?.view.window {
            window.contentMinSize = QuoteViewController.fixedPopoverSize
            window.contentMaxSize = QuoteViewController.fixedPopoverSize
            window.minSize = QuoteViewController.fixedPopoverSize
            window.maxSize = QuoteViewController.fixedPopoverSize
        }
    }

    /// Closes the popover.
    private func closePopover(_ sender: Any?) {
        popover.performClose(sender)
    }

    private func isContextClickEvent(_ event: NSEvent?) -> Bool {
        guard let event else { return false }

        if event.type == .rightMouseDown || event.type == .rightMouseUp {
            return true
        }

        if (event.type == .leftMouseDown || event.type == .leftMouseUp), event.modifierFlags.contains(.control) {
            return true
        }

        return false
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        closePopover(nil)
        statusItemContextMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 4), in: button)
    }

    @objc private func quitApplication(_ sender: Any?) {
        NSApp.terminate(sender)
    }

    // MARK: - Utility Methods

    /// Builds a template image for status bar rendering in both light and dark modes.
    private func createStatusBarImage() -> NSImage? {
        let bundle = ResourceBundleLocator.resolve()

        let image = bundle.url(forResource: "logo-menubar", withExtension: "svg")
            .flatMap { NSImage(contentsOf: $0) }
            ?? bundle.url(forResource: "logo", withExtension: "svg")
            .flatMap { NSImage(contentsOf: $0) }
            ?? bundle.image(forResource: NSImage.Name("logo-menubar"))
            ?? bundle.image(forResource: NSImage.Name("logo"))
            ?? NSImage(named: NSImage.Name("logo-menubar"))
            ?? NSImage(named: NSImage.Name("logo"))

        guard let image else { return nil }

        let templateImage = image.copy() as? NSImage ?? image
        assert(Self.menuIconSize >= Self.minMenuIconSize, "Menu icon size underflows safe bound.")
        assert(Self.menuIconSize <= Self.maxMenuIconSize, "Menu icon size overflows safe bound.")
        templateImage.isTemplate = true
        templateImage.size = NSSize(width: Self.menuIconSize, height: Self.menuIconSize)
        return templateImage
    }

    /// Builds a fallback glyph title that follows system appearance in the menu bar.
    private func createFallbackStatusBarTitle() -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .black),
            .foregroundColor: NSColor.labelColor,
            .baselineOffset: -1.0,
        ]
        return NSAttributedString(string: "⏣", attributes: attributes)
    }

    // MARK: - Error Handling

    /// Handles errors that occur during application setup and operation, logging them appropriately.
    /// - Parameter error: The error to handle.
    private func handleError(_ error: Error) {
        ErrorLogger.shared.logError(error)

        // Handle specific errors with user feedback or additional logging as needed.
        switch error {
        case AppError.statusBarItemButtonNotAvailable:
            print("Error: Status bar item button not available.")
        default:
            print("An unknown error occurred.")
        }
    }
}
#endif
