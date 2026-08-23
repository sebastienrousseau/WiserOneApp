#if canImport(Cocoa)
import XCTest
@testable import WiserOne

/// Drives the repository's cold path against purpose-built bundles.
///
/// Most of `QuoteRepository` was unreachable from the suite: the shared
/// cache is populated by whichever test runs first, and every load
/// afterwards short-circuits before discovery, decoding or any of the
/// guards. Building a real bundle per test — and clearing that bundle's
/// cache partition — exercises the code that actually reads the disk.
final class QuoteRepositoryColdLoadTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    /// Builds a loadable bundle directory containing `quotes.json`.
    private func makeBundle(
        named name: String,
        json: String,
        inResourcesSubdirectory nested: Bool = false
    ) throws -> Bundle {
        let bundleURL = root.appendingPathComponent("\(name).bundle", isDirectory: true)
        let target = nested
            ? bundleURL.appendingPathComponent("resources", isDirectory: true)
            : bundleURL
        try FileManager.default.createDirectory(
            at: target, withIntermediateDirectories: true
        )
        try json.write(
            to: target.appendingPathComponent("quotes.json"),
            atomically: true, encoding: .utf8
        )
        return try XCTUnwrap(Bundle(url: bundleURL))
    }

    private func corpus(_ count: Int) -> String {
        let entries = (0..<count).map { i in
            """
            {"id":\(i),"quote_text":"Quote \(i)","author":"A",\
            "date_added":"2026-08-23T06:06:06Z",\
            "image_url":"https://e.com/a.jpg"}
            """
        }
        return "{\"quotes\":[\(entries.joined(separator: ","))]}"
    }

    func testColdLoadReadsDecodesAndOrders() throws {
        let bundle = try makeBundle(named: "cold", json: corpus(5))
        let repo = QuoteRepository(bundle: bundle)
        QuoteCache.shared.removeAll(in: repo.cacheScope)

        let (quotes, sources) = try repo.loadDiscoveredQuotes()
        XCTAssertEqual(quotes.count, 5)
        XCTAssertEqual(sources, 1)
        XCTAssertEqual(quotes.compactMap(\.id), Array(0..<5))
    }

    func testResourcesSubdirectoryIsDiscovered() throws {
        let bundle = try makeBundle(
            named: "nested", json: corpus(3), inResourcesSubdirectory: true
        )
        let repo = QuoteRepository(bundle: bundle)
        QuoteCache.shared.removeAll(in: repo.cacheScope)

        let (quotes, _) = try repo.loadDiscoveredQuotes()
        XCTAssertEqual(quotes.count, 3)
    }

    func testSecondLoadIsServedFromTheCache() throws {
        let bundle = try makeBundle(named: "cached", json: corpus(2))
        let repo = QuoteRepository(bundle: bundle)
        QuoteCache.shared.removeAll(in: repo.cacheScope)

        _ = try repo.loadDiscoveredQuotes()
        XCTAssertNotNil(QuoteCache.shared.cachedMergedQuotes(in: repo.cacheScope))

        let (again, _) = try repo.loadDiscoveredQuotes()
        XCTAssertEqual(again.count, 2)
    }

    func testAnEmptyQuoteArrayIsRejected() throws {
        let bundle = try makeBundle(named: "empty", json: "{\"quotes\":[]}")
        let repo = QuoteRepository(bundle: bundle)
        QuoteCache.shared.removeAll(in: repo.cacheScope)

        XCTAssertThrowsError(try repo.loadDiscoveredQuotes()) { error in
            XCTAssertTrue(error is QuoteLoadError)
        }
    }

    func testMalformedJSONIsSkippedRatherThanFatal() throws {
        let bundle = try makeBundle(named: "broken", json: "{ not json at all")
        let repo = QuoteRepository(bundle: bundle)
        QuoteCache.shared.removeAll(in: repo.cacheScope)

        // Discovery is deliberately permissive: a malformed file is
        // skipped, and with nothing left the load reports no resources
        // rather than surfacing a decode error.
        XCTAssertThrowsError(try repo.loadDiscoveredQuotes())
    }

    func testQuotesWithoutIdsStillLoadAndSortLast() throws {
        let json = """
        {"quotes":[
          {"quote_text":"No id","author":"A","date_added":"2024-01-02T00:00:00Z","image_url":"https://e.com/a.jpg"},
          {"id":0,"quote_text":"Has id","author":"A","date_added":"2024-01-01T00:00:00Z","image_url":"https://e.com/a.jpg"}
        ]}
        """
        let bundle = try makeBundle(named: "mixed", json: json)
        let repo = QuoteRepository(bundle: bundle)
        QuoteCache.shared.removeAll(in: repo.cacheScope)

        let (quotes, _) = try repo.loadDiscoveredQuotes()
        XCTAssertEqual(quotes.first?.quoteText, "Has id")
        XCTAssertEqual(quotes.last?.quoteText, "No id")
    }

    func testTwoQuotesSharingAnIdFallBackToDateOrder() throws {
        let json = """
        {"quotes":[
          {"id":0,"quote_text":"Later","author":"A","date_added":"2024-01-02T00:00:00Z","image_url":"https://e.com/a.jpg"},
          {"id":0,"quote_text":"Earlier","author":"A","date_added":"2024-01-01T00:00:00Z","image_url":"https://e.com/a.jpg"}
        ]}
        """
        let bundle = try makeBundle(named: "tied", json: json)
        let repo = QuoteRepository(bundle: bundle)
        QuoteCache.shared.removeAll(in: repo.cacheScope)

        let (quotes, _) = try repo.loadDiscoveredQuotes()
        XCTAssertEqual(quotes.first?.quoteText, "Earlier")
    }

    func testProbeAcceptsAPurposeBuiltBundleAndRejectsAnEmptyOne() throws {
        let withQuotes = try makeBundle(named: "probe", json: corpus(1))
        XCTAssertTrue(ResourceBundleLocator.isLikelyResourceBundle(withQuotes))

        let bare = root.appendingPathComponent("bare.bundle", isDirectory: true)
        try FileManager.default.createDirectory(
            at: bare, withIntermediateDirectories: true
        )
        let empty = try XCTUnwrap(Bundle(url: bare))
        XCTAssertFalse(ResourceBundleLocator.isLikelyResourceBundle(empty))
    }

    func testLegacyNumberedFilenameIsStillRecognised() throws {
        let bundleURL = root.appendingPathComponent("legacy.bundle", isDirectory: true)
        try FileManager.default.createDirectory(
            at: bundleURL, withIntermediateDirectories: true
        )
        try corpus(2).write(
            to: bundleURL.appendingPathComponent("01-quotes.json"),
            atomically: true, encoding: .utf8
        )
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        XCTAssertTrue(
            ResourceBundleLocator.isLikelyResourceBundle(bundle),
            "the probe must still accept the pre-pool filenames"
        )

        let repo = QuoteRepository(bundle: bundle)
        QuoteCache.shared.removeAll(in: repo.cacheScope)
        let (quotes, _) = try repo.loadDiscoveredQuotes()
        XCTAssertEqual(quotes.count, 2)
    }
}

