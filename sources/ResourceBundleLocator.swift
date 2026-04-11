#if canImport(Foundation)
import Foundation

/// Runtime-safe bundle locator for SwiftPM resources in both `swift run` and packaged app layouts.
enum ResourceBundleLocator {
    private static let moduleBundleName = "WiserOne_WiserOne"
    private static let moduleBundleExtensions = ["bundle", "resources"]

    static func resolve() -> Bundle {
        let mainBundle = Bundle.main
        for url in candidateBundleURLs(mainBundle: mainBundle) {
            if let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return mainBundle
    }

    private static func candidateBundleURLs(mainBundle: Bundle) -> [URL] {
        var searchRoots: [URL] = [
            mainBundle.bundleURL,
            mainBundle.resourceURL,
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
}
#endif
