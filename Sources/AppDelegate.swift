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

import Cocoa

// MARK: - Error Definitions

/// Enumerates possible errors within the application for more precise error handling.
enum AppError: Error {
    case statusBarItemButtonNotAvailable
    case popoverSetupFailed(message: String)
    case contentUpdateFailed(message: String)
}

// MARK: - AppDelegate

/// The main class responsible for initializing and managing the application's status bar item and its associated popover.
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?

    // Lazy initialization of popover with default behavior set via property.
    lazy var popover: NSPopover = {
        let popover = NSPopover()
        popover.behavior = .transient
        return popover
    }()

    // MARK: - Application Lifecycle

    /// Called when the application has completed its launch setup.
    /// Initializes the status bar item and configures the popover.
    func applicationDidFinishLaunching(_: Notification) {
        do {
            try setupStatusBarItem()
            setupPopover()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Status Bar Setup

    /// Initializes and configures the status bar item.
    /// - Throws: `AppError.statusBarItemButtonNotAvailable` if unable to access the status bar item button.
    private func setupStatusBarItem() throws {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusBarItem?.button else {
            throw AppError.statusBarItemButtonNotAvailable
        }
        configureButton(button)
    }

    /// Configures the status bar button with a custom icon and action.
    /// - Parameter button: The `NSStatusBarButton` to configure.
    private func configureButton(_ button: NSStatusBarButton) {
        button.attributedTitle = createStatusBarIcon()
        button.action = #selector(togglePopover(_:))
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
        popover.contentSize = viewController.view.frame.size
    }

    // MARK: - Popover Display Handling

    /// Toggles the popover's visibility based on its current state.
    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusBarItem?.button else { return }
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(from: button)
        }
    }

    /// Displays the popover anchored to the provided view.
    /// - Parameter view: The `NSView` from which to anchor the popover.
    private func showPopover(from view: NSView) {
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: NSRectEdge.minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    /// Closes the popover.
    private func closePopover(_ sender: Any?) {
        popover.performClose(sender)
    }

    // MARK: - Utility Methods

    /// Creates a custom icon for the status bar item.
    /// - Returns: An `NSAttributedString` representing the icon.
    private func createStatusBarIcon() -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: 22, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .baselineOffset: NSNumber(value: -2),
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
        case let AppError.popoverSetupFailed(message),
             let AppError.contentUpdateFailed(message):
            print("Error: \(message)")
        default:
            print("An unknown error occurred.")
        }
    }
}