/// The service's failure and edge branches.
///
/// `loadDailyQuote`'s catch, its reset-to-fallback guards, the plural
/// source summary and single-quote cycling were all unreachable while
/// every test loaded the same healthy multi-quote bundle.
final class QuoteServiceEdgeTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func bundle(named name: String, files: [String: String]) throws -> Bundle {
        let url = root.appendingPathComponent("\(name).bundle", isDirectory: true)
        try FileManager.default.createDirectory(
            at: url, withIntermediateDirectories: true
        )
        for (file, contents) in files {
            try contents.write(
                to: url.appendingPathComponent(file),
                atomically: true, encoding: .utf8
            )
        }
        return try XCTUnwrap(Bundle(url: url))
    }

    private func entry(_ id: Int) -> String {
        """
        {"id":\(id),"quote_text":"Quote \(id)","author":"A",\
        "date_added":"2026-08-23T06:06:06Z","image_url":"https://e.com/a.jpg"}
        """
    }

    func testAFailingRepositoryYieldsTheFallbackAndClearsState() throws {
        let bare = root.appendingPathComponent("bare.bundle", isDirectory: true)
        try FileManager.default.createDirectory(
            at: bare, withIntermediateDirectories: true
        )
        let empty = try XCTUnwrap(Bundle(url: bare))
        let repo = QuoteRepository(bundle: empty)
        QuoteCache.shared.removeAll(in: repo.cacheScope)

        let service = QuoteService(repository: repo)
        let quote = service.loadDailyQuote(dayNumber: 739_851)

        XCTAssertEqual(quote.quoteText, Quote.fallback.quoteText)
        XCTAssertFalse(service.hasLoadedQuotes)
        XCTAssertTrue(service.activeQuotes.isEmpty)
        XCTAssertEqual(service.activeQuoteIndex, 0)
        XCTAssertTrue(service.sourceSummary.isEmpty)
        XCTAssertNil(service.currentQuote())
        XCTAssertNil(service.cycleToNextQuote())
    }

    func testTwoSourceFilesArePluralisedInTheSummary() throws {
        let b = try bundle(named: "two", files: [
            "quotes.json": "{\"quotes\":[\(entry(0))]}",
            "extra.json": "{\"quotes\":[\(entry(1))]}",
        ])
        let repo = QuoteRepository(bundle: b)
        QuoteCache.shared.removeAll(in: repo.cacheScope)

        let service = QuoteService(repository: repo)
        _ = service.loadDailyQuote(dayNumber: 739_851)
        XCTAssertEqual(service.sourceSummary, "2 source files")
        XCTAssertEqual(service.activeQuotes.count, 2)
    }

    func testCyclingASingleQuoteCorpusReturnsThatQuote() throws {
        let b = try bundle(named: "one", files: [
            "quotes.json": "{\"quotes\":[\(entry(0))]}",
        ])
        let repo = QuoteRepository(bundle: b)
        QuoteCache.shared.removeAll(in: repo.cacheScope)

        let service = QuoteService(repository: repo)
        _ = service.loadDailyQuote(dayNumber: 739_851)
        XCTAssertEqual(service.sourceSummary, "1 source file")

        let next = service.cycleToNextQuote()
        XCTAssertEqual(next?.quoteText, "Quote 0")
        XCTAssertEqual(service.activeQuoteIndex, 0, "one quote must not advance")
    }

    func testLoggerAppendsThroughTheFileHandlePath() throws {
        // Pre-create the file so the logger takes the append branch on
        // its very first write, rather than the create branch.
        let logURL = root.appendingPathComponent("appLog.txt")
        try "existing line\n".write(to: logURL, atomically: true, encoding: .utf8)

        struct Boom: LocalizedError { let errorDescription: String? }
        ErrorLogger(logURL: logURL).logError(
            Boom(errorDescription: "appended"), errorCode: 7
        )

        let contents = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertTrue(contents.hasPrefix("existing line"))
        XCTAssertTrue(contents.contains("appended"))
        XCTAssertTrue(contents.contains("Code: 7"))
    }

    func testLoggerSurvivesADirectoryWhereTheFileShouldBe() throws {
        // A directory at the log path makes both the create and the
        // append branch fail; logging must still not throw.
        let logURL = root.appendingPathComponent("appLog.txt")
        try FileManager.default.createDirectory(
            at: logURL, withIntermediateDirectories: true
        )
        struct Boom: LocalizedError { let errorDescription: String? }
        ErrorLogger(logURL: logURL).logError(Boom(errorDescription: "unwritable"))
    }
}

