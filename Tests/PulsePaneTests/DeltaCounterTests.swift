import XCTest
@testable import PulsePane

final class DeltaCounterTests: XCTestCase {

    func testFirstSampleReturnsNil() {
        let counter = DeltaCounter()
        let result = counter.sample(newValue: 100, interval: 1.0)
        XCTAssertNil(result, "First sample should return nil")
    }

    func testNormalIncrementReturnsRate() {
        let counter = DeltaCounter()
        _ = counter.sample(newValue: 100, interval: 1.0) // baseline
        let result = counter.sample(newValue: 200, interval: 1.0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 100.0, accuracy: 0.001)
    }

    func testZeroIncrementReturnsZero() {
        let counter = DeltaCounter()
        _ = counter.sample(newValue: 100, interval: 1.0)
        let result = counter.sample(newValue: 100, interval: 1.0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 0.0, accuracy: 0.001)
    }

    func testCurrentEqualsPreviousReturnsZero() {
        let counter = DeltaCounter()
        _ = counter.sample(newValue: 100, interval: 1.0)
        let result = counter.sample(newValue: 100, interval: 1.0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 0.0, accuracy: 0.001)
    }

    func testCurrentLessThanPreviousReturnsNilAndResets() {
        let counter = DeltaCounter()
        _ = counter.sample(newValue: 100, interval: 1.0)
        let result = counter.sample(newValue: 50, interval: 1.0)
        XCTAssertNil(result, "Counter reset should return nil")
        // Next sample should establish new baseline
        let result2 = counter.sample(newValue: 150, interval: 1.0)
        XCTAssertNil(result2, "After reset, first sample should be nil")
        let result3 = counter.sample(newValue: 250, interval: 1.0)
        XCTAssertNotNil(result3)
        XCTAssertEqual(result3!, 100.0, accuracy: 0.001)
    }

    func testCounterResetClearsBaseline() {
        let counter = DeltaCounter()
        _ = counter.sample(newValue: 100, interval: 1.0)
        _ = counter.sample(newValue: 200, interval: 1.0)
        counter.reset()
        let result = counter.sample(newValue: 300, interval: 1.0)
        XCTAssertNil(result, "After reset, first sample should be nil")
    }

    func testHasBaselineReflectsState() {
        let counter = DeltaCounter()
        XCTAssertFalse(counter.hasBaseline)
        _ = counter.sample(newValue: 100, interval: 1.0)
        XCTAssertTrue(counter.hasBaseline)
        counter.reset()
        XCTAssertFalse(counter.hasBaseline)
    }

    func testVeryLargeValidIncrement() {
        let counter = DeltaCounter()
        _ = counter.sample(newValue: 0, interval: 1.0)
        let result = counter.sample(newValue: 10_000_000_000, interval: 1.0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 10_000_000_000.0, accuracy: 1.0)
    }

    func testOverflowBoundary() {
        let counter = DeltaCounter()
        _ = counter.sample(newValue: UInt64.max - 1000, interval: 1.0)
        let result = counter.sample(newValue: UInt64.max, interval: 1.0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 1000.0, accuracy: 1.0)
    }

    func testZeroElapsedIntervalReturnsNil() {
        let counter = DeltaCounter()
        _ = counter.sample(newValue: 100, interval: 1.0)
        let result = counter.sample(newValue: 200, interval: 0.0)
        XCTAssertNil(result)
    }
}