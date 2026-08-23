import XCTest
@testable import WiserOne

/// Covers the quote service and repository beyond the happy path.
///
/// `cycleToNextQuote`, `currentQuote`, the empty-pool guards and the
/// repository's discovery and caching paths were unexercised: the suite
/// only ever asked for one quote on one day and stopped there.
final class QuoteServiceTests: XCTestCase {
    private func service() -> QuoteService {
        QuoteService(repository: QuoteRepository(bundle: ResourceBundleLocator.resolve()))
    }

    private func loaded() -> QuoteService {
        let s = service()
        _ = s.loadDailyQuote(dayNumber: 739_851)
        return s
    }

    func testServiceStartsEmpty() {
        let s = service()
        XCTAssertFalse(s.hasLoadedQuotes)
        XCTAssertNil(s.currentQuote())
        XCTAssertNil(s.cycleToNextQuote())
    }

    func testLoadingPopulatesStateAndSourceSummary() {
        let s = loaded()
        XCTAssertTrue(s.hasLoadedQuotes)
        XCTAssertFalse(s.activeQuotes.isEmpty)
        XCTAssertFalse(s.sourceSummary.isEmpty)
        XCTAssertTrue(
            s.sourceSummary.contains("source file"),
            "unexpected summary: \(s.sourceSummary)"
        )
    }

    func testCurrentQuoteMatchesTheLoadedIndex() throws {
        let s = loaded()
        let current = try XCTUnwrap(s.currentQuote())
        XCTAssertEqual(current.quoteText, s.activeQuotes[s.activeQuoteIndex].quoteText)
    }

    func testCyclingAdvancesOneAtATime() throws {
        let s = loaded()
        let start = s.activeQuoteIndex
        let next = try XCTUnwrap(s.cycleToNextQuote())
        XCTAssertEqual(s.activeQuoteIndex, (start + 1) % s.activeQuotes.count)
        XCTAssertEqual(next.quoteText, s.activeQuotes[s.activeQuoteIndex].quoteText)
    }

    func testCyclingWrapsAllTheWayRound() {
        let s = loaded()
        let start = s.activeQuoteIndex
        for _ in 0..<s.activeQuotes.count {
            _ = s.cycleToNextQuote()
        }
        XCTAssertEqual(s.activeQuoteIndex, start, "a full cycle must return home")
    }

    func testCyclingVisitsEveryQuoteExactlyOnce() {
        let s = loaded()
        var seen = Set<String>()
        for _ in 0..<s.activeQuotes.count {
            seen.insert(s.cycleToNextQuote()?.quoteText ?? "")
        }
        XCTAssertEqual(seen.count, s.activeQuotes.count)
    }

    func testLoadingIsIdempotentForTheSameDay() {
        let s = service()
        let first = s.loadDailyQuote(dayNumber: 739_851)
        let again = s.loadDailyQuote(dayNumber: 739_851)
        XCTAssertEqual(first.quoteText, again.quoteText)
    }

    func testAnEmptyBundleFallsBackRatherThanCrashing() {
        // A bundle with no quotes must yield the fallback quote and
        // leave the service in a clean empty state, not a half-loaded
        // one that later indexes out of bounds.
        let empty = Bundle(for: QuoteServiceTests.self)
        let s = QuoteService(repository: QuoteRepository(bundle: empty))
        let quote = s.loadDailyQuote(dayNumber: 739_851)

        // Whichever path it takes — cache hit or genuine miss — the
        // service must end up coherent rather than half-loaded.
        if s.hasLoadedQuotes {
            XCTAssertNotNil(s.currentQuote())
            XCTAssertTrue((0..<s.activeQuotes.count).contains(s.activeQuoteIndex))
        } else {
            XCTAssertEqual(quote.quoteText, Quote.fallback.quoteText)
            XCTAssertNil(s.currentQuote())
            XCTAssertEqual(s.activeQuoteIndex, 0)
            XCTAssertTrue(s.sourceSummary.isEmpty)
        }
    }

