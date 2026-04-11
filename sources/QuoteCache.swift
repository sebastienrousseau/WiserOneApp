#if canImport(Foundation)
import Foundation

/// Thread-safe in-memory quote cache shared by repository instances.
final class QuoteCache {
    static let shared = QuoteCache()

    private let lock = NSLock()
    private var quotesByResource = [String: [Quote]]()
    private var mergedQuotes: [Quote]?
    private var mergedSourceCount = 0

    private init() {}

    func cachedQuotes(for resourceName: String) -> [Quote]? {
        lock.lock()
        defer { lock.unlock() }
        return quotesByResource[resourceName]
    }

    func storeQuotes(_ quotes: [Quote], for resourceName: String) {
        lock.lock()
        defer { lock.unlock() }
        quotesByResource[resourceName] = quotes
    }

    func cachedMergedQuotes() -> ([Quote], Int)? {
        lock.lock()
        defer { lock.unlock() }
        guard let mergedQuotes else {
            return nil
        }
        return (mergedQuotes, mergedSourceCount)
    }

    func storeMergedQuotes(_ quotes: [Quote], sourceCount: Int) {
        lock.lock()
        defer { lock.unlock() }
        mergedQuotes = quotes
        mergedSourceCount = sourceCount
    }
}
#endif
