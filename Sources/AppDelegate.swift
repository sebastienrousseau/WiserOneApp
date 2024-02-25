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

// MARK: - Error Handling

/// Enum for error descriptions
enum AppError: Error {
    case statusBarItemButtonNotAvailable
    case popoverSetupFailed(message: String)
    case contentUpdateFailed(message: String)
}

// MARK: - AppDelegate

/// Main class responsible for initializing the application's status bar item and popover.
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var popover: NSPopover?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try setupStatusBarItem()
            setupPopover()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Setup Methods

    /// Sets up the status bar item with a circular attributed string representing the current day.
    private func setupStatusBarItem() throws {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusBarItem?.button else {
            throw AppError.statusBarItemButtonNotAvailable
        }
        configureButton(button)
    }

    /// Configures the button with a circular attributed string.
    /// - Parameter button: The NSStatusBarButton to configure.
    private func configureButton(_ button: NSStatusBarButton) {
        // let day = "\(Calendar.current.component(.day, from: Date()))"
        button.attributedTitle = createStatusBarIcon()
        button.action = #selector(togglePopover(_:))
    }

    // MARK: - Popover Setup

    /// Sets up and configures the popover for the application.
    ///
    /// This method initializes a new `NSPopover` instance, sets its behavior to transient,
    /// and updates its content with a `QuoteViewController` instance. A transient popover will
    /// close automatically when the user interacts with a UI element outside the popover.
    /// The `QuoteViewController` is intended to manage the content displayed within the popover.
    private func setupPopover() {
        // Create a new instance of NSPopover and assign it to the popover property.
        // NSPopover is a class used to manage a popover window.
        popover = NSPopover()

        if let popover = popover {
            // Set the behavior of the popover to .transient.
            // .transient behavior means that the popover will close automatically when the user interacts with a user interface element outside the popover.
            popover.behavior = .transient

            // Call the updatePopoverContent function, passing in a new instance of QuoteViewController.
            // This function is presumably designed to configure the content of the popover with the provided view controller.
            // QuoteViewController() is a custom view controller that you want to display inside the popover.
            updatePopoverContent(with: QuoteViewController())
        }
    }

    // MARK: - Utility Methods

    /// Creates an icon for the status bar item
    /// - Parameter string: The string to display in the icon.
    private func createStatusBarIcon() -> NSAttributedString {
    let font = NSFont.systemFont(ofSize: 22, weight: .bold) // Your chosen font size
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.labelColor,
        .baselineOffset: NSNumber(value: -2) // Adjust this value as needed
    ]
    return NSAttributedString(string: "⏣", attributes: attributes)
}


    /// Updates the popover's content with a given view controller.
    /// - Parameter viewController: The view controller to display in the popover.
    private func updatePopoverContent(with viewController: NSViewController) {
        popover?.contentViewController = viewController
        popover?.contentSize = viewController.view.frame.size
    }

    // MARK: - Popover Display Handling

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusBarItem?.button else { return }
        if popover?.isShown == true {
            closePopover(sender)
        } else {
            showPopover(from: button)
        }
    }

    private func showPopover(from view: NSView) {
        popover?.show(relativeTo: view.bounds, of: view, preferredEdge: NSRectEdge.minY)
        popover?.contentViewController?.view.window?.makeKey()
    }

    private func closePopover(_ sender: Any?) {
        popover?.performClose(sender)

    }

    // MARK: - Error Handling

    /// Handles errors that occur during application setup and operation.
    /// - Parameter error: The error to handle.
    private func handleError(_ error: Error) {
        ErrorLogger.shared.logError(error)

        switch error {
        case AppError.statusBarItemButtonNotAvailable:
            print("Status bar item button not available")
        case let AppError.popoverSetupFailed(message):
            print("Popover setup failed: \(message)")
        case let AppError.contentUpdateFailed(message):
            print("Content update failed: \(message)")
        default:
            break
        }
    }
}
