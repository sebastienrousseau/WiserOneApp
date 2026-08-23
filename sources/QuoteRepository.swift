#if canImport(Foundation)
import Foundation

enum QuoteLoadError: Error {
    case emptyResource(String)
    case resourceTooLarge(String)
    case noValidResources
    /// Some quotes carry no `id`, so pool order — and therefore which
    /// quote a given day maps to — no longer matches wiserone.com.
    case unorderedCorpus(Int)
}

/// Resource discovery and decoding for quote JSON payloads.
final class QuoteRepository {
    private static let maxQuotesPerResource = 10_000
    private static let maxResourceNameLength = 255
    private static let maxRecursiveResourceScan = 2_048
    private static let decoder = JSONDecoder()

    private let resourceBundle: Bundle
    private let cache: QuoteCache

    /// Cache partition for this repository's bundle.
    ///
    /// The identifier is absent for a plain resource bundle, so the
    /// path is the fallback — it is stable for the lifetime of the
    /// process and unique per bundle, which is all the key needs to be.
    var cacheScope: String {
        resourceBundle.bundleIdentifier ?? resourceBundle.bundleURL.path
    }

    init(bundle: Bundle, cache: QuoteCache = .shared) {
        resourceBundle = bundle
        self.cache = cache
    }

    func loadDiscoveredQuotes() throws -> ([Quote], Int) {
        if let cached = cache.cachedMergedQuotes(in: cacheScope) {
            return cached
        }

        let resources = discoverQuoteResources()
        guard !resources.isEmpty else {
            throw QuoteLoadError.noValidResources
        }

        var mergedQuotes = [Quote]()
        var validSourceCount = 0

        for resource in resources {
            do {
                let quotes = try loadQuotes(named: resource.name, from: resource.url)
                if !quotes.isEmpty {
                    mergedQuotes.append(contentsOf: quotes)
                    validSourceCount += 1
                }
            } catch {
                // Ignore malformed or non-quote JSON files to keep discovery permissive.
                continue
            }
        }

        guard !mergedQuotes.isEmpty, validSourceCount > 0 else {
            throw QuoteLoadError.noValidResources
        }

        // Order by pool position, not by date_added. Sorting on the date
        // was right when the corpus was twelve month-files merged in
        // arbitrary order. It is wrong now: date_added records the day a
        // line was written, so sorting on it scrambles the pool relative
        // to wiserone.com and the two show different quotes on the same
        // day. Entries without an id sort last, keeping any legacy file
        // usable rather than throwing.
        // Entries without an id sort last and keep the corpus usable,
        // but they also mean this app and wiserone.com no longer agree on
        // which quote a day maps to — the exact failure that shipped
        // when ordering was by date_added. Say so rather than silently
        // diverging.
        let missingIds = mergedQuotes.filter { $0.id == nil }.count
        if missingIds > 0 {
            ErrorLogger.shared.logError(
                QuoteLoadError.unorderedCorpus(missingIds)
            )
        }

        let sortedQuotes = mergedQuotes.sorted { lhs, rhs in
            let left = lhs.id ?? Int.max
            let right = rhs.id ?? Int.max
            return left == right ? lhs.dateAdded < rhs.dateAdded : left < right
        }
        cache.storeMergedQuotes(
            sortedQuotes, sourceCount: validSourceCount, in: cacheScope
        )
        return (sortedQuotes, validSourceCount)
    }

    private func discoverQuoteResources() -> [(name: String, url: URL)] {
        let rootURLs = (resourceBundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .map { $0 as URL }
        let resourcesSubdirectoryURLs = (resourceBundle.urls(forResourcesWithExtension: "json", subdirectory: "resources") ?? [])
            .map { $0 as URL }
        let recursiveURLs = discoverQuoteResourcesRecursively()
        var seenPaths = Set<String>()
        let resourceURLs = (rootURLs + resourcesSubdirectoryURLs + recursiveURLs)
            .filter { seenPaths.insert($0.path).inserted }

        var selectedResources = [String: URL]()

        for url in resourceURLs {
            let resourceName = url.deletingPathExtension().lastPathComponent
            guard !resourceName.isEmpty, resourceName.count <= Self.maxResourceNameLength else {
                continue
            }

            if let existingURL = selectedResources[resourceName] {
                if resourcePriority(for: url) > resourcePriority(for: existingURL) {
                    selectedResources[resourceName] = url
                }
            } else {
                selectedResources[resourceName] = url
            }
        }

        return selectedResources.keys.sorted().compactMap { name in
            guard let url = selectedResources[name] else { return nil }
            return (name: name, url: url)
        }
    }

    private func discoverQuoteResourcesRecursively() -> [URL] {
        guard let rootURL = resourceBundle.resourceURL ?? resourceBundle.bundleURL as URL? else {
            return []
        }

        var urls = [URL]()
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            if urls.count >= Self.maxRecursiveResourceScan {
                break
            }

            if fileURL.pathExtension.lowercased() != "json" {
                continue
            }

            urls.append(fileURL)
        }

        return urls
    }

    private func resourcePriority(for url: URL) -> Int {
        let path = url.path.lowercased()
        if path.contains("/resources/") {
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

        if let cached = cache.cachedQuotes(for: resourceName, in: cacheScope) {
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

        cache.storeQuotes(decoded.quotes, for: resourceName, in: cacheScope)
        return decoded.quotes
    }
}
#endif
