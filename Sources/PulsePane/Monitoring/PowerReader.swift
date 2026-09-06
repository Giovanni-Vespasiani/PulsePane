import Foundation
import IOKit
import os

/// Reads system power draw from Apple's battery telemetry.
///
/// # Source
/// `IOKit` service `AppleSmartBattery` → property `PowerTelemetryData` → key `SystemLoad`.
///
/// # Semantics (Critical)
/// The exact meaning of `SystemLoad` is **not officially documented by Apple**.
/// Empirical validation on Apple M4 / macOS 26.6.2:
/// - Idle: ≈ 5894 → ≈ 5.9 W
/// - Under 10×`yes` load: ≈ 8617 → ≈ 8.6 W
/// - Raw magnitude (thousands) is consistent with **milliwatts**.
/// - Cross-validated against boot-time `AccumulatedSystemLoad / SystemLoadAccumulatorCount` average.
///
/// **Internal naming convention:** We refer to this metric as "reported system load power"
/// to avoid claiming it represents total system power with certainty. The UI displays
/// it as "Power" with unit "W" but this is an *estimate derived from Apple telemetry*.
///
/// # Hardware Dependencies
/// - Requires `AppleSmartBattery` service → present on MacBooks (has battery)
/// - May be absent on: Mac mini, Mac Studio, Mac Pro, desktop Macs without battery
/// - On such systems, power metric will be unavailable (`nil` → UI shows `—`)
///
/// # Error Handling
/// - Service absent → unavailable
/// - PowerTelemetryData missing → unavailable
/// - SystemLoad missing → unavailable
/// - Non-numeric / negative / NaN / infinity → rejected
/// - Absurdly large values (>500W) → rejected as likely malformed
final class PowerReader: @unchecked Sendable {

    // MARK: - Configuration

    private static let serviceMatch = "AppleSmartBattery"
    private static let telemetryKey = "PowerTelemetryData"
    private static let loadKey = "SystemLoad"

    // Plausible bounds for a MacBook system power (watts)
    private static let minPlausibleWatts = 0.0
    private static let maxPlausibleWatts = 500.0

    // MARK: - State

    private let logger = Logger(subsystem: "com.github.Giovanni-Vespasiani.PulsePane", category: "power")

    // MARK: - Public API

    /// Returns estimated system power in watts, or `nil` if unavailable.
    ///
    /// The value is derived from `AppleSmartBattery.PowerTelemetryData.SystemLoad`
    /// divided by 1000 (assuming milliwatts). This is an Apple telemetry estimate,
    /// not a lab-grade power meter reading.
    func powerWatts() -> Double? {
        let match = IOServiceMatching(Self.serviceMatch)
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == KERN_SUCCESS else {
            logger.debug("Power: IOServiceGetMatchingServices failed for \(Self.serviceMatch)")
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service: io_object_t = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }
            if let watts = readWatts(from: service) {
                return watts
            }
            service = IOIteratorNext(iterator)
        }

        logger.debug("Power: no AppleSmartBattery service with valid PowerTelemetryData")
        return nil
    }

    // MARK: - Private

    private func readWatts(from service: io_registry_entry_t) -> Double? {
        guard let cf = IORegistryEntryCreateCFProperty(
            service,
            Self.telemetryKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? [String: Any] else {
            logger.debug("Power: PowerTelemetryData missing or not a dictionary")
            return nil
        }

        guard let raw = cf[Self.loadKey] else {
            logger.debug("Power: SystemLoad key missing from PowerTelemetryData")
            return nil
        }

        let milliwatts: Double?
        switch raw {
        case let n as CFNumber:
            var out: Double = 0
            guard CFNumberGetValue(n, .doubleType, &out) else {
                logger.debug("Power: SystemLoad CFNumber conversion failed")
                return nil
            }
            milliwatts = out
        case let n as NSNumber:
            milliwatts = n.doubleValue
        case let n as Int:
            milliwatts = Double(n)
        case let n as Int32:
            milliwatts = Double(n)
        case let n as Int64:
            milliwatts = Double(n)
        default:
            logger.debug("Power: SystemLoad has unexpected type \(type(of: raw))")
            return nil
        }

        guard let mw = milliwatts, mw.isFinite else {
            logger.debug("Power: SystemLoad is non-finite")
            return nil
        }

        guard mw >= 0 else {
            logger.debug("Power: SystemLoad is negative (\(mw))")
            return nil
        }

        let watts = mw / 1000.0

        // Plausibility check
        guard watts >= Self.minPlausibleWatts, watts <= Self.maxPlausibleWatts else {
            logger.warning("Power: value \(watts) W outside plausible range [\(Self.minPlausibleWatts), \(Self.maxPlausibleWatts)]")
            return nil
        }

        return watts
    }
}