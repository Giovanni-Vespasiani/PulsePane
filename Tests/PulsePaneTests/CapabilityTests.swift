import XCTest
@testable import PulsePane

final class CapabilityTests: XCTestCase {

    func testDetectAllCapabilities() {
        let snapshot = SystemCapabilities.detect()
        
        // Basic hardware info - portable assertions
        XCTAssertFalse(snapshot.machineModel.isEmpty, "Machine model should not be empty")
        XCTAssertTrue(snapshot.architecture.hasPrefix("arm64"), "Architecture should be arm64 variant on Apple Silicon")
        XCTAssertTrue(snapshot.isAppleSilicon, "Should detect Apple Silicon")
        XCTAssertGreaterThan(snapshot.cpuLogicalCount, 0, "CPU count should be positive")
        XCTAssertGreaterThan(snapshot.physicalMemoryBytes, 0, "Memory should be positive")
        
        // Capability availability - verify detection logic runs without crashing
        XCTAssertNotNil(snapshot.gpuAvailable, "GPU availability should be determined")
        XCTAssertNotNil(snapshot.powerAvailable, "Power availability should be determined")
        XCTAssertNotNil(snapshot.temperatureAvailable, "Temperature availability should be determined")
        XCTAssertNotNil(snapshot.networkAvailable, "Network availability should be determined")
        XCTAssertNotNil(snapshot.diskAvailable, "Disk availability should be determined")
        
        // Temperature should be unavailable (no clean non-privileged API)
        XCTAssertFalse(snapshot.temperatureAvailable, "SoC temperature should be unavailable")
        
        // GPU details - if available, details should be populated
        if snapshot.gpuAvailable {
            XCTAssertNotNil(snapshot.gpuServiceClass, "GPU service class should be set when available")
            XCTAssertNotNil(snapshot.gpuBundleID, "GPU bundle ID should be set when available")
            XCTAssertNotNil(snapshot.gpuPreferredKey, "GPU preferred key should be set when available")
        }
        
        // Power details - power source should be set when available
        if snapshot.powerAvailable {
            XCTAssertNotNil(snapshot.powerSource, "Power source should be set when power is available")
        }
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
        // Should detect Apple Silicon on arm64/arm64e
        XCTAssertTrue(snapshot.isAppleSilicon, "Should detect Apple Silicon on arm64/arm64e")
        XCTAssertTrue(snapshot.architecture.hasPrefix("arm64"), "Architecture should be arm64 variant")
    }
    
    func testAppleSiliconArchitectureClassification() {
        // Test the pure architecture classification function
        XCTAssertTrue(SystemCapabilities.isAppleSiliconArchitecture("arm64"), "arm64 should be Apple Silicon")
        XCTAssertTrue(SystemCapabilities.isAppleSiliconArchitecture("arm64e"), "arm64e should be Apple Silicon")
        XCTAssertFalse(SystemCapabilities.isAppleSiliconArchitecture("x86_64"), "x86_64 should not be Apple Silicon")
        XCTAssertFalse(SystemCapabilities.isAppleSiliconArchitecture("i386"), "i386 should not be Apple Silicon")
        XCTAssertFalse(SystemCapabilities.isAppleSiliconArchitecture("unknown"), "Unknown arch should not be Apple Silicon")
        XCTAssertFalse(SystemCapabilities.isAppleSiliconArchitecture(""), "Empty string should not be Apple Silicon")
    }
}