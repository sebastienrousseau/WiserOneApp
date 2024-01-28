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

struct Quote: Decodable {
    let quote_text: String
    let author: String
    let date_added: String
    let image_url: String
}

struct Quotes: Decodable {
    let quotes: [Quote]
}

class QuoteViewController: NSViewController {
    // swiftlint:disable:next implicitly_unwrapped_optional
    var textField: NSTextField!

    // swiftlint:disable:next function_body_length
    override func loadView() {
        let viewWidth: CGFloat = 300
        let viewHeight: CGFloat = 300
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: viewWidth, height: viewHeight))
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = nil

        let button = NSButton()
        let bundle: Bundle

        #if SWIFT_PACKAGE
        bundle = Bundle.module
        #else
        bundle = Bundle.main
        #endif

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

    override func viewWillAppear() {
        super.viewWillAppear()
        loadRandomQuote()
    }

    @objc func buttonClicked(sender: NSButton) {
        if let url = URL(string: "https://wiserone.com") {
            NSWorkspace.shared.open(url)
        }
    }

    func getQuote() -> Quote {
        let bundle: Bundle

        #if SWIFT_PACKAGE
        bundle = Bundle.module
        #else
        bundle = Bundle.main
        #endif

        let quotesJSONName = "quotes"

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
            print("Selected quote: \(selectedQuote.quote_text) by \(selectedQuote.author)")
            return selectedQuote
        } else {
            print("Failed to load or parse quotes.json")
            return Quote(quote_text: "Quote not found", author: "", date_added: "", image_url: "")
        }
    }

    func loadRandomQuote() {
        let quote = getQuote()
        textField.stringValue = "\(quote.quote_text)\n\n\(quote.author)"
    }
}
