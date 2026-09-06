import Foundation
import Darwin
import IOKit

/// Lightweight capability detection and hardware description.
///
/// This component provides a snapshot of what the current system can report.
/// It is used for:
/// - Diagnostics (issue reports, compatibility work)
/// - Graceful degradation when optional capabilities are unavailable
/// - Future public support matrix
///
/// All data is local only — never transmitted.
final class SystemCapabilities {

    // MARK: - Public Snapshot

    struct Snapshot: Sendable {
        let machineModel: String          // e.g. "MacBookAir16,13"
        let architecture: String          // e.g. "arm64"
        let macOSVersion: String          // e.g. "26.6.2"
        let isAppleSilicon: Bool
        let cpuLogicalCount: Int
        let physicalMemoryBytes: UInt64

        // Optional capability availability
        let gpuAvailable: Bool
        let powerAvailable: Bool
        let temperatureAvailable: Bool
        let networkAvailable: Bool
        let diskAvailable: Bool

        // GPU details (when available)
        let gpuServiceClass: String?      // e.g. "AGXAcceleratorG16G"
        let gpuBundleID: String?          // e.g. "com.apple.AGXG16G"
        let gpuPreferredKey: String?      // e.g. "Device Utilization %"

        // Power details
        let powerSource: String?          // e.g. "AppleSmartBattery.PowerTelemetryData.SystemLoad"

        let timestamp: Date
    }

    // MARK: - Detection

    static func detect() -> Snapshot {
        let model = Self.machineModel()
        let arch = Self.architecture()
        let macOS = Self.macOSVersion()
        let cpuCount = Self.logicalCPUCount()
        let memBytes = Self.physicalMemoryBytes()
        let isAppleSilicon = model.hasPrefix("Mac") && (arch == "arm64")

        let gpuInfo = Self.detectGPU()
        let powerInfo = Self.detectPower()
        let tempInfo = Self.detectTemperature()
        let netInfo = Self.detectNetwork()
        let diskInfo = Self.detectDisk()

        return Snapshot(
            machineModel: model,
            architecture: arch,
            macOSVersion: macOS,
            isAppleSilicon: isAppleSilicon,
            cpuLogicalCount: cpuCount,
            physicalMemoryBytes: memBytes,
            gpuAvailable: gpuInfo.available,
            powerAvailable: powerInfo.available,
            temperatureAvailable: tempInfo.available,
            networkAvailable: netInfo.available,
            diskAvailable: diskInfo.available,
            gpuServiceClass: gpuInfo.serviceClass,
            gpuBundleID: gpuInfo.bundleID,
            gpuPreferredKey: gpuInfo.preferredKey,
            powerSource: powerInfo.sourceDescription,
            timestamp: Date()
        )
    }

    // MARK: - Individual Detectors

    private static func machineModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    private static func architecture() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var arch = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &arch, &size, nil, 0)
        return String(cString: arch)
    }

    private static func macOSVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private static func logicalCPUCount() -> Int {
        var count: UInt32 = 0
        var size = MemoryLayout<UInt32>.size
        sysctlbyname("hw.logicalcpu", &count, &size, nil, 0)
        return Int(count)
    }

    private static func physicalMemoryBytes() -> UInt64 {
        var mem: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        let mib: [Int32] = [CTL_HW, HW_MEMSIZE]
        _ = mib.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return false }
            return sysctl(
                UnsafeMutablePointer(mutating: base),
                UInt32(buffer.count),
                &mem,
                &size,
                nil,
                0
            ) == 0
        }
        return mem
    }

    // GPU detection
    private static func detectGPU() -> (available: Bool, serviceClass: String?, bundleID: String?, preferredKey: String?) {
        let match = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == KERN_SUCCESS else {
            return (false, nil, nil, nil)
        }
        defer { IOObjectRelease(iterator) }

        var service: io_object_t = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }

            // Get service class
            var className = ""
            if let cfClass = IORegistryEntryCreateCFProperty(service, "IOObjectClass" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
                className = cfClass
            }

            // Get bundle ID
            var bundleID = ""
            if let cfBundle = IORegistryEntryCreateCFProperty(service, kIOBundleIdentifierKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
                bundleID = cfBundle
            }

            // Check PerformanceStatistics for preferred keys
            let keys = ["Device Utilization %", "Renderer Utilization %", "Tiler Utilization %"]
            var foundKey: String? = nil
            if let cf = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
                for key in keys {
                    if cf[key] != nil {
                        foundKey = key
                        break
                    }
                }
            }

            if !className.isEmpty {
                return (true, className, bundleID.isEmpty ? nil : bundleID, foundKey)
            }

            service = IOIteratorNext(iterator)
        }
        return (false, nil, nil, nil)
    }

    // Power detection
    private static func detectPower() -> (available: Bool, sourceDescription: String?) {
        let match = IOServiceMatching("AppleSmartBattery")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == KERN_SUCCESS else {
            return (false, nil)
        }
        defer { IOObjectRelease(iterator) }

        var service: io_object_t = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }
            if let cf = IORegistryEntryCreateCFProperty(
                service,
                "PowerTelemetryData" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any],
               cf["SystemLoad"] != nil {
                return (true, "AppleSmartBattery.PowerTelemetryData.SystemLoad")
            }
            service = IOIteratorNext(iterator)
        }
        return (false, nil)
    }

    // Temperature detection (currently unsupported)
    private static func detectTemperature() -> (available: Bool) {
        // AppleSmartBattery Temperature exists but is battery temp, not SoC
        // IOReport MSP0/MSP1 channels require private libIOReport
        // No clean non-privileged SoC temperature API found
        return (false)
    }

    // Network detection
    private static func detectNetwork() -> (available: Bool) {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let list = ifap else { return (false) }
        defer { freeifaddrs(ifap) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = list
        while let current = cursor {
            cursor = current.pointee.ifa_next
            guard let addr = current.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
            let name = String(cString: current.pointee.ifa_name)
            let flags = current.pointee.ifa_flags
            if (flags & UInt32(IFF_UP)) != 0, (flags & UInt32(IFF_LOOPBACK)) == 0,
               !name.hasPrefix("lo"), !name.hasPrefix("awdl"), !name.hasPrefix("llw"),
               !name.hasPrefix("utun"), !name.hasPrefix("ipsec"), !name.hasPrefix("gif"),
               !name.hasPrefix("stf") {
                return (true)
            }
        }
        return (false)
    }

    // Disk detection
    private static func detectDisk() -> (available: Bool) {
        let match = IOServiceMatching("IOBlockStorageDriver")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == KERN_SUCCESS else {
            return (false)
        }
        defer { IOObjectRelease(iterator) }

        var service: io_object_t = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }
            if let cf = IORegistryEntryCreateCFProperty(
                service, "Statistics" as CFString, kCFAllocatorDefault, 0
            )?.takeRetainedValue() as? [String: Any],
               cf["Total Time (Write)"] != nil {
                return (true)
            }
            service = IOIteratorNext(iterator)
        }
        return (false)
    }
}