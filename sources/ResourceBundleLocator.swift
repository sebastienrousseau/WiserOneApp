#if canImport(Foundation)
import Foundation

/// Runtime-safe bundle locator for SwiftPM resources in both `swift run` and packaged app layouts.
enum ResourceBundleLocator {
    private static let moduleBundleName = "WiserOne_WiserOne"
    private static let moduleBundleExtensions = ["bundle", "resources"]
    private static let quoteProbePrefix = "01-quotes"

    static func resolve() -> Bundle {
        let mainBundle = Bundle.main
        var firstCandidateBundle: Bundle?
        for url in candidateBundleURLs(mainBundle: mainBundle) {
            if let bundle = Bundle(url: url) {
                if firstCandidateBundle == nil {
                    firstCandidateBundle = bundle
                }
                if isLikelyResourceBundle(bundle) {
                    return bundle
                }
            }
        }
        return firstCandidateBundle ?? mainBundle
    }

    private static func candidateBundleURLs(mainBundle: Bundle) -> [URL] {
        var searchRoots: [URL] = [
            mainBundle.bundleURL,
            mainBundle.resourceURL,
            mainBundle.bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true),
            mainBundle.bundleURL.deletingLastPathComponent(),
            mainBundle.executableURL?.deletingLastPathComponent(),
        ].compactMap { $0 }

        for bundle in (Bundle.allBundles + Bundle.allFrameworks) {
            searchRoots.append(bundle.bundleURL)
            if let resourceURL = bundle.resourceURL {
                searchRoots.append(resourceURL)
            }
            searchRoots.append(bundle.bundleURL.deletingLastPathComponent())
        }

        var seen = Set<String>()
        var urls = [URL]()

        for root in searchRoots {
            for ext in moduleBundleExtensions {
                let url = root.appendingPathComponent("\(moduleBundleName).\(ext)", isDirectory: true)
                if seen.insert(url.path).inserted {
                    urls.append(url)
                }
            }
        }

        return urls
    }

    private static func isLikelyResourceBundle(_ bundle: Bundle) -> Bool {
        if bundle.url(forResource: quoteProbePrefix, withExtension: "json") != nil {
            return true
        }
        if bundle.url(forResource: quoteProbePrefix, withExtension: "json", subdirectory: "resources") != nil {
            return true
        }

        let jsonURLs = (bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .map { $0 as URL }
        let resourcesJSONURLs = (bundle.urls(forResourcesWithExtension: "json", subdirectory: "resources") ?? [])
            .map { $0 as URL }
        if (jsonURLs + resourcesJSONURLs).contains(where: { $0.lastPathComponent.contains("-quotes.json") })
        {
            return true
        }
        return false
    }
}
#endif
