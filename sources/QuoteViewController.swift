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

#if canImport(Cocoa)
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

    private enum QuoteLoadError: Error {
        case missingResource(String)
        case emptyResource(String)
        case resourceTooLarge(String)
        case noValidResources
    }

    private static let maxQuotesPerResource = 10_000
    private static let maxResourceNameLength = 255
    private static let panelCornerRadius: CGFloat = 18
    private static let panelWidth: CGFloat = 300
    private static let panelHeight: CGFloat = 300
    private static let quoteHorizontalPadding: CGFloat = 20
    private static let minQuoteFontSize: CGFloat = 18
    private static let maxQuoteFontSize: CGFloat = 24
    private static let quoteFontScaleFactor: CGFloat = 1.55
    private static let minLogoSize: CGFloat = 84
    private static let maxLogoSize: CGFloat = 112
    private static let logoToFontScaleFactor: CGFloat = 4.8
    private static let authorLabelHeight: CGFloat = 22
    private static let cacheLock = NSLock()
    private static var quotesCache = [String: [Quote]]()
    private static var mergedQuotesCache: [Quote]?
    private static var mergedSourceCountCache = 0
    private static let decoder = JSONDecoder()
    private static let fallbackQuote = Quote(
        quoteText: "Quote not found",
        author: "Author not found",
        dateAdded: "Date not found",
        imageUrl: "Image not found"
    )
    static let fixedPopoverSize = NSSize(width: panelWidth, height: panelHeight)

    /// Scroll container for long quote rendering within fixed popup dimensions.
    var quoteScrollView = NSScrollView()
    /// Text view used to display quote content without truncating long entries.
    var quoteTextView = NSTextView()
    /// Fixed author/signature label kept visible in the popup.
    var authorTextField = NSTextField()
    /// The button to open the Wiser One website.
    var button = NSButton()
    private var activeResourceName = ""
    private var activeQuotes = [Quote]()
    private var activeQuoteIndex = 0
    private var logoWidthConstraint: NSLayoutConstraint?
    private var logoHeightConstraint: NSLayoutConstraint?
    private lazy var resourceBundle: Bundle = {
        #if SWIFT_PACKAGE
            Bundle.module
        #else
            Bundle.main
        #endif
    }()

    // MARK: - View Lifecycle

    /// Loads the view controller's view.
    /// - Note: This method is called automatically when the view controller is loaded.
    override func loadView() {
        /// Sets up the view controller's main view.
        setupView()
        /// Sets up the button in the view controller's view.
        setupButton()
        /// Sets up the author signature label.
        setupAuthorTextField()
        /// Sets up the text field in the view controller's view.
        setupTextField()
    }

    /// Called when the view controller's view is about to be added to the view hierarchy.
    /// - Note: This method is called automatically when the view controller's view is about to be added to the view hierarchy.
    override func viewWillAppear() {
        super.viewWillAppear()
        if quoteTextView.string.isEmpty {
            loadDailyQuote()
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        enforceFixedPopoverSize()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        enforceFixedPopoverSize()
    }

    // MARK: - Setup UI

    /// Sets up the view controller's main view.
    private func setupView() {
        let viewWidth: CGFloat = Self.panelWidth
        let viewHeight: CGFloat = Self.panelHeight
        assert(viewWidth > 0)
        assert(viewHeight > 0)

        let panel = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: viewWidth, height: viewHeight))
        panel.material = .popover
        panel.blendingMode = .withinWindow
        panel.state = .followsWindowActiveState
        panel.appearance = nil

        view = panel
        preferredContentSize = Self.fixedPopoverSize
    }

    /// Sets up the button in the view controller's view.
    private func setupButton() {
        let logoSize = resolvedLogoSize()
        button = NSButton()
        let logoImage = loadPopupLogoImage(size: logoSize) ?? NSImage(named: NSImage.applicationIconName)

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

        logoWidthConstraint = button.widthAnchor.constraint(equalToConstant: logoSize)
        logoHeightConstraint = button.heightAnchor.constraint(equalToConstant: logoSize)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            logoWidthConstraint!,
            logoHeightConstraint!,
        ])
    }

    /// Sets up the quote text area in the view controller's view.
    private func setupTextField() {
        quoteScrollView = NSScrollView()
        quoteScrollView.translatesAutoresizingMaskIntoConstraints = false
        quoteScrollView.drawsBackground = false
        quoteScrollView.borderType = .noBorder
        quoteScrollView.hasVerticalScroller = true
        quoteScrollView.hasHorizontalScroller = false
        quoteScrollView.autohidesScrollers = true
        quoteScrollView.contentInsets = NSEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)

        quoteTextView = NSTextView(frame: .zero)
        quoteTextView.drawsBackground = false
        quoteTextView.isEditable = false
        quoteTextView.isSelectable = true
        quoteTextView.font = NSFont.systemFont(ofSize: resolvedQuoteFontSize(), weight: .medium)
        quoteTextView.textColor = NSColor.labelColor
        quoteTextView.textContainerInset = NSSize(width: 0, height: 2)
        quoteTextView.isHorizontallyResizable = false
        quoteTextView.isVerticallyResizable = true
        quoteTextView.minSize = .zero
        quoteTextView.maxSize = NSSize(
            width: Self.panelWidth - (Self.quoteHorizontalPadding * 2),
            height: CGFloat.greatestFiniteMagnitude
        )
        quoteTextView.textContainer?.lineFragmentPadding = 0
        quoteTextView.textContainer?.widthTracksTextView = true
        quoteTextView.textContainer?.heightTracksTextView = false
        quoteTextView.textContainer?.lineBreakMode = .byWordWrapping
        quoteTextView.textContainer?.maximumNumberOfLines = 0

        quoteScrollView.documentView = quoteTextView
        view.addSubview(quoteScrollView)

        NSLayoutConstraint.activate([
            quoteScrollView.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 10),
            quoteScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            quoteScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            quoteScrollView.bottomAnchor.constraint(equalTo: authorTextField.topAnchor, constant: 0),
        ])
    }

    /// Sets up the fixed author/signature label.
    private func setupAuthorTextField() {
        authorTextField = NSTextField()
        authorTextField.translatesAutoresizingMaskIntoConstraints = false
        authorTextField.isEditable = false
        authorTextField.isSelectable = false
        authorTextField.isBezeled = false
        authorTextField.drawsBackground = false
        authorTextField.alignment = .center
        authorTextField.lineBreakMode = .byTruncatingTail
        authorTextField.maximumNumberOfLines = 1
        authorTextField.font = NSFont.systemFont(ofSize: max(resolvedQuoteFontSize() - 4, 14), weight: .semibold)
        authorTextField.textColor = NSColor.controlAccentColor
        authorTextField.stringValue = ""
        view.addSubview(authorTextField)

        NSLayoutConstraint.activate([
            authorTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            authorTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            authorTextField.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            authorTextField.heightAnchor.constraint(equalToConstant: Self.authorLabelHeight),
        ])
    }

    // MARK: - Actions

    /// Handles the button click event.
    @objc func buttonClicked(sender _: NSButton) {
        assert(Thread.isMainThread, "UI actions must run on the main thread.")
        if let url = URL(string: "https://wiserone.com") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Data Handling

    /// Retrieves the current day-of-year (1...366) for stable daily quote selection.
    private func getCurrentDayOfYear() -> Int {
        let dayOfYear = Calendar.autoupdatingCurrent.ordinality(of: .day, in: .year, for: Date()) ?? 1
        assert(dayOfYear >= 1, "Day-of-year must be at least 1.")
        return dayOfYear
    }

    /// Retrieves the current daily quote from all discoverable quote JSON resources.
    private func getQuote() -> Quote {
        do {
            let (quotes, sourceCount) = try loadDiscoveredQuotes()
            guard !quotes.isEmpty else {
                return Self.fallbackQuote
            }

            let dayOfYear = getCurrentDayOfYear()
            let boundedIndex = max(0, dayOfYear - 1) % quotes.count
            activeResourceName = sourceCount == 1 ? "1 source file" : "\(sourceCount) source files"
            activeQuotes = quotes
            activeQuoteIndex = boundedIndex
            return quotes[boundedIndex]
        } catch {
            print("Failed to discover any valid quote JSON resources.")
            activeResourceName = ""
            activeQuotes = []
            activeQuoteIndex = 0
            return Self.fallbackQuote
        }
    }

    /// Discovers all JSON resources, loads valid quote files, and returns one merged ordered list.
    private func loadDiscoveredQuotes() throws -> ([Quote], Int) {
        if let cached = cachedMergedQuotes() {
            return cached
        }

        let resources = discoverQuoteResources()
        guard !resources.isEmpty else {
            throw QuoteLoadError.noValidResources
        }

        var merged = [Quote]()
        var validSourceCount = 0

        for resource in resources {
            do {
                let quotes = try loadQuotes(named: resource.name, from: resource.url)
                if !quotes.isEmpty {
                    merged.append(contentsOf: quotes)
                    validSourceCount += 1
                }
            } catch {
                // Ignore non-quote or malformed JSON resources to support arbitrary filenames in the folder.
                continue
            }
        }

        guard !merged.isEmpty, validSourceCount > 0 else {
            throw QuoteLoadError.noValidResources
        }

        let sortedMerged = sortQuotesByDate(merged)
        storeMergedQuotes(sortedMerged, sourceCount: validSourceCount)
        return (sortedMerged, validSourceCount)
    }

    /// Discovers JSON quote resources in deterministic order.
    /// When duplicate basenames exist, `sources/resources` variants are preferred over `.xcassets`.
    private func discoverQuoteResources() -> [(name: String, url: URL)] {
        guard let resourceURLs = resourceBundle.urls(forResourcesWithExtension: "json", subdirectory: nil) else {
            return []
        }

        var selected = [String: URL]()

        for url in resourceURLs {
            let resourceName = url.deletingPathExtension().lastPathComponent
            guard !resourceName.isEmpty, resourceName.count <= Self.maxResourceNameLength else {
                continue
            }

            if let existingURL = selected[resourceName] {
                if resourcePriority(for: url) > resourcePriority(for: existingURL) {
                    selected[resourceName] = url
                }
            } else {
                selected[resourceName] = url
            }
        }

        return selected.keys.sorted().compactMap { name in
            guard let url = selected[name] else { return nil }
            return (name: name, url: url)
        }
    }

    /// Gives precedence to quote resources under `resources` to keep runtime behavior stable.
    private func resourcePriority(for url: URL) -> Int {
        let path = url.path
        if path.lowercased().contains("/resources/") {
            return 2
        }
        if path.contains(".xcassets/") {
            return 0
        }
        return 1
    }

    private func loadQuotes(named resourceName: String, from url: URL) throws -> [Quote] {
        assert(!resourceName.isEmpty, "Resource name must not be empty.")
        assert(resourceName.count <= Self.maxResourceNameLength, "Resource name exceeds safe bound.")
        if let cached = cachedQuotes(for: resourceName) {
            return cached
        }

        let jsonData = try Data(contentsOf: url, options: [.mappedIfSafe])
        let decoded = try Self.decoder.decode(Quotes.self, from: jsonData)
        guard !decoded.quotes.isEmpty else {
            throw QuoteLoadError.emptyResource(resourceName)
        }
        guard decoded.quotes.count <= Self.maxQuotesPerResource else {
            throw QuoteLoadError.resourceTooLarge(resourceName)
        }

        storeQuotes(decoded.quotes, for: resourceName)
        return decoded.quotes
    }

    private func cachedQuotes(for resourceName: String) -> [Quote]? {
        Self.cacheLock.lock()
        defer { Self.cacheLock.unlock() }
        return Self.quotesCache[resourceName]
    }

    private func storeQuotes(_ quotes: [Quote], for resourceName: String) {
        assert(!quotes.isEmpty, "Quote cache stores non-empty quote arrays only.")
        assert(quotes.count <= Self.maxQuotesPerResource, "Quote cache input exceeds maximum bound.")

        Self.cacheLock.lock()
        defer { Self.cacheLock.unlock() }
        Self.quotesCache[resourceName] = quotes
    }

    private func cachedMergedQuotes() -> ([Quote], Int)? {
        Self.cacheLock.lock()
        defer { Self.cacheLock.unlock() }
        guard let merged = Self.mergedQuotesCache else {
            return nil
        }
        return (merged, Self.mergedSourceCountCache)
    }

    private func storeMergedQuotes(_ quotes: [Quote], sourceCount: Int) {
        assert(!quotes.isEmpty, "Merged quote cache stores non-empty quote arrays only.")
        assert(sourceCount > 0, "Merged quote cache source count must be positive.")
        Self.cacheLock.lock()
        defer { Self.cacheLock.unlock() }
        Self.mergedQuotesCache = quotes
        Self.mergedSourceCountCache = sourceCount
    }

    /// Mirrors the sister Rust project's stable-by-date ordering for loaded quote collections.
    private func sortQuotesByDate(_ quotes: [Quote]) -> [Quote] {
        assert(!quotes.isEmpty, "Sorting requires non-empty quote collections.")
        return quotes.sorted { lhs, rhs in
            lhs.dateAdded < rhs.dateAdded
        }
    }

    /// Loads a popup logo with the same base asset preference as the menu bar icon.
    private func loadPopupLogoImage(size: CGFloat) -> NSImage? {
        let image = resourceBundle.url(forResource: "logo", withExtension: "svg")
            .flatMap { NSImage(contentsOf: $0) }
            ?? resourceBundle.url(forResource: "logo-menubar", withExtension: "svg")
            .flatMap { NSImage(contentsOf: $0) }
            ?? resourceBundle.image(forResource: NSImage.Name("logo"))
            ?? resourceBundle.image(forResource: NSImage.Name("logo-menubar"))
            ?? NSImage(named: NSImage.Name("logo"))
            ?? NSImage(named: NSImage.Name("logo-menubar"))

        guard let image else { return nil }
        let copy = image.copy() as? NSImage ?? image
        copy.size = NSSize(width: size, height: size)
        return copy
    }

    /// Resolves quote font size from system typography to keep visual consistency with macOS settings.
    private func resolvedQuoteFontSize() -> CGFloat {
        let systemBodySize: CGFloat
        if #available(macOS 11.0, *) {
            systemBodySize = NSFont.preferredFont(forTextStyle: .body).pointSize
        } else {
            systemBodySize = NSFont.systemFontSize
        }

        let scaledSize = systemBodySize * Self.quoteFontScaleFactor
        return min(max(scaledSize, Self.minQuoteFontSize), Self.maxQuoteFontSize)
    }

    /// Keeps the popup logo proportional to text scale without changing popup dimensions.
    private func resolvedLogoSize() -> CGFloat {
        let scaledSize = resolvedQuoteFontSize() * Self.logoToFontScaleFactor
        return min(max(scaledSize, Self.minLogoSize), Self.maxLogoSize)
    }

    /// Loads a deterministic daily quote and displays it in the text field.
    private func loadDailyQuote() {
        assert(Thread.isMainThread, "UI updates must run on the main thread.")
        let quote = getQuote()
        renderQuote(quote, animated: false)
    }

    /// Advances to the next quote in the currently loaded collection.
    private func cycleToNextQuote(animated: Bool) {
        assert(Thread.isMainThread, "UI updates must run on the main thread.")
        guard !activeQuotes.isEmpty else {
            loadDailyQuote()
            return
        }

        let quoteCount = activeQuotes.count
        guard quoteCount > 1 else {
            renderQuote(activeQuotes[0], animated: animated)
            return
        }

        activeQuoteIndex = (activeQuoteIndex + 1) % quoteCount
        assert(activeQuoteIndex >= 0 && activeQuoteIndex < quoteCount, "Quote index must remain in bounds.")
        let quote = activeQuotes[activeQuoteIndex]
        renderQuote(quote, animated: animated)
    }

    /// Renders a quote in the current text field format.
    private func renderQuote(_ quote: Quote, animated: Bool) {
        let quoteText = "\"\(quote.quoteText)\""
        let authorText = "— \(quote.author)"
        applyQuoteText(quoteText)
        authorTextField.stringValue = authorText

        if animated {
            quoteScrollView.alphaValue = 0
            authorTextField.alphaValue = 0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                quoteScrollView.animator().alphaValue = 1
                authorTextField.animator().alphaValue = 1
            }
        } else {
            quoteScrollView.alphaValue = 1
            authorTextField.alphaValue = 1
        }

        assert(!quoteTextView.string.isEmpty, "Quote text should not render as an empty string.")
        assert(!authorTextField.stringValue.isEmpty, "Quote author should not render as an empty string.")
        enforceFixedPopoverSize()
    }

    /// Applies quote text with centered paragraph style and resets scroll position.
    private func applyQuoteText(_ text: String) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: resolvedQuoteFontSize(), weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle,
        ]
        quoteTextView.textStorage?.setAttributedString(NSAttributedString(string: text, attributes: attributes))
        if let scrollView = quoteTextView.enclosingScrollView {
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    /// Prevents dynamic content from changing popover dimensions.
    private func enforceFixedPopoverSize() {
        preferredContentSize = Self.fixedPopoverSize
        view.setFrameSize(Self.fixedPopoverSize)
        if let window = view.window {
            window.contentMinSize = Self.fixedPopoverSize
            window.contentMaxSize = Self.fixedPopoverSize
            window.minSize = Self.fixedPopoverSize
            window.maxSize = Self.fixedPopoverSize
            window.setContentSize(Self.fixedPopoverSize)
        }
    }

    /// Refreshes quote selection for a menu bar icon click.
    func refreshForMenuBarClick() {
        assert(Thread.isMainThread, "UI updates must run on the main thread.")
        if activeQuotes.isEmpty {
            loadDailyQuote()
            return
        }
        cycleToNextQuote(animated: false)
    }
}
#endif
