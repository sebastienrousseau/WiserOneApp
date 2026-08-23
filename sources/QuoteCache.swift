#if canImport(Foundation)
import Foundation

/// Thread-safe in-memory quote cache shared by repository instances.
/// Process-wide cache of decoded quotes, partitioned by bundle.
///
/// Entries used to be keyed by resource name alone, with a single
/// merged corpus for the whole process. Because `loadDiscoveredQuotes`
/// consults the cache before it looks at its own bundle, a repository
/// built on one bundle would be handed whatever a *different* bundle
/// had loaded first. Harmless while the app ships exactly one bundle,
/// and wrong the moment a second source exists — the kind of defect
/// that surfaces as "the wrong quotes" long after the change that
/// caused it. Every entry is now scoped to the bundle it came from.
final class QuoteCache {
    static let shared = QuoteCache()

    private let lock = NSLock()
    private var quotesByResource = [String: [String: [Quote]]]()
    private var mergedQuotes = [String: [Quote]]()
    private var mergedSourceCounts = [String: Int]()

    private init() {}

    func cachedQuotes(for resourceName: String, in scope: String) -> [Quote]? {
        lock.lock()
        defer { lock.unlock() }
        return quotesByResource[scope]?[resourceName]
    }

    func storeQuotes(_ quotes: [Quote], for resourceName: String, in scope: String) {
        lock.lock()
        defer { lock.unlock() }
        quotesByResource[scope, default: [:]][resourceName] = quotes
    }

    func cachedMergedQuotes(in scope: String) -> ([Quote], Int)? {
        lock.lock()
        defer { lock.unlock() }
        guard let quotes = mergedQuotes[scope] else {
            return nil
        }
        return (quotes, mergedSourceCounts[scope] ?? 0)
    }

    func storeMergedQuotes(_ quotes: [Quote], sourceCount: Int, in scope: String) {
        lock.lock()
        defer { lock.unlock() }
        mergedQuotes[scope] = quotes
        mergedSourceCounts[scope] = sourceCount
    }

    /// Drops everything cached for one bundle.
    ///
    /// Exists so a test can start from a known state; the app never
    /// needs it, because a bundle's contents cannot change at runtime.
    func removeAll(in scope: String) {
        lock.lock()
        defer { lock.unlock() }
        quotesByResource[scope] = nil
        mergedQuotes[scope] = nil
        mergedSourceCounts[scope] = nil
    }
}
#endif
