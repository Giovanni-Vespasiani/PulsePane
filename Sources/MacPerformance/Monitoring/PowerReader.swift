import Foundation
import IOKit

/// Estimates total system power draw (watts) from Apple's own live power
/// telemetry, without privileges.
///
/// # Source
/// `IOKit` service `AppleSmartBattery` → property `PowerTelemetryData` →
/// `SystemLoad`.
///
/// # How it was validated (2026-09-05, Apple M4 / macOS 26.6.2)
/// - Idle: `SystemLoad` ≈ 5894 → ≈ 5.9 W.
/// - Under 10×`yes` CPU load: `SystemLoad` ≈ 8617 → ≈ 8.6 W (clearly responds
///   to load).
/// - Units inferred as **milliwatts**: the boot-time
///   `AccumulatedSystemLoad / SystemLoadAccumulatorCount` average is coherent
///   with milliwatts, and the raw magnitude (5–9 W idle/loaded) matches
///   plausible system power on this MacBook Air more closely than any other
///   unit. Treat the value as an approximate estimate from Apple's telemetry,
///   not a lab-grade power meter.
///
/// # Honesty rules enforced
/// - `nil` if the service / key is missing; never a made-up number.
/// - No `sudo`, no privileged polling.
final class PowerReader: @unchecked Sendable {

    private static let serviceMatching = "AppleSmartBattery"
    private static let telemetryKey = "PowerTelemetryData"
    private static let loadKey = "SystemLoad"

    /// Returns total system power in watts, or `nil` if unavailable.
    func powerWatts() -> Double? {
        let match = IOServiceMatching(Self.serviceMatching)
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service: io_object_t = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }
            if let watts = watts(from: service) {
                return watts
            }
            service = IOIteratorNext(iterator)
        }
        return nil
    }

    private func watts(from service: io_registry_entry_t) -> Double? {
        guard let cf = IORegistryEntryCreateCFProperty(
            service,
            Self.telemetryKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        guard let milliwatts = double(from: cf[Self.loadKey]) else { return nil }
        guard milliwatts >= 0 else { return nil }
        return milliwatts / 1000
    }

    private func double(from value: Any?) -> Double? {
        switch value {
        case let n as NSNumber:
            return n.doubleValue
        case let n as CFNumber:
            var out: Double = 0
            guard CFNumberGetValue(n, .doubleType, &out) else { return nil }
            return out
        default:
            return nil
        }
    }
}