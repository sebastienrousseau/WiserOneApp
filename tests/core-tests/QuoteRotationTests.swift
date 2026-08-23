import XCTest
@testable import WiserOneCore

/// Pure tests for the daily rotation.
///
/// These replace the tests for `QuoteResourceResolver`, which exercised
/// filename resolution for a corpus layout that no longer exists. The
/// coverage gate now protects the arithmetic that actually decides
/// which quote a reader sees.
final class QuoteRotationTests: XCTestCase {
    /// 2026-08-23 as `date.toordinal()`.
    private let knownDay = 739_851

    func testEpochOrdinalMatchesPythonToordinal() {
        // date(1970, 1, 1).toordinal() == 719163
        XCTAssertEqual(QuoteRotation.unixEpochOrdinal, 719_163)
        XCTAssertEqual(
            QuoteRotation.dayNumber(for: Date(timeIntervalSince1970: 0)),
            719_163
        )
    }

    func testDayNumberMatchesAKnownDate() {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 23
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: components)!
        XCTAssertEqual(QuoteRotation.dayNumber(for: date), knownDay)
    }

    func testDayNumberIsStableAcrossTheWholeUTCDay() {
        // One second past midnight and one second before the next must
        // land on the same day, or the quote flickers.
        let midnight = Date(timeIntervalSince1970: 1_800_000_000)
        let dayStart = midnight.timeIntervalSince1970 - midnight.timeIntervalSince1970.truncatingRemainder(dividingBy: 86_400)
        let start = Date(timeIntervalSince1970: dayStart)
        let end = Date(timeIntervalSince1970: dayStart + 86_399)
        XCTAssertEqual(
            QuoteRotation.dayNumber(for: start),
            QuoteRotation.dayNumber(for: end)
        )
        XCTAssertEqual(
            QuoteRotation.dayNumber(for: Date(timeIntervalSince1970: dayStart + 86_400)),
            QuoteRotation.dayNumber(for: start) + 1
        )
    }

    func testDayNumberIsMonotonic() {
        let first = QuoteRotation.dayNumber(for: Date(timeIntervalSince1970: 0))
        let later = QuoteRotation.dayNumber(for: Date(timeIntervalSince1970: 86_400 * 10))
        XCTAssertEqual(later - first, 10)
    }

    func testDayNumberHandlesPreEpochDates() {
        // floor, not truncation: -1 second is the previous day.
        XCTAssertEqual(
            QuoteRotation.dayNumber(for: Date(timeIntervalSince1970: -1)),
            719_162
        )
    }

    func testIndexWrapsAcrossAFullPass() {
        let size = 136
        let base = QuoteRotation.index(forDayNumber: knownDay, poolSize: size)
        XCTAssertEqual(base, knownDay % size)
        XCTAssertEqual(
            QuoteRotation.index(forDayNumber: knownDay + size, poolSize: size),
            base
        )
    }

    func testIndexAdvancesByOnePerDay() {
        let size = 136
        let today = QuoteRotation.index(forDayNumber: knownDay, poolSize: size)!
        let tomorrow = QuoteRotation.index(forDayNumber: knownDay + 1, poolSize: size)!
        XCTAssertEqual((today + 1) % size, tomorrow)
    }

    /// The bug this rotation replaced: day-of-year reset each January,
    /// so the sequence jumped instead of advancing.
    func testIndexDoesNotResetAtTheYearBoundary() {
        let size = 136
        let newYearsEve = QuoteRotation.index(forDayNumber: 739_981, poolSize: size)!
        let newYearsDay = QuoteRotation.index(forDayNumber: 739_982, poolSize: size)!
        XCTAssertEqual((newYearsEve + 1) % size, newYearsDay)
        XCTAssertNotEqual(newYearsDay, 0, "a reset would land on index 0")
    }

    func testIndexIsNeverNegative() {
        for day in [-1, -136, -1_000_000, Int.min + 1] {
            guard let index = QuoteRotation.index(forDayNumber: day, poolSize: 136) else {
                return XCTFail("expected an index for day \(day)")
            }
            XCTAssertTrue((0..<136).contains(index), "out of range for \(day)")
        }
    }

    func testIndexIsNilForAnEmptyPool() {
        XCTAssertNil(QuoteRotation.index(forDayNumber: knownDay, poolSize: 0))
        XCTAssertNil(QuoteRotation.index(forDayNumber: knownDay, poolSize: -1))
    }

    func testEveryDayInAFullCycleIsReachable() {
        let size = 136
        var seen = Set<Int>()
        for offset in 0..<size {
            seen.insert(QuoteRotation.index(forDayNumber: knownDay + offset, poolSize: size)!)
        }
        XCTAssertEqual(seen.count, size, "a full pass must visit every quote exactly once")
    }
}
