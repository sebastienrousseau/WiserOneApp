import XCTest
@testable import WiserOneCore

final class QuoteResourceResolverTests: XCTestCase {
    func testResolveResourceNameUsesPreferredWhenAvailable() {
        let resourceName = QuoteResourceResolver.resolveResourceName(forMonth: "04") { name in
            name == "04-quotes"
        }

        XCTAssertEqual(resourceName, "04-quotes")
    }

    func testResolveResourceNameFallsBackToJanuaryWhenMissing() {
        let resourceName = QuoteResourceResolver.resolveResourceName(forMonth: "04") { _ in
            false
        }

        XCTAssertEqual(resourceName, "01-quotes")
    }

    func testResolveResourceNameUsesMonthTokenAsProvided() {
        let resourceName = QuoteResourceResolver.resolveResourceName(forMonth: "9") { name in
            name == "9-quotes"
        }

        XCTAssertEqual(resourceName, "9-quotes")
    }

    func testResolveResourceNameFallsBackWhenMonthTokenIsEmpty() {
        let resourceName = QuoteResourceResolver.resolveResourceName(forMonth: "") { _ in
            false
        }

        XCTAssertEqual(resourceName, "01-quotes")
    }

    func testResolveResourceNameFallsBackWhenMonthTokenIsNotNumeric() {
        let resourceName = QuoteResourceResolver.resolveResourceName(forMonth: "AB") { _ in
            false
        }

        XCTAssertEqual(resourceName, "01-quotes")
    }

    func testResolveResourceNameUsesBoundedMonthTokenLength() {
        let resourceName = QuoteResourceResolver.resolveResourceName(forMonth: "1234") { name in
            name == "12-quotes"
        }

        XCTAssertEqual(resourceName, "12-quotes")
    }
}
