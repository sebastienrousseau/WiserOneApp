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

/// Controller to manage the main app window
class QuoteWindowController: NSWindowController {

    /// Default initializer
    init() {

        // Create a temporary content view controller
        let contentViewController = QuoteViewController()

        // Calculate the size of the content dynamically based on its subviews
        let contentSize = contentViewController.view.fittingSize

        // Set the contentRect of the window based on the calculated content size
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        // Center the window on screen
        window.center()

        // Set window title
        window.title = "Quote of the Day"

        // Set this class as the window delegate
        super.init(window: window)

        // Set the view controller as the content
        window.contentViewController = QuoteViewController()
    }

    /// Required coder initializer (not implemented)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
