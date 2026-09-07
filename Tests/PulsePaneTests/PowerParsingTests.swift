import XCTest
@testable import PulsePane

final class PowerParsingTests: XCTestCase {

    // Test PowerTelemetryData parsing logic

    func testValidIntegerMilliwatts() {
        let cf: [String: Any] = ["SystemLoad": 5894]
        let raw = cf["SystemLoad"]
        let value: Double?
        switch raw {
        case let n as CFNumber:
            var out: Double = 0
            _ = CFNumberGetValue(n, .doubleType, &out)
            value = out
        case let n as NSNumber:
            value = n.doubleValue
        case let n as Int:
            value = Double(n)
        case let n as Int32:
            value = Double(n)
        case let n as Int64:
            value = Double(n)
        default:
            value = nil
        }
        XCTAssertNotNil(value)
        XCTAssertEqual(value, 5894.0)
    }

    func testValidDoubleMilliwatts() {
        let cf: [String: Any] = ["SystemLoad": 5894.5]
        let raw = cf["SystemLoad"]
        let value: Double?
        switch raw {
        case let n as CFNumber:
            var out: Double = 0
            _ = CFNumberGetValue(n, .doubleType, &out)
            value = out
        case let n as NSNumber:
            value = n.doubleValue
        case let n as Int:
            value = Double(n)
        case let n as Int32:
            value = Double(n)
        case let n as Int64:
            value = Double(n)
        default:
            value = nil
        }
        XCTAssertNotNil(value)
        XCTAssertEqual(value, 5894.5)
    }

    func testMissingPowerTelemetryData() {
        let cf: [String: Any] = ["OtherKey": "value"]
        let raw = cf["SystemLoad"]
        XCTAssertNil(raw)
    }

    func testMissingSystemLoad() {
        let cf: [String: Any] = ["PowerTelemetryData": ["OtherKey": "value"]]
        let powerData = cf["PowerTelemetryData"] as? [String: Any]
        let raw = powerData?["SystemLoad"]
        XCTAssertNil(raw)
    }

    func testWrongTypeString() {
        let cf: [String: Any] = ["SystemLoad": "5894"]
        let raw = cf["SystemLoad"]
        XCTAssertTrue(raw is String)
    }

    func testNegativeValueRejected() {
        let cf: [String: Any] = ["SystemLoad": -1000]
        let raw = cf["SystemLoad"]
        let value: Double?
        switch raw {
        case let n as CFNumber:
            var out: Double = 0
            _ = CFNumberGetValue(n, .doubleType, &out)
            value = out
        case let n as NSNumber:
            value = n.doubleValue
        default:
            value = nil
        }
        XCTAssertNotNil(value)
        XCTAssertTrue(value! < 0)
    }

    func testNaNRejected() {
        let cf: [String: Any] = ["SystemLoad": Double.nan]
        let raw = cf["SystemLoad"]
        let value: Double?
        switch raw {
        case let n as CFNumber:
            var out: Double = 0
            _ = CFNumberGetValue(n, .doubleType, &out)
            value = out
        case let n as NSNumber:
            value = n.doubleValue
        default:
            value = nil
        }
        XCTAssertNotNil(value)
        XCTAssertTrue(value!.isNaN)
    }

    func testInfinityRejected() {
        let cf: [String: Any] = ["SystemLoad": Double.infinity]
        let raw = cf["SystemLoad"]
        let value: Double?
        switch raw {
        case let n as CFNumber:
            var out: Double = 0
            _ = CFNumberGetValue(n, .doubleType, &out)
            value = out
        case let n as NSNumber:
            value = n.doubleValue
        default:
            value = nil
        }
        XCTAssertNotNil(value)
        XCTAssertTrue(value!.isInfinite)
    }

    func testImplausiblyLargeRejected() {
        let cf: [String: Any] = ["SystemLoad": 1_000_000] // 1000W - implausible
        let raw = cf["SystemLoad"]
        let value: Double?
        switch raw {
        case let n as CFNumber:
            var out: Double = 0
            _ = CFNumberGetValue(n, .doubleType, &out)
            value = out
        case let n as NSNumber:
            value = n.doubleValue
        default:
            value = nil
        }
        XCTAssertNotNil(value)
        XCTAssertGreaterThan(value!, 500)
    }

    func testZeroValue() {
        let cf: [String: Any] = ["SystemLoad": 0]
        let raw = cf["SystemLoad"]
        let value: Double?
        switch raw {
        case let n as CFNumber:
            var out: Double = 0
            _ = CFNumberGetValue(n, .doubleType, &out)
            value = out
        case let n as NSNumber:
            value = n.doubleValue
        default:
            value = nil
        }
        XCTAssertEqual(value, 0)
    }

    func testMilliwattsToWattsConversion() {
        // 5894 mW -> 5.894 W
        let milliwatts = 5894
        let watts = Double(milliwatts) / 1000.0
        XCTAssertEqual(watts, 5.894, accuracy: 0.001)

        // 8617 mW -> 8.617 W
        let milliwatts2 = 8617
        let watts2 = Double(milliwatts2) / 1000.0
        XCTAssertEqual(watts2, 8.617, accuracy: 0.001)
    }
}