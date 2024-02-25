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

// MARK: - Models

/// Model to store a quote's information.
/// - Parameters:
///  - quoteText: The quote's text.
///  - author: The quote's author.
///  - dateAdded: The date the quote was added.
///  - imageUrl: The URL of the image associated with the quote.
/// - Returns: A new `Quote` instance.
/// - Note: The `Decodable` protocol is used to facilitate JSON decoding.
///
struct Quote: Decodable {
    /// The quote's text.
    let quoteText: String
    /// The quote's author.
    let author: String
    /// The date the quote was added.
    let dateAdded: String
    /// The URL of the image associated with the quote.
    let imageUrl: String

    /// Coding keys to map the JSON keys to the struct properties.
    /// - Parameters:
    ///  - quoteText: The quote's text.
    ///  - author: The quote's author.
    ///  - dateAdded: The date the quote was added.
    ///  - imageUrl: The URL of the image associated with the quote.
    private enum CodingKeys: String, CodingKey {
        case quoteText = "quote_text"
        case author
        case dateAdded = "date_added"
        case imageUrl = "image_url"
    }
}

/// Encapsulates quotes array to facilitate JSON decoding.
/// - Parameters:
///  - quotes: The quotes array.
/// - Returns: A new `Quotes` instance.
struct Quotes: Decodable {
    /// The quotes array.
    let quotes: [Quote]
}

// MARK: - QuoteViewController

/// Displays quotes in the app UI. Designed for macOS, not iOS.
class QuoteViewController: NSViewController {
    // MARK: Properties

    /// The text field to display the quote.
    var textField = NSTextField()
    /// The button to open the Wiser One website.
    var button = NSButton()

    // MARK: - View Lifecycle

    /// Loads the view controller's view.
    /// - Note: This method is called automatically when the view controller is loaded.
    override func loadView() {
        /// Sets up the view controller's main view.
        setupView()
        /// Sets up the button in the view controller's view.
        setupButton()
        /// Sets up the text field in the view controller's view.
        setupTextField()
    }

    /// Called when the view controller's view is about to be added to the view hierarchy.
    /// - Note: This method is called automatically when the view controller's view is about to be added to the view hierarchy.
    override func viewWillAppear() {
        super.viewWillAppear()
        /// Loads a random quote and displays it in the text field.
        loadRandomQuote()
    }

    // MARK: - Setup UI

    /// Sets up the view controller's main view.
    private func setupView() {
        let viewWidth: CGFloat = 300
        let viewHeight: CGFloat = 300
        view = NSView(frame: NSRect(x: 0, y: 0, width: viewWidth, height: viewHeight))
        view.wantsLayer = true
        view.layer?.backgroundColor = nil
    }

    /// Sets up the button in the view controller's view.
    private func setupButton() {
        button = NSButton()

        #if SWIFT_PACKAGE
            let bundle = Bundle.module
        #else
            let bundle = Bundle.main
        #endif

        let logoImageName = "logo"
        guard let logoImage = bundle.image(forResource: NSImage.Name(logoImageName)) else {
            fatalError("Unable to load logo image asset")
        }

        button.image = logoImage
        button.imageScaling = .scaleProportionallyUpOrDown
        button.bezelStyle = .shadowlessSquare
        button.refusesFirstResponder = true
        button.isBordered = false
        button.setButtonType(.momentaryChange)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = #selector(buttonClicked)
        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            button.widthAnchor.constraint(equalToConstant: 99),
            button.heightAnchor.constraint(equalToConstant: 99),
        ])
    }

    /// Sets up the text field in the view controller's view.
    private func setupTextField() {
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
        textField.preferredMaxLayoutWidth = view.frame.width * 1.618
        view.addSubview(textField)

        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 10),
            textField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            textField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }

    // MARK: - Actions

    /// Handles the button click event.
    @objc func buttonClicked(sender _: NSButton) {
        if let url = URL(string: "https://wiserone.com") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Data Handling

    /// Retrieves the current month as a two-digit string.
    private func getCurrentMonth() -> String {
        let date = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        return String(format: "%02d", month)
    }

    /// Retrieves a random quote from a JSON file based on the provided month.
    private func getQuote(fromMonth month: String) -> Quote {
        #if SWIFT_PACKAGE
            let bundle = Bundle.module
        #else
            let bundle = Bundle.main
        #endif

        let quotesJSONName = "\(month)-quotes"

        guard let jsonURL = bundle.url(forResource: quotesJSONName, withExtension: "json"),
              let jsonData = try? Data(contentsOf: jsonURL),
              let quotes = try? JSONDecoder().decode(Quotes.self, from: jsonData)
        else {
            print("Failed to load or parse \(quotesJSONName).json")
            return Quote(quoteText: "Quote not found", author: "Author not found", dateAdded: "Date not found", imageUrl: "Image not found")
        }

        return quotes.quotes.randomElement() ?? Quote(quoteText: "Quote not found", author: "Author not found", dateAdded: "Date not found", imageUrl: "Image not found")
    }

    /// Loads a random quote and displays it in the text field.
    private func loadRandomQuote() {
        let currentMonth = getCurrentMonth()
        let quote = getQuote(fromMonth: currentMonth)
        textField.stringValue = "\"\(quote.quoteText)\"\n\n\(quote.author)"
    }
}
