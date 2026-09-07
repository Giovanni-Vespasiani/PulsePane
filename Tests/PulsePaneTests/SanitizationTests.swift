import XCTest
@testable import PulsePane

final class SanitizationTests: XCTestCase {

    // MARK: - Percent Sanitization

    func testPercentNormalValues() {
        XCTAssertEqual(MetricSanitizers.percent(0), 0)
        XCTAssertEqual(MetricSanitizers.percent(50), 50)
        XCTAssertEqual(MetricSanitizers.percent(100), 100)
    }

    func testPercentNegativeClampedToZero() {
        XCTAssertEqual(MetricSanitizers.percent(-10), 0)
    }

    func testPercentOver100Clamped() {
        XCTAssertEqual(MetricSanitizers.percent(150), 100)
    }

    func testPercentNaNReturnsNil() {
        XCTAssertNil(MetricSanitizers.percent(Double.nan))
    }

    func testPercentPositiveInfinityReturnsNil() {
        XCTAssertNil(MetricSanitizers.percent(Double.infinity))
    }

    func testPercentNegativeInfinityReturnsNil() {
        XCTAssertNil(MetricSanitizers.percent(-Double.infinity))
    }

    func testPercentNilReturnsNil() {
        XCTAssertNil(MetricSanitizers.percent(nil))
    }

    // MARK: - Throughput Sanitization

    func testThroughputNormalValues() {
        XCTAssertEqual(MetricSanitizers.throughput(0), 0)
        XCTAssertEqual(MetricSanitizers.throughput(1024), 1024)
        XCTAssertEqual(MetricSanitizers.throughput(1024 * 1024), 1024 * 1024)
    }

    func testThroughputNegativeReturnsNil() {
        XCTAssertNil(MetricSanitizers.throughput(-100))
    }

    func testThroughputNaNReturnsNil() {
        XCTAssertNil(MetricSanitizers.throughput(Double.nan))
    }

    func testThroughputInfinityReturnsNil() {
        XCTAssertNil(MetricSanitizers.throughput(Double.infinity))
    }

    func testThroughputAbsurdlyLargeReturnsNil() {
        XCTAssertNil(MetricSanitizers.throughput(200_000_000_000_000)) // > 100 TB/s
    }

    // MARK: - Power Sanitization

    func testPowerNormalValues() {
        XCTAssertEqual(MetricSanitizers.power(0), 0)
        XCTAssertEqual(MetricSanitizers.power(5.9), 5.9)
        XCTAssertEqual(MetricSanitizers.power(8.6), 8.6)
    }

    func testPowerNegativeReturnsNil() {
        XCTAssertNil(MetricSanitizers.power(-1))
    }

    func testPowerNaNReturnsNil() {
        XCTAssertNil(MetricSanitizers.power(Double.nan))
    }

    func testPowerInfinityReturnsNil() {
        XCTAssertNil(MetricSanitizers.power(Double.infinity))
    }

    func testPowerAboveMaxReturnsNil() {
        XCTAssertNil(MetricSanitizers.power(600)) // > 500W
    }

    func testPowerNilReturnsNil() {
        XCTAssertNil(MetricSanitizers.power(nil))
    }

    // MARK: - Temperature Sanitization

    func testTemperatureNormalValues() {
        XCTAssertEqual(MetricSanitizers.temperature(-20), -20)
        XCTAssertEqual(MetricSanitizers.temperature(33.7), 33.7)
        XCTAssertEqual(MetricSanitizers.temperature(100), 100)
    }

    func testTemperatureBelowRangeReturnsNil() {
        XCTAssertNil(MetricSanitizers.temperature(-60))
    }

    func testTemperatureAboveRangeReturnsNil() {
        XCTAssertNil(MetricSanitizers.temperature(200))
    }

    // MARK: - Memory Sanitization

    func testMemoryNormalValues() {
        let result = MetricSanitizers.memory(used: 8_000_000_000, total: 16_000_000_000)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.used, 8_000_000_000)
        XCTAssertEqual(result?.total, 16_000_000_000)
    }

    func testMemoryUsedClampedToTotal() {
        let result = MetricSanitizers.memory(used: 20_000_000_000, total: 16_000_000_000)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.used, 16_000_000_000)
        XCTAssertEqual(result?.total, 16_000_000_000)
    }

    func testMemoryZeroTotalReturnsNil() {
        XCTAssertNil(MetricSanitizers.memory(used: 100, total: 0))
    }

    func testMemoryNilUsedReturnsNil() {
        XCTAssertNil(MetricSanitizers.memory(used: nil, total: 16_000_000_000))
    }

    func testMemoryNilTotalReturnsNil() {
        XCTAssertNil(MetricSanitizers.memory(used: 100, total: nil))
    }

    // MARK: - Frequency Sanitization

    func testFrequencyNormalValues() {
        XCTAssertEqual(MetricSanitizers.frequencyGHz(3.2), 3.2)
        XCTAssertEqual(MetricSanitizers.frequencyGHz(0.5), 0.5)
    }

    func testFrequencyZeroReturnsNil() {
        XCTAssertNil(MetricSanitizers.frequencyGHz(0))
    }

    func testFrequencyNegativeReturnsNil() {
        XCTAssertNil(MetricSanitizers.frequencyGHz(-1))
    }

    func testFrequencyTooHighReturnsNil() {
        XCTAssertNil(MetricSanitizers.frequencyGHz(15))
    }

    func testFrequencyNaNReturnsNil() {
        XCTAssertNil(MetricSanitizers.frequencyGHz(Double.nan))
    }
}