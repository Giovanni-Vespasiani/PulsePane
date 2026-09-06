import Foundation
import IOKit

/// Reads global GPU utilization from the Apple GPU driver via IOKit.
///
/// # How it works
/// We iterate IOKit services of class `IOAccelerator` and read the
/// `PerformanceStatistics` dictionary property through the public IOKit API
/// `IORegistryEntryCreateCFProperty`.
///
/// # Important caveat (read this)
/// `IORegistryEntryCreateCFProperty` is a *public* IOKit API, but the specific
/// keys inside `PerformanceStatistics` (`Device Utilization %`,
/// `Renderer Utilization %`, `Tiler Utilization %`) are **driver-provided,
/// empirical properties**. They are NOT a documented, stable Apple API
/// contract. They were verified present and live on:
///   - Hardware: Apple M4 (Mac16,13)
///   - OS: macOS 26.6.2 (SDK MacOSX26.5)
///   - Service: IOClass `AGXAcceleratorG16G`, CFBundleIdentifier
///     `com.apple.AGXG16G`, IONameMatched `gpu,t8132`
///
/// Compatibility risk: key names, types, or the presence of the dictionary
/// may change on other hardware / future macOS. This entire class is isolated
/// precisely so it can be replaced without touching the rest of the app.
///
/// # Counter choice
/// Primary: `Device Utilization %`. Fallbacks: `Renderer Utilization %`,
/// then `Tiler Utilization %`. If none is readable, returns `nil` — the UI
/// shows "GPU —" (unavailable), never a fake 0%.
final class GPUReader: @unchecked Sendable {

    private static let performanceStatisticsKey = "PerformanceStatistics"
    private static let preferredKeys = [
        "Device Utilization %",
        "Renderer Utilization %",
        "Tiler Utilization %",
    ]

    func gpuUsage() -> Double? {
        let match = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service: io_object_t = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }
            if let value = readUsage(from: service) {
                return value
            }
            service = IOIteratorNext(iterator)
        }
        return nil
    }

    private func readUsage(from service: io_registry_entry_t) -> Double? {
        guard let cf = IORegistryEntryCreateCFProperty(
            service,
            Self.performanceStatisticsKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue(),
        let dict = cf as? [String: Any] else {
            return nil
        }

        for key in Self.preferredKeys {
            if let value = double(from: dict[key]) {
                return min(max(value, 0), 100)
            }
        }
        return nil
    }

    private func double(from value: Any?) -> Double? {
        switch value {
        case let n as CFNumber:
            var out: Double = 0
            guard CFNumberGetValue(n, .doubleType, &out) else { return nil }
            return out
        case let n as NSNumber:
            return n.doubleValue
        case let n as Int:
            return Double(n)
        case let n as Int32:
            return Double(n)
        default:
            return nil
        }
    }
}