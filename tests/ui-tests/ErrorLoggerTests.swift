import XCTest
@testable import WiserOne

/// Covers the error log, which had no tests at all.
///
/// It sat at 0/74 lines — the entire logging path, including the
/// create-versus-append branch and the size bound. Nothing verified
/// that a logged error reached disk, which is a poor thing to discover
/// while trying to diagnose a crash from a user's log.
final class ErrorLoggerTests: XCTestCase {
    private var directory: URL!
    private var logURL: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        logURL = directory.appendingPathComponent("appLog.txt")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private struct SampleError: LocalizedError {
        let errorDescription: String?
    }

    func testLoggingCreatesTheFileOnFirstWrite() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: logURL.path))

        ErrorLogger(logURL: logURL).logError(
            SampleError(errorDescription: "first failure")
        )

        let contents = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("first failure"))
    }

    func testSecondWriteAppendsRatherThanReplacing() throws {
        let logger = ErrorLogger(logURL: logURL)
        logger.logError(SampleError(errorDescription: "first failure"))
        logger.logError(SampleError(errorDescription: "second failure"))

        let contents = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("first failure"))
        XCTAssertTrue(contents.contains("second failure"))
        XCTAssertEqual(
            contents.split(separator: "\n").count, 2,
            "each error must be its own line"
        )
    }

    func testEntryCarriesTimestampCodeFileAndMethod() throws {
        ErrorLogger(logURL: logURL).logError(
            SampleError(errorDescription: "boom"),
            errorCode: 42
        )

        let contents = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("Code: 42"))
        XCTAssertTrue(contents.contains("File: "))
        XCTAssertTrue(contents.contains("Method: "))
        XCTAssertTrue(contents.contains("Error: boom"))
        // Timestamp is a fixed-width UTC stamp at the head of the line.
        let head = String(contents.prefix(19))
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        parser.dateFormat = "yyyy-MM-dd HH:mm:ss"
        XCTAssertNotNil(parser.date(from: head), "bad timestamp: \(head)")
    }

    func testEntryWithoutACodeOmitsTheCodeField() throws {
        ErrorLogger(logURL: logURL).logError(
            SampleError(errorDescription: "no code")
        )
        let contents = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertFalse(contents.contains("Code:"))
    }

    func testOversizedEntriesAreBounded() throws {
        // The formatter caps an entry at 8192 characters; without the
        // bound a runaway description would write unbounded to disk.
        let huge = String(repeating: "x", count: 20_000)
        ErrorLogger(logURL: logURL).logError(
            SampleError(errorDescription: huge)
        )

        let contents = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertLessThanOrEqual(contents.count, 8_192)
        XCTAssertTrue(contents.contains("xxxx"))
    }

    func testAnUnwritableDestinationDoesNotThrow() {
        // The logger swallows write failures deliberately: logging must
        // never be the thing that takes the app down.
        let unwritable = URL(fileURLWithPath: "/System/nope/appLog.txt")
        ErrorLogger(logURL: unwritable).logError(
            SampleError(errorDescription: "unwritable")
        )
    }

    func testSharedLoggerIsASingleton() {
        XCTAssertTrue(ErrorLogger.shared === ErrorLogger.shared)
    }
}
