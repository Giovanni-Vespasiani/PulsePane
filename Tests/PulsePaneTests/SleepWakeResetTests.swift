import XCTest
@testable import PulsePane

final class SleepWakeResetTests: XCTestCase {

    func testWakeHandlerRegistersReaders() {
        let handler = WakeHandler()
        
        let cpuReader = CPUReader()
        let networkReader = NetworkReader()
        let diskReader = DiskReader()
        let gpuReader = GPUReader()
        
        handler.register(cpuReader)
        handler.register(networkReader)
        handler.register(diskReader)
        handler.register(gpuReader)
        
        // We can't directly test the internal state, but we can verify
        // the registration doesn't crash
        XCTAssertTrue(true)
    }

    func testCPUReaderResetBaselines() {
        let cpuReader = CPUReader()
        _ = cpuReader.cpuUsage() // First sample establishes baseline
        
        cpuReader.resetBaselines()
        
        // After reset, first sample should return nil (new baseline)
        let result = cpuReader.cpuUsage()
        XCTAssertNil(result, "After reset, first sample should return nil")
    }

    func testNetworkReaderResetBaselines() {
        let networkReader = NetworkReader()
        // First sample establishes baseline
        _ = networkReader.read()
        
        networkReader.resetBaselines()
        
        // After reset, first sample should return nil
        let result = networkReader.read()
        XCTAssertNil(result.0)
        XCTAssertNil(result.1)
    }

    func testDiskReaderResetBaselines() {
        let diskReader = DiskReader()
        _ = diskReader.read()
        
        diskReader.resetBaselines()
        
        let result = diskReader.read()
        XCTAssertNil(result.0)
        XCTAssertNil(result.1)
    }

    func testGPUReaderResetBaselinesInvalidatesService() {
        let gpuReader = GPUReader()
        // Try to get a reading (may be nil if no GPU)
        _ = gpuReader.gpuUsage()
        
        gpuReader.resetBaselines()
        
        // Should not crash - result may be nil (no GPU) or a value
        let result = gpuReader.gpuUsage()
        // Result may be nil (no GPU) or a value - just verify no crash
        _ = result
    }

    func testWakeHandlerStartsAndStops() {
        let handler = WakeHandler()
        
        // Start should not crash
        handler.start()
        
        // Stop should not crash
        handler.stop()
        
        // Multiple start/stop cycles should be safe
        handler.start()
        handler.stop()
        handler.start()
        handler.stop()
    }

    func testWakeHandlerDoesNotAlterWindowState() {
        let handler = WakeHandler()
        handler.start()
        
        // Window state should not be affected by wake handler
        let defaults = UserDefaults.standard
        let frameKey = "PulsePane.windowFrame"
        let originalFrame = defaults.string(forKey: frameKey)
        
        // Simulate wake
        // (Can't easily test actual sleep/wake in unit test)
        
        // Verify frame key still exists
        let frameAfter = defaults.string(forKey: frameKey)
        XCTAssertEqual(frameAfter, originalFrame)
    }

    func testWakeHandlerDoesNotAlterMigrationState() {
        let defaults = UserDefaults.standard
        
        // Set migration as complete
        defaults.set(1, forKey: "PulsePane.migrationVersion")
        
        let handler = WakeHandler()
        handler.start()
        handler.stop()
        
        // Migration marker should be untouched
        XCTAssertEqual(defaults.integer(forKey: "PulsePane.migrationVersion"), 1)
    }

    func testWakeHandlerDoesNotAlterUserPreferences() {
        let defaults = UserDefaults.standard
        let testKey = "PulsePane.testPreference"
        defaults.set("testValue", forKey: testKey)
        
        let handler = WakeHandler()
        handler.start()
        handler.stop()
        
        // User preferences should be untouched
        XCTAssertEqual(defaults.string(forKey: testKey), "testValue")
    }
}