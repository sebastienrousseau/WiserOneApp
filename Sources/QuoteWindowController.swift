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
//
//  QuoteWindowController.swift
//  The Wiser One
//
//  Created by Sebastien Rousseau on 27/01/2024.
//

import Cocoa

/// Manages the main application window, displaying dynamic content through a `QuoteViewController`.
class QuoteWindowController: NSWindowController, NSWindowDelegate {
    // Provides direct access to the `QuoteViewController`, ensuring type safety and ease of customization.
    var quoteViewController: QuoteViewController {
        return window?.contentViewController as! QuoteViewController
    }

    /// Initializes a new window with a `QuoteViewController` as its content, dynamically sizing the window and centering it on the screen.
    init() {
        super.init(window: nil) // Call super with nil and setup the window in the next steps.

        let contentViewController = QuoteViewController()
        let contentSize = contentViewController.view.fittingSize

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.title = "Quote of the Day"
        window.contentViewController = contentViewController

        self.window = window // Assign the newly created window to the window property of NSWindowController.
        window.delegate = self // Set this class as the delegate to handle window events.
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: NSWindowDelegate Methods

    /// Implement NSWindowDelegate methods here to handle window events, such as closing or resizing, in custom ways if needed.
    func windowWillClose(_: Notification) {
        // Custom handling of the window closing event.
    }

    // Additional NSWindowDelegate methods can be implemented as required.

    // MARK: - Public API Documentation

    /// Initializes the `QuoteWindowController` with a `QuoteViewController` as its content, setting up the window appropriately.
    /// This approach allows for dynamic view construction similar to SwiftUI, offering flexibility in content management and window behavior.
    ///
    /// The window is sized based on the content's requirements and centered on the screen, providing an optimal user experience.
    ///
    /// Usage of this class is intended for scenarios where a code-based UI is preferred over storyboards or nibs, aligning with modern SwiftUI practices.
    ///
    /// - Note: This class does not support initialization from a storyboard or nib and will throw a fatal error if attempted.
}
