import XCTest
@testable import WiserOne

/// Guards the daily rotation and the bundle lookup it depends on.
///
/// Both broke silently when the corpus became a single `quotes.json`
/// pool: `ResourceBundleLocator` identified the resource bundle by
/// probing for `01-quotes.json`, and its fallback matched the substring
/// `"-quotes.json"`, which the new name does not contain. The whole
/// existing suite stayed green while the app fell through to the wrong
/// bundle and would have rendered `Quote.fallback`.
final class QuoteRotationTests: XCTestCase {
    /// 2026-08-23 as `date.toordinal()`, the ordinal the website uses.
    private let knownDayNumber = 739_851
    private let expectedForKnownDay =
        "If nobody's upset about what you cut, you didn't cut enough."

    private func makeService() -> QuoteService {
        QuoteService(repository: QuoteRepository(bundle: ResourceBundleLocator.resolve()))
    }

    func testResourceBundleResolvesToTheQuotePool() {
        let bundle = ResourceBundleLocator.resolve()
        let direct = bundle.url(forResource: "quotes", withExtension: "json")
        let nested = bundle.url(forResource: "quotes", withExtension: "json",
                                subdirectory: "resources")
        XCTAssertTrue(direct != nil || nested != nil,
                      "the resolved bundle does not contain quotes.json")
    }

    func testDailyQuoteIsNotTheFallback() {
        let quote = makeService().loadDailyQuote(dayNumber: knownDayNumber)
        XCTAssertNotEqual(quote.quoteText, Quote.fallback.quoteText,
                          "quote lookup fell back, so the corpus did not load")
    }

    func testRotationMatchesTheWebsiteForAKnownDay() {
        let quote = makeService().loadDailyQuote(dayNumber: knownDayNumber)
        XCTAssertEqual(quote.quoteText, expectedForKnownDay)
    }

    /// The bug this replaced: day-of-year reset every January, so the
    /// sequence jumped rather than advancing by one.
    func testRotationIsContinuousAcrossTheYearBoundary() {
        let service = makeService()
        let newYearsEve = service.loadDailyQuote(dayNumber: 739_981)
        let newYearsDay = service.loadDailyQuote(dayNumber: 739_982)
        XCTAssertNotEqual(newYearsEve.quoteText, newYearsDay.quoteText)

        let poolSize = service.activeQuotes.count
        XCTAssertGreaterThan(poolSize, 1)
        let indexOnEve = 739_981 % poolSize
        let indexOnDay = 739_982 % poolSize
        XCTAssertEqual((indexOnEve + 1) % poolSize, indexOnDay,
                       "consecutive days must advance the rotation by one")
    }

    func testRotationWrapsAfterAFullPass() {
        let service = makeService()
        _ = service.loadDailyQuote(dayNumber: knownDayNumber)
        let poolSize = service.activeQuotes.count
        let first = service.loadDailyQuote(dayNumber: knownDayNumber)
        let afterOnePass = service.loadDailyQuote(dayNumber: knownDayNumber + poolSize)
        XCTAssertEqual(first.quoteText, afterOnePass.quoteText)
    }

    func testNegativeDayNumberDoesNotTrap() {
        let quote = makeService().loadDailyQuote(dayNumber: -1)
        XCTAssertFalse(quote.quoteText.isEmpty)
    }
}

/// Guards the bundle probe and the shipped corpus.
final class QuoteCorpusTests: XCTestCase {
    private func pool() -> [Quote] {
        let service = QuoteService(
            repository: QuoteRepository(bundle: ResourceBundleLocator.resolve())
        )
        _ = service.loadDailyQuote(dayNumber: 739_851)
        return service.activeQuotes
    }

    func testProbeRecognisesTheRealResourceBundle() {
        // Direct, not via resolve(): resolve() masks a broken probe by
        // falling through to a candidate that is right by accident.
        XCTAssertTrue(
            ResourceBundleLocator.isLikelyResourceBundle(ResourceBundleLocator.resolve()),
            "the probe no longer recognises the bundle holding quotes.json"
        )
    }

    func testProbeRejectsABundleWithNoQuotes() {
        XCTAssertFalse(
            ResourceBundleLocator.isLikelyResourceBundle(Bundle(for: QuoteCorpusTests.self)),
            "the probe accepts a bundle with no corpus, so it proves nothing"
        )
    }

    func testEveryShippedQuoteCarriesAnId() {
        let quotes = pool()
        XCTAssertFalse(quotes.isEmpty)
        XCTAssertTrue(
            quotes.allSatisfy { $0.id != nil },
            "a quote without an id makes pool order, and the daily selection, diverge from wiserone.com"
        )
    }

    func testIdsAreContiguousFromZero() {
        let ids = pool().compactMap(\.id).sorted()
        XCTAssertEqual(ids, Array(0..<ids.count),
                       "ids must be contiguous; a gap shifts every day's quote")
    }

    func testCorpusIsDeepEnoughToHideTheRotation() {
        XCTAssertGreaterThanOrEqual(
            pool().count, 100,
            "below ~100 quotes a returning reader notices the repeat"
        )
    }

    func testNoDuplicateQuotesInThePool() {
        let texts = pool().map(\.quoteText)
        XCTAssertEqual(Set(texts).count, texts.count, "duplicate quote in the pool")
    }
}
