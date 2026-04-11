#if canImport(Foundation)
import Foundation

enum QuoteLoadError: Error {
    case emptyResource(String)
    case resourceTooLarge(String)
    case noValidResources
}

/// Resource discovery and decoding for quote JSON payloads.
final class QuoteRepository {
    private static let maxQuotesPerResource = 10_000
    private static let maxResourceNameLength = 255
    private static let decoder = JSONDecoder()

    private let resourceBundle: Bundle
    private let cache: QuoteCache

    init(bundle: Bundle, cache: QuoteCache = .shared) {
        resourceBundle = bundle
        self.cache = cache
    }

    func loadDiscoveredQuotes() throws -> ([Quote], Int) {
        if let cached = cache.cachedMergedQuotes() {
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

        let sortedQuotes = mergedQuotes.sorted { lhs, rhs in
            lhs.dateAdded < rhs.dateAdded
        }
        cache.storeMergedQuotes(sortedQuotes, sourceCount: validSourceCount)
        return (sortedQuotes, validSourceCount)
    }

    private func discoverQuoteResources() -> [(name: String, url: URL)] {
        guard let discoveredURLs = resourceBundle.urls(forResourcesWithExtension: "json", subdirectory: nil) else {
            return []
        }
        let resourceURLs = discoveredURLs.map { $0 as URL }

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

        if let cached = cache.cachedQuotes(for: resourceName) {
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

        cache.storeQuotes(decoded.quotes, for: resourceName)
        return decoded.quotes
    }
}
#endif
