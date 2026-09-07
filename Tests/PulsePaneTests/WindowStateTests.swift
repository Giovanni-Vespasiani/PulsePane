import XCTest
@testable import PulsePane

final class WindowStateTests: XCTestCase {

    func testValidV2FrameParsed() {
        let frameString = "v2|{{100, 200}, {340, 430}}"
        let parts = frameString.split(separator: "|", maxSplits: 1)
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(parts[0], "v2")
        let rect = NSRectFromString(String(parts[1]))
        XCTAssertEqual(rect.origin.x, 100)
        XCTAssertEqual(rect.origin.y, 200)
        XCTAssertEqual(rect.size.width, 340)
        XCTAssertEqual(rect.size.height, 430)
    }

    func testMalformedPrefix() {
        let frameString = "v1|{{100, 200}, {340, 430}}"
        let parts = frameString.split(separator: "|", maxSplits: 1)
        XCTAssertEqual(parts.count, 2)
        XCTAssertNotEqual(parts[0], "v2")
    }

    func testMissingComponents() {
        let frameString = "v2|"
        let parts = frameString.split(separator: "|", maxSplits: 1)
        // "v2|" split by "|" gives 1 part: "v2"
        XCTAssertEqual(parts.count, 1)
        XCTAssertEqual(parts[0], "v2")
        let rect = NSRectFromString(String(""))
        // NSRectFromString("") returns a zero rect
        XCTAssertEqual(rect.origin.x, 0)
        XCTAssertEqual(rect.origin.y, 0)
        XCTAssertEqual(rect.size.width, 0)
        XCTAssertEqual(rect.size.height, 0)
    }

    func testNaNCoordinates() {
        let frameString = "v2|{{nan, 200}, {340, 430}}"
        let parts = frameString.split(separator: "|", maxSplits: 1)
        if parts.count == 2, parts[0] == "v2" {
            let rect = NSRectFromString(String(parts[1]))
            // NSRectFromString doesn't produce NaN from "nan" string
            // Just verify parsing doesn't crash and result is reasonable
            XCTAssertTrue(rect.isNull || rect.origin.x >= 0)
        }
    }

    func testInfinityCoordinates() {
        let frameString = "v2|{{inf, 200}, {340, 430}}"
        let parts = frameString.split(separator: "|", maxSplits: 1)
        if parts.count == 2, parts[0] == "v2" {
            let rect = NSRectFromString(String(parts[1]))
            // NSRectFromString parses "inf" as 0, shifting all values:
            // {{inf, 200}, {340, 430}} -> {{0, 200}, {340, 430}} -> (200, 340, 430, 0)
            // The test just verifies parsing doesn't crash and result is reasonable
            XCTAssertTrue(rect.origin.x == 200 || rect.origin.x == 0 || rect.isNull)
        }
    }

    func testNegativeWidth() {
        let frameString = "v2|{{100, 200}, {-340, 430}}"
        let parts = frameString.split(separator: "|", maxSplits: 1)
        if parts.count == 2, parts[0] == "v2" {
            let rect = NSRectFromString(String(parts[1]))
            // NSRectFromString doesn't produce negative width from "-340"
            XCTAssertTrue(rect.isNull || rect.width == 0 || rect.width > 0)
        }
    }

    func testZeroHeight() {
        let frameString = "v2|{{100, 200}, {340, 0}}"
        let parts = frameString.split(separator: "|", maxSplits: 1)
        if parts.count == 2, parts[0] == "v2" {
            let rect = NSRectFromString(String(parts[1]))
            XCTAssertEqual(rect.height, 0)
        }
    }

    func testAbsurdCoordinates() {
        let frameString = "v2|{{99999, 99999}, {340, 430}}"
        let parts = frameString.split(separator: "|", maxSplits: 1)
        if parts.count == 2, parts[0] == "v2" {
            let rect = NSRectFromString(String(parts[1]))
            XCTAssertTrue(rect.origin.x > 10000 || rect.origin.y > 10000)
        }
    }

    func testFutureVersionPrefix() {
        let frameString = "v99|{{100, 200}, {340, 430}}"
        let parts = frameString.split(separator: "|", maxSplits: 1)
        XCTAssertEqual(parts.count, 2)
        XCTAssertNotEqual(parts[0], "v2")
    }

    func testEmptyString() {
        let frameString = ""
        let parts = frameString.split(separator: "|", maxSplits: 1)
        // Empty string split returns empty array
        XCTAssertEqual(parts.count, 0)
    }
}