#if canImport(Foundation)
import Foundation

/// Runtime-safe bundle locator for SwiftPM resources in both `swift run` and packaged app layouts.
enum ResourceBundleLocator {
    private static let moduleBundleName = "WiserOne_WiserOne"
    private static let moduleBundleExtensions = ["bundle", "resources"]
    /// Basename probed to recognise the resource bundle. The corpus is a
    /// single `quotes.json` pool; it used to be twelve `NN-quotes.json`
    /// files, and this probed for `01-quotes`.
    private static let quoteProbePrefix = "quotes"

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

    /// Internal rather than private so a test can exercise it directly.
    ///
    /// Testing through `resolve()` does not guard this: when the probe
    /// is wrong, `resolve()` falls through to `firstCandidateBundle`,
    /// which in the SwiftPM test layout happens to be the right bundle
    /// anyway. The probe can be completely broken and every test still
    /// passes — which is what happened when the corpus was renamed.
    static func isLikelyResourceBundle(_ bundle: Bundle) -> Bool {
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
        // hasSuffix, not contains("-quotes.json"): the pool file is named
        // `quotes.json` with no prefix, so the old substring test matched
        // nothing and the locator fell through to the wrong bundle. This
        // still accepts the legacy `NN-quotes.json` names.
        if (jsonURLs + resourcesJSONURLs).contains(where: { $0.lastPathComponent.hasSuffix("quotes.json") })
        {
            return true
        }
        return false
    }
}
#endif