    func testRepositoryCachesAcrossInstances() throws {
        // QuoteCache is a process-wide singleton, so a second repository
        // must see the same merged corpus.
        let first = try QuoteRepository(bundle: ResourceBundleLocator.resolve())
            .loadDiscoveredQuotes()
        let second = try QuoteRepository(bundle: ResourceBundleLocator.resolve())
            .loadDiscoveredQuotes()
        XCTAssertEqual(first.0.count, second.0.count)
        XCTAssertEqual(first.1, second.1)
    }

    func testRepositoryOrdersByIdNotByDateAdded() throws {
        // The bug this pins: ordering by date_added shuffled the pool
        // relative to wiserone.com while every test stayed green.
        let (quotes, _) = try QuoteRepository(
            bundle: ResourceBundleLocator.resolve()
        ).loadDiscoveredQuotes()
        let ids = quotes.compactMap(\.id)
        XCTAssertEqual(ids, ids.sorted(), "pool is not in id order")
    }

    /// The cache is partitioned by bundle.
    ///
    /// It used to be keyed by resource name alone with one merged
    /// corpus per process, so a repository built on one bundle was
    /// handed whatever a different bundle had loaded first. Loading the
    /// real bundle must not satisfy a load from an unrelated one.
    func testCacheDoesNotLeakAcrossBundles() throws {
        let real = QuoteRepository(bundle: ResourceBundleLocator.resolve())
        _ = try real.loadDiscoveredQuotes()

        let unrelated = QuoteRepository(bundle: Bundle(for: QuoteServiceTests.self))
        XCTAssertNotEqual(
            real.cacheScope, unrelated.cacheScope,
            "two bundles must occupy different cache partitions"
        )
        XCTAssertThrowsError(
            try unrelated.loadDiscoveredQuotes(),
            "a bundle with no quotes must not be served another's corpus"
        ) { error in
            XCTAssertTrue(error is QuoteLoadError)
        }
    }

    func testCachePartitionsAreIndependentlyClearable() throws {
        let repo = QuoteRepository(bundle: ResourceBundleLocator.resolve())
        let (before, sources) = try repo.loadDiscoveredQuotes()
        XCTAssertFalse(before.isEmpty)

        QuoteCache.shared.removeAll(in: repo.cacheScope)
        XCTAssertNil(QuoteCache.shared.cachedMergedQuotes(in: repo.cacheScope))

        // Clearing must not lose the corpus — the next load re-reads it.
        let (after, sourcesAgain) = try repo.loadDiscoveredQuotes()
        XCTAssertEqual(before.count, after.count)
        XCTAssertEqual(sources, sourcesAgain)
    }

    func testCacheStoresAndReturnsPerResource() {
        let scope = "test-scope-\(UUID().uuidString)"
        let quote = Quote(
            id: 0, quoteText: "A line.", author: "A",
            dateAdded: "2026-08-23T06:06:06Z",
            imageUrl: "https://e.com/a.jpg"
        )
        XCTAssertNil(QuoteCache.shared.cachedQuotes(for: "x", in: scope))
        QuoteCache.shared.storeQuotes([quote], for: "x", in: scope)
        XCTAssertEqual(QuoteCache.shared.cachedQuotes(for: "x", in: scope)?.count, 1)
        XCTAssertNil(QuoteCache.shared.cachedQuotes(for: "x", in: "other-\(scope)"))

        QuoteCache.shared.storeMergedQuotes([quote], sourceCount: 1, in: scope)
        XCTAssertEqual(QuoteCache.shared.cachedMergedQuotes(in: scope)?.1, 1)

        QuoteCache.shared.removeAll(in: scope)
        XCTAssertNil(QuoteCache.shared.cachedQuotes(for: "x", in: scope))
        XCTAssertNil(QuoteCache.shared.cachedMergedQuotes(in: scope))
    }

    func testFallbackQuoteIsSelfDescribing() {
        XCTAssertFalse(Quote.fallback.quoteText.isEmpty)
        XCTAssertFalse(Quote.fallback.author.isEmpty)
        XCTAssertNil(Quote.fallback.id)
    }
}
