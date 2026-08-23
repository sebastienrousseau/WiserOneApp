#if canImport(Foundation)
import Foundation

/// The daily rotation, shared and pure.
///
/// This target previously held `QuoteResourceResolver`, which resolved
/// `MM-quotes` filenames for a twelve-file corpus that no longer exists
/// and was called from nowhere — dead code that read like the selection
/// mechanism, kept at 100% coverage by its own tests. The rotation is
/// what actually decides which quote a day shows, so it lives here
/// instead: pure arithmetic, no bundle, no I/O, fast to test.
public enum QuoteRotation {
    /// Ordinal of 1970-01-01 in the proleptic Gregorian calendar.
    ///
    /// wiserone.com selects on `date.toordinal()`, Python's count of
    /// days since 0001-01-01. Matching the epoch is what makes the app
    /// and the site show the same quote on the same day.
    public static let unixEpochOrdinal = 719_163

    private static let secondsPerDay = 86_400.0

    /// Days elapsed since 0001-01-01 for the given instant, in UTC.
    ///
    /// UTC deliberately: the quote turns over at midnight UTC
    /// everywhere, rather than drifting with the machine's timezone and
    /// disagreeing with the website for most of the day.
    public static func dayNumber(for date: Date = Date()) -> Int {
        unixEpochOrdinal + Int(floor(date.timeIntervalSince1970 / secondsPerDay))
    }

    /// Position in the pool for a day, wrapping in both directions.
    ///
    /// Floored modulo, so a pre-epoch ordinal yields a valid index
    /// instead of a negative one that would trap on subscript.
    ///
    /// - Returns: `nil` when the pool is empty, which the caller must
    ///   treat as "no quote" rather than substituting zero.
    public static func index(forDayNumber dayNumber: Int, poolSize: Int) -> Int? {
        guard poolSize > 0 else { return nil }
        return ((dayNumber % poolSize) + poolSize) % poolSize
    }
}
#endif
