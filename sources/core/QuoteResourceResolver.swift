import Foundation

public enum QuoteResourceResolver {
    private static let fallbackResourceName = "01-quotes"
    private static let maxMonthTokenLength = 2

    public static func resolveResourceName(forMonth month: String, resourceExists: (String) -> Bool) -> String {
        let monthToken = normalizedMonthToken(from: month)
        let preferredName = "\(monthToken)-quotes"

        let hasPreferredResource = resourceExists(preferredName)
        if hasPreferredResource {
            return preferredName
        }

        return fallbackResourceName
    }

    private static func normalizedMonthToken(from month: String) -> String {
        guard !month.isEmpty else {
            return "01"
        }

        let boundedToken = String(month.prefix(maxMonthTokenLength))
        let isNumeric = boundedToken.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
        guard isNumeric else {
            return "01"
        }

        return boundedToken
    }
}
