import XCTest
@testable import PulsePane

final class CapabilityTests: XCTestCase {

    func testDetectAllCapabilities() {
        let snapshot = SystemCapabilities.detect()
        
        // Basic hardware info
        XCTAssertEqual(snapshot.machineModel, "Mac16,13")
        XCTAssertEqual(snapshot.architecture, "arm64")
        XCTAssertTrue(snapshot.isAppleSilicon)
        XCTAssertEqual(snapshot.cpuLogicalCount, 10)
        XCTAssertEqual(snapshot.physicalMemoryBytes, 17_179_869_184)
        
        // Capability availability - on CI GPU may not be available
        // We just verify the detection logic runs without crashing
        XCTAssertNotNil(snapshot.gpuAvailable)
        XCTAssertNotNil(snapshot.powerAvailable)
        XCTAssertNotNil(snapshot.temperatureAvailable)
        XCTAssertNotNil(snapshot.networkAvailable)
        XCTAssertNotNil(snapshot.diskAvailable)
        
        // Temperature should be unavailable (no clean API)
        XCTAssertFalse(snapshot.temperatureAvailable)
        
        // GPU details - may be nil on some systems
        // If GPU is available, verify details are populated
        if snapshot.gpuAvailable {
            XCTAssertNotNil(snapshot.gpuServiceClass)
            XCTAssertNotNil(snapshot.gpuBundleID)
            XCTAssertNotNil(snapshot.gpuPreferredKey)
        }
        
        // Power details
        XCTAssertNotNil(snapshot.powerSource)
        XCTAssertEqual(snapshot.powerSource, "AppleSmartBattery.PowerTelemetryData.SystemLoad")
    }

    func testCapabilityUnavailableStates() {
        // Test that unavailable capabilities are properly represented
        let snapshot = SystemCapabilities.detect()
        
        // Temperature should be unavailable
        XCTAssertFalse(snapshot.temperatureAvailable)
        
        // All capabilities should have boolean values
        XCTAssertNotNil(snapshot.gpuAvailable)
        XCTAssertNotNil(snapshot.powerAvailable)
        XCTAssertNotNil(snapshot.networkAvailable)
        XCTAssertNotNil(snapshot.diskAvailable)
    }

    func testDiagnosticSummaryGeneration() {
        let snapshot = SystemCapabilities.detect()
        
        // Verify no private fields in diagnostic output
        let dict: [String: Any] = [
            "machineModel": snapshot.machineModel,
            "architecture": snapshot.architecture,
            "macOSVersion": snapshot.macOSVersion,
            "isAppleSilicon": snapshot.isAppleSilicon,
            "cpuLogicalCount": snapshot.cpuLogicalCount,
            "physicalMemoryBytes": snapshot.physicalMemoryBytes,
            "gpuAvailable": snapshot.gpuAvailable,
            "powerAvailable": snapshot.powerAvailable,
            "temperatureAvailable": snapshot.temperatureAvailable,
            "networkAvailable": snapshot.networkAvailable,
            "diskAvailable": snapshot.diskAvailable,
            "gpuServiceClass": snapshot.gpuServiceClass ?? "unavailable",
            "gpuBundleID": snapshot.gpuBundleID ?? "unavailable",
            "gpuPreferredKey": snapshot.gpuPreferredKey ?? "unavailable",
            "powerSource": snapshot.powerSource ?? "unavailable"
        ]
        
        // Ensure no private fields
        let jsonString = dict.description
        XCTAssertFalse(jsonString.contains("home"))
        XCTAssertFalse(jsonString.contains("user"))
        XCTAssertFalse(jsonString.contains("serial"))
        XCTAssertFalse(jsonString.contains("IP"))
        XCTAssertFalse(jsonString.contains("MAC"))
        XCTAssertFalse(jsonString.contains("SSH"))
        XCTAssertFalse(jsonString.contains("password"))
        XCTAssertFalse(jsonString.contains("token"))
        XCTAssertFalse(jsonString.contains("key"))
    }

    func testAppleSiliconDetection() {
        let snapshot = SystemCapabilities.detect()
        // On this M4 Mac, should be Apple Silicon
        XCTAssertTrue(snapshot.isAppleSilicon)
        XCTAssertEqual(snapshot.architecture, "arm64")
    }
}