import XCTest
@testable import PulsePane

final class NetworkHoldTests: XCTestCase {
    private func makeStats(upload: Double?, download: Double?) -> SystemStats {
        SystemStats(
            cpuUsage: 10,
            gpuUsage: nil,
            memoryUsed: 0,
            memoryTotal: 0,
            cpuFrequencyGHz: nil,
            gpuName: nil,
            networkUploadBytesPerSec: upload,
            networkDownloadBytesPerSec: download,
            networkQuality: nil,
            diskReadBytesPerSec: nil,
            diskWriteBytesPerSec: nil,
            powerWatts: nil,
            socTemperatureCelsius: nil,
            timestamp: Date()
        )
    }

    func testValidNonZeroThenResetThenValidNonZero() {
        let model = PerformanceModel()
        // valid nonzero
        model.update(makeStats(upload: 1000, download: 2000))
        XCTAssertEqual(model.displayUpload, 1000)
        XCTAssertEqual(model.displayDownload, 2000)
        // reset (nil)
        model.update(makeStats(upload: nil, download: nil))
        // hold for up to 2 cycles
        XCTAssertEqual(model.displayUpload, 1000)
        XCTAssertEqual(model.displayDownload, 2000)
        // second nil still hold
        model.update(makeStats(upload: nil, download: nil))
        XCTAssertEqual(model.displayUpload, 1000)
        XCTAssertEqual(model.displayDownload, 2000)
        // third nil -> hold expired
        model.update(makeStats(upload: nil, download: nil))
        XCTAssertNil(model.displayUpload)
        XCTAssertNil(model.displayDownload)
        // new valid nonzero
        model.update(makeStats(upload: 1500, download: 2500))
        XCTAssertEqual(model.displayUpload, 1500)
        XCTAssertEqual(model.displayDownload, 2500)
    }

    func testValidNonZeroThenBaselineThenValid() {
        let model = PerformanceModel()
        model.update(makeStats(upload: 1000, download: 2000))
        XCTAssertEqual(model.displayUpload, 1000)
        // baseline (first sample after interface switch) -> nil
        model.update(makeStats(upload: nil, download: nil))
        // hold
        XCTAssertEqual(model.displayUpload, 1000)
        // next sample valid
        model.update(makeStats(upload: 1200, download: 2200))
        XCTAssertEqual(model.displayUpload, 1200)
    }

    func testValidZeroThenResetThenValidZero() {
        let model = PerformanceModel()
        model.update(makeStats(upload: 0, download: 0))
        XCTAssertEqual(model.displayUpload, 0)
        XCTAssertEqual(model.displayDownload, 0)
        // reset -> nil
        model.update(makeStats(upload: nil, download: nil))
        // hold zero
        XCTAssertEqual(model.displayUpload, 0)
        model.update(makeStats(upload: nil, download: nil))
        XCTAssertEqual(model.displayUpload, 0)
        // third nil -> hold expired
        model.update(makeStats(upload: nil, download: nil))
        XCTAssertNil(model.displayUpload)
        // new valid zero
        model.update(makeStats(upload: 0, download: 0))
        XCTAssertEqual(model.displayUpload, 0)
    }

    func testValidNonZeroThenUnavailableOneCycleThenRecover() {
        let model = PerformanceModel()
        model.update(makeStats(upload: 1000, download: 2000))
        XCTAssertEqual(model.displayUpload, 1000)
        // one unavailable cycle
        model.update(makeStats(upload: nil, download: nil))
        XCTAssertEqual(model.displayUpload, 1000) // hold
        // recover
        model.update(makeStats(upload: 1100, download: 2100))
        XCTAssertEqual(model.displayUpload, 1100)
    }

    func testValidNonZeroThenUnavailableBeyondHoldWindow() {
        let model = PerformanceModel()
        model.update(makeStats(upload: 1000, download: 2000))
        XCTAssertEqual(model.displayUpload, 1000)
        // three unavailable cycles (hold window = 2)
        model.update(makeStats(upload: nil, download: nil))
        model.update(makeStats(upload: nil, download: nil))
        model.update(makeStats(upload: nil, download: nil))
        XCTAssertNil(model.displayUpload)
        // recover after hold expired
        model.update(makeStats(upload: 1200, download: 2200))
        XCTAssertEqual(model.displayUpload, 1200)
    }

    func testSleepWakeBaselineReset() {
        let model = PerformanceModel()
        model.update(makeStats(upload: 1000, download: 2000))
        XCTAssertEqual(model.displayUpload, 1000)
        // sleep/wake triggers baseline reset -> nil
        model.update(makeStats(upload: nil, download: nil))
        // hold
        XCTAssertEqual(model.displayUpload, 1000)
        // next sample after wake is baseline nil again? Actually after wake, first sample may be nil then next valid.
        model.update(makeStats(upload: nil, download: nil))
        XCTAssertEqual(model.displayUpload, 1000) // second hold
        model.update(makeStats(upload: nil, download: nil))
        XCTAssertNil(model.displayUpload) // hold expired
        // then valid
        model.update(makeStats(upload: 1300, download: 2300))
        XCTAssertEqual(model.displayUpload, 1300)
    }

    func testGenuineZeroImmediatelyAfterValidNonZero() {
        let model = PerformanceModel()
        model.update(makeStats(upload: 1000, download: 2000))
        XCTAssertEqual(model.displayUpload, 1000)
        // genuine zero traffic
        model.update(makeStats(upload: 0, download: 0))
        // zero is valid, should display 0 immediately
        XCTAssertEqual(model.displayUpload, 0)
        XCTAssertEqual(model.displayDownload, 0)
        // next nil should hold zero
        model.update(makeStats(upload: nil, download: nil))
        XCTAssertEqual(model.displayUpload, 0)
    }
}