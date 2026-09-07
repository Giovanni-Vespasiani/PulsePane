import XCTest
@testable import PulsePane

final class FormatterTests: XCTestCase {

    // MARK: - Byte Rate Formatting

    func testByteRateZero() {
        XCTAssertEqual(MetricFormatters.byteRate(0), "0 B/s")
    }

    func testByteRateBytes() {
        XCTAssertEqual(MetricFormatters.byteRate(999), "999 B/s")
    }

    func testByteRateKilobytes() {
        XCTAssertEqual(MetricFormatters.byteRate(1024), "1.0 KB/s")
        XCTAssertEqual(MetricFormatters.byteRate(1536), "1.5 KB/s")
        XCTAssertEqual(MetricFormatters.byteRate(999_999), "976.6 KB/s")
    }

    func testByteRateMegabytes() {
        XCTAssertEqual(MetricFormatters.byteRate(1024 * 1024), "1.0 MB/s")
        XCTAssertEqual(MetricFormatters.byteRate(10 * 1024 * 1024), "10.0 MB/s")
        XCTAssertEqual(MetricFormatters.byteRate(999 * 1024 * 1024), "999.0 MB/s")
    }

    func testByteRateGigabytes() {
        XCTAssertEqual(MetricFormatters.byteRate(1024 * 1024 * 1024), "1.00 GB/s")
        XCTAssertEqual(MetricFormatters.byteRate(2 * 1024 * 1024 * 1024), "2.00 GB/s")
    }

    func testByteRateNilReturnsDash() {
        XCTAssertEqual(MetricFormatters.byteRate(nil), "—")
    }

    func testByteRateNegativeReturnsDash() {
        XCTAssertEqual(MetricFormatters.byteRate(-100), "—")
    }

    func testByteRateNaNReturnsDash() {
        XCTAssertEqual(MetricFormatters.byteRate(Double.nan), "—")
    }

    // MARK: - Power Formatting

    func testPowerFormatting() {
        XCTAssertEqual(MetricFormatters.power(0), "0.0 W")
        XCTAssertEqual(MetricFormatters.power(5.9), "5.9 W")
        XCTAssertEqual(MetricFormatters.power(8.6), "8.6 W")
        XCTAssertEqual(MetricFormatters.power(100), "100.0 W")
    }

    func testPowerNilReturnsDash() {
        XCTAssertEqual(MetricFormatters.power(nil), "—")
    }

    func testPowerNegativeReturnsDash() {
        XCTAssertEqual(MetricFormatters.power(-1), "—")
    }

    // MARK: - Temperature Formatting

    func testTemperatureFormatting() {
        XCTAssertEqual(MetricFormatters.temperature(0), "0°C")
        XCTAssertEqual(MetricFormatters.temperature(33.7), "34°C")
        XCTAssertEqual(MetricFormatters.temperature(100), "100°C")
    }

    func testTemperatureNilReturnsDash() {
        XCTAssertEqual(MetricFormatters.temperature(nil), "—")
    }

    // MARK: - Percent Formatting

    func testPercentFormatting() {
        XCTAssertEqual(MetricFormatters.percent(0), "0%")
        XCTAssertEqual(MetricFormatters.percent(50.5), "50%")
        XCTAssertEqual(MetricFormatters.percent(100), "100%")
        XCTAssertEqual(MetricFormatters.percent(-10), "0%")
        XCTAssertEqual(MetricFormatters.percent(150), "100%")
    }

    func testPercentNilReturnsDash() {
        XCTAssertEqual(MetricFormatters.percent(nil), "—")
    }

    func testPercentNaNReturnsDash() {
        XCTAssertEqual(MetricFormatters.percent(Double.nan), "—")
    }

    // MARK: - Frequency Formatting

    func testFrequencyFormatting() {
        XCTAssertEqual(MetricFormatters.frequency(3.2), "3.20 GHz")
        XCTAssertEqual(MetricFormatters.frequency(0.5), "0.50 GHz")
    }

    func testFrequencyNilReturnsDash() {
        XCTAssertEqual(MetricFormatters.frequency(nil), "—")
    }

    // MARK: - Memory Formatting

    func testMemoryUsed() {
        // 8_000_000_000 bytes / (1024^3) = 7.45 GB -> "7.5 GB"
        XCTAssertEqual(MetricFormatters.memoryUsed(8_000_000_000), "7.5 GB")
        // 16_000_000_000 bytes / (1024^3) = 14.9 GB -> "14.9 GB"
        XCTAssertEqual(MetricFormatters.memoryUsed(16_000_000_000), "14.9 GB")
        // 8_589_934_592 bytes = 8 GiB exactly
        XCTAssertEqual(MetricFormatters.memoryUsed(8_589_934_592), "8.0 GB")
    }

    func testMemoryTotal() {
        XCTAssertEqual(MetricFormatters.memoryTotal(8_000_000_000), "7 GB")
        XCTAssertEqual(MetricFormatters.memoryTotal(16_000_000_000), "15 GB")
        // 8_589_934_592 bytes = 8 GiB exactly
        XCTAssertEqual(MetricFormatters.memoryTotal(8_589_934_592), "8 GB")
    }

    func testMemoryPercent() {
        XCTAssertEqual(MetricFormatters.memoryPercent(used: 8_589_934_592, total: 17_179_869_184), "50%")
        XCTAssertEqual(MetricFormatters.memoryPercent(used: 0, total: 17_179_869_184), "0%")
        XCTAssertEqual(MetricFormatters.memoryPercent(used: 17_179_869_184, total: 17_179_869_184), "100%")
        XCTAssertEqual(MetricFormatters.memoryPercent(used: 18_000_000_000, total: 16_000_000_000), "100%")
    }

    func testMemoryPercentNilTotal() {
        XCTAssertEqual(MetricFormatters.memoryPercent(used: 100, total: 0), "—")
    }
}