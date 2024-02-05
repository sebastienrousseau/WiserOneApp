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
//  QuoteViewController.swift
//  The Wiser One
//
//  Created by Sebastien Rousseau on 27/01/2024.
//

import Cocoa

/// Model to store a quote's information.
struct Quote: Decodable {
    let quote_text: String
    let author: String
    let date_added: String
    let image_url: String
}

/// Encapsulates quotes array to facilitate JSON decoding.
struct Quotes: Decodable {
    let quotes: [Quote]
}

/// Displays quotes in app UI. Designed for macOS, not iOS.
class QuoteViewController: NSViewController {
    // Text field to display the quote. It is an implicitly unwrapped optional because its value will be set after the view controller's view is loaded.
    // swiftlint:disable:next implicitly_unwrapped_optional
    var textField: NSTextField!

    // Sets up the view controller's view with necessary UI elements.
    // swiftlint:disable:next function_body_length
    override func loadView() {

        // Defines the dimensions of the view.
        let viewWidth: CGFloat = 300
        let viewHeight: CGFloat = 300
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: viewWidth, height: viewHeight))
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = nil

        // Configuration for a button to potentially trigger an action (e.g., load a new quote).
        let button = NSButton()
        let bundle: Bundle

        #if SWIFT_PACKAGE
        bundle = Bundle.module
        #else
        bundle = Bundle.main
        #endif

        // Attempts to load an image asset for the button.
        let logoImageName = "logo"
        if let logoImage = bundle.image(forResource: NSImage.Name(logoImageName)) {
            button.image = logoImage
        } else {
            print("Unable to load logo image asset")
            return
        }

        button.imageScaling = .scaleProportionallyUpOrDown
        button.bezelStyle = .shadowlessSquare
        button.refusesFirstResponder = true
        button.isBordered = false
        button.setButtonType(.momentaryChange)
        button.setPeriodicDelay(0.1, interval: 0.2)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = #selector(buttonClicked)
        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            button.widthAnchor.constraint(equalToConstant: 99),
            button.heightAnchor.constraint(equalToConstant: 99)
        ])

        textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.isEditable = false
        textField.isSelectable = false
        textField.font = NSFont.systemFont(ofSize: 22, weight: .light)
        textField.textColor = nil
        textField.backgroundColor = nil
        textField.isBezeled = false
        textField.alignment = .center
        textField.lineBreakMode = .byWordWrapping
        textField.maximumNumberOfLines = 6
        textField.preferredMaxLayoutWidth = viewWidth * 1.618
        view.addSubview(textField)

        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 10),
            textField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            textField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        loadRandomQuote()
    }

    /// This method is called when the view is about to appear on the screen.
    /// It calls the `loadRandomQuote()` method to load a random quote.
    override func viewWillAppear() {
        super.viewWillAppear()
        loadRandomQuote()
    }

    /// Handles the button click event.
    ///
    /// - Parameter sender: The button that was clicked.
    /// - Note: This method opens the Wiser One website in the default web browser when the button is clicked.
    ///
    @objc func buttonClicked(sender: NSButton) {
        if let url = URL(string: "https://wiserone.com") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Function to get the current month as a two-digit string
    func getCurrentMonth() -> String {
        let date = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        return String(format: "%02d", month) // Formats the month to a two-digit string
    }

    ///
    /// Retrieves a random quote from a JSON file based on the provided month.
    ///
    /// - Parameters:
    ///     - month: The month for which to retrieve the quote.
    /// - Returns: A randomly selected `Quote` object.
    /// - Note: This function dynamically creates the file name based on the `month`
    /// parameter and attempts to load and parse the corresponding JSON file.
    /// If successful, it returns a randomly selected quote from the parsed data.
    /// If the file fails to load or parse, it returns a default "Quote not found"
    /// object.
    ///
    func getQuote(fromMonth month: String) -> Quote {
        let bundle: Bundle

        #if SWIFT_PACKAGE
        bundle = Bundle.module
        #else
        bundle = Bundle.main
        #endif

        // Dynamically create the file name based on the month parameter
        let quotesJSONName = "\(month)-quotes"

        if
            let jsonURL = bundle.url(forResource: quotesJSONName, withExtension: "json"),
            let jsonData = try? Data(contentsOf: jsonURL),
            let quotes = try? JSONDecoder().decode(Quotes.self, from: jsonData) {
            let selectedQuote = quotes.quotes.randomElement() ?? Quote(
                quote_text: "Quote not found",
                author: "Author not found",
                date_added: "Date not found",
                image_url: "Image not found"
            )
            print("Selected quote: \(selectedQuote.quote_text) \(selectedQuote.author)")
            return selectedQuote
        } else {
            print("Failed to load or parse \(quotesJSONName).json")
            return Quote(quote_text: "Quote not found", author: "Author not found", date_added: "Date not found", image_url: "Image not found")
        }
    }

    /// Loads a random quote and displays it in the text field.
    /// - Note: This method retrieves the current month, gets a quote for that month, and displays the quote in the text field.
    func loadRandomQuote() {
        let currentMonth = getCurrentMonth()
        let quote = getQuote(fromMonth: currentMonth)
        textField.stringValue = "\(quote.quote_text)\n\n\(quote.author)"
    }
}