/// The last reachable branches: size bound, resource priority, and the
/// locator's fallback probes.
final class QuoteRepositoryBoundsTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func entries(_ count: Int) -> String {
        let items = (0..<count).map {
            """
            {"id":\($0),"quote_text":"Q\($0)","author":"A",\
            "date_added":"2026-08-23T06:06:06Z","image_url":"https://e.com/a.jpg"}
            """
        }
        return "{\"quotes\":[\(items.joined(separator: ","))]}"
    }

    /// A corpus above the per-resource cap must be refused, not loaded.
    func testAnOversizedResourceIsRejected() throws {
        let url = root.appendingPathComponent("huge.bundle", isDirectory: true)
        try FileManager.default.createDirectory(
            at: url, withIntermediateDirectories: true
        )
        try entries(10_001).write(
            to: url.appendingPathComponent("quotes.json"),
            atomically: true, encoding: .utf8
        )
        let bundle = try XCTUnwrap(Bundle(url: url))
        let repo = QuoteRepository(bundle: bundle)
        QuoteCache.shared.removeAll(in: repo.cacheScope)

        XCTAssertThrowsError(try repo.loadDiscoveredQuotes()) { error in
            XCTAssertTrue(error is QuoteLoadError)
        }
    }

    /// The same basename in two locations resolves by priority, with
    /// `resources/` beating the bundle root.
    func testDuplicateBasenameResolvesByPriority() throws {
        let url = root.appendingPathComponent("dupe.bundle", isDirectory: true)
        let nested = url.appendingPathComponent("resources", isDirectory: true)
        try FileManager.default.createDirectory(
            at: nested, withIntermediateDirectories: true
        )
        // Root copy has one quote; the resources/ copy has three and
        // should win.
        try entries(1).write(
            to: url.appendingPathComponent("quotes.json"),
            atomically: true, encoding: .utf8
        )
        try entries(3).write(
            to: nested.appendingPathComponent("quotes.json"),
            atomically: true, encoding: .utf8
        )

        let bundle = try XCTUnwrap(Bundle(url: url))
        let repo = QuoteRepository(bundle: bundle)
        QuoteCache.shared.removeAll(in: repo.cacheScope)

        let (quotes, sources) = try repo.loadDiscoveredQuotes()
        XCTAssertEqual(sources, 1, "one basename must yield one source")
        XCTAssertEqual(
            quotes.count, 3,
            "the resources/ copy should have taken priority"
        )
    }

    /// The probe's second and third checks: a corpus only in
    /// `resources/`, and a legacy `NN-quotes.json` matched by suffix.
    func testProbeFallsBackToSubdirectoryAndSuffix() throws {
        let nestedBundle = root.appendingPathComponent("sub.bundle", isDirectory: true)
        let nested = nestedBundle.appendingPathComponent("resources", isDirectory: true)
        try FileManager.default.createDirectory(
            at: nested, withIntermediateDirectories: true
        )
        try entries(1).write(
            to: nested.appendingPathComponent("quotes.json"),
            atomically: true, encoding: .utf8
        )
        XCTAssertTrue(
            ResourceBundleLocator.isLikelyResourceBundle(
                try XCTUnwrap(Bundle(url: nestedBundle))
            ),
            "a corpus under resources/ must still be recognised"
        )

        let legacyBundle = root.appendingPathComponent("legacy2.bundle", isDirectory: true)
        try FileManager.default.createDirectory(
            at: legacyBundle, withIntermediateDirectories: true
        )
        try entries(1).write(
            to: legacyBundle.appendingPathComponent("07-quotes.json"),
            atomically: true, encoding: .utf8
        )
        XCTAssertTrue(
            ResourceBundleLocator.isLikelyResourceBundle(
                try XCTUnwrap(Bundle(url: legacyBundle))
            ),
            "the suffix fallback must still accept NN-quotes.json"
        )

        let jsonButNotQuotes = root.appendingPathComponent("other.bundle", isDirectory: true)
        try FileManager.default.createDirectory(
            at: jsonButNotQuotes, withIntermediateDirectories: true
        )
        try "{}".write(
            to: jsonButNotQuotes.appendingPathComponent("settings.json"),
            atomically: true, encoding: .utf8
        )
        XCTAssertFalse(
            ResourceBundleLocator.isLikelyResourceBundle(
                try XCTUnwrap(Bundle(url: jsonButNotQuotes))
            ),
            "a bundle whose only JSON is unrelated must be rejected"
        )
    }
}
#endif
