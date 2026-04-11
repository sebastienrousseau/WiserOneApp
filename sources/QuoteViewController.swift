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

// MARK: - QuoteViewController

/// Displays quotes in the app UI. Designed for macOS, not iOS.
class QuoteViewController: NSViewController {
    // MARK: Properties
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
    static let fixedPopoverSize = NSSize(width: panelWidth, height: panelHeight)
    private static let quoteContentWidth: CGFloat = panelWidth - (quoteHorizontalPadding * 2)

    /// Scroll container for long quote rendering within fixed popup dimensions.
    var quoteScrollView = NSScrollView()
    /// Text view used to display quote content without truncating long entries.
    var quoteTextView = NSTextView()
    /// Fixed author/signature label kept visible in the popup.
    var authorTextField = NSTextField()
    /// The button to open the Wiser One website.
    var button = NSButton()
    private var logoWidthConstraint: NSLayoutConstraint?
    private var logoHeightConstraint: NSLayoutConstraint?
    private lazy var resourceBundle: Bundle = ResourceBundleLocator.resolve()
    private lazy var quoteService = QuoteService(repository: QuoteRepository(bundle: resourceBundle))

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
        if !quoteService.hasLoadedQuotes {
            loadDailyQuote()
            return
        }

        if quoteTextView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let activeQuote = quoteService.currentQuote()
        {
            renderQuote(activeQuote, animated: false)
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
        panel.wantsLayer = true
        panel.layer?.cornerRadius = Self.panelCornerRadius
        panel.layer?.masksToBounds = true

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
        quoteTextView.isRichText = false
        quoteTextView.importsGraphics = false
        quoteTextView.font = NSFont.systemFont(ofSize: resolvedQuoteFontSize(), weight: .medium)
        quoteTextView.textColor = NSColor.textColor
        quoteTextView.textContainerInset = NSSize(width: 0, height: 2)
        quoteTextView.isHorizontallyResizable = false
        quoteTextView.isVerticallyResizable = true
        quoteTextView.minSize = .zero
        quoteTextView.maxSize = NSSize(
            width: Self.quoteContentWidth,
            height: CGFloat.greatestFiniteMagnitude
        )
        quoteTextView.textContainer?.lineFragmentPadding = 0
        quoteTextView.textContainer?.widthTracksTextView = true
        quoteTextView.textContainer?.heightTracksTextView = false
        quoteTextView.textContainer?.lineBreakMode = .byWordWrapping
        quoteTextView.textContainer?.maximumNumberOfLines = 0
        quoteTextView.frame = NSRect(
            x: 0,
            y: 0,
            width: Self.quoteContentWidth,
            height: 1
        )

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

    /// Retrieves and stores the current daily quote from discovered resources.
    private func getQuote() -> Quote {
        quoteService.loadDailyQuote(dayOfYear: getCurrentDayOfYear())
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
        guard quoteService.hasLoadedQuotes else {
            loadDailyQuote()
            return
        }

        guard let quote = quoteService.cycleToNextQuote() else {
            loadDailyQuote()
            return
        }
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
        assert(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Quote text must not be blank.")
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: resolvedQuoteFontSize(), weight: .medium),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphStyle,
        ]

        let attributedText = NSAttributedString(string: text, attributes: attributes)
        if let textStorage = quoteTextView.textStorage {
            textStorage.setAttributedString(attributedText)
        } else {
            quoteTextView.string = text
            quoteTextView.textColor = NSColor.textColor
            quoteTextView.font = NSFont.systemFont(ofSize: resolvedQuoteFontSize(), weight: .medium)
            quoteTextView.alignment = .center
        }

        if let textContainer = quoteTextView.textContainer,
           let layoutManager = quoteTextView.layoutManager
        {
            let targetWidth = max(quoteScrollView.contentSize.width, Self.quoteContentWidth)
            textContainer.containerSize = NSSize(width: targetWidth, height: CGFloat.greatestFiniteMagnitude)
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let targetHeight = max(usedRect.height + (quoteTextView.textContainerInset.height * 2), quoteScrollView.contentSize.height)
            quoteTextView.setFrameSize(NSSize(width: max(targetWidth, 1), height: max(targetHeight, 1)))
        }

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
        if !isViewLoaded {
            _ = view
        }

        if !quoteService.hasLoadedQuotes {
            loadDailyQuote()
            return
        }
        cycleToNextQuote(animated: false)
    }
}
#endif
