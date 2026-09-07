import Foundation
import IOKit
import os

/// Reads global GPU utilization from the Apple GPU driver via IOKit.
///
/// # Architecture
/// - Service discovery is cached. `discover()` runs once on init and can be
///   re-triggered via `invalidate()` if the service becomes unavailable.
/// - Falls back through a prioritized list of utilization keys.
/// - All error paths return `nil` (unavailable) — never fake data.
/// - Malformed values are rejected with logging.
///
/// # Fallback Strategy (in priority order)
/// 1. `Device Utilization %` — aggregate device utilization (preferred)
/// 2. `Renderer Utilization %` — render pipeline utilization
/// 3. `Tiler Utilization %` — tiling pipeline utilization
///
/// If none are readable, GPU is reported as unavailable (UI shows "GPU —").
///
/// # Error Handling
/// - No IOAccelerator service → unavailable
/// - Multiple services → first one with valid stats wins
/// - PerformanceStatistics missing → unavailable
/// - All preferred keys missing → unavailable
/// - Wrong CF type / NaN / infinity / <0 / >100 → rejected, try next key
/// - Service invalidated → cache cleared, next sample will rediscover
final class GPUReader: @unchecked Sendable, WakeHandler.BaselineResettable {

    // MARK: - Configuration

    private enum CounterKey: String, CaseIterable {
        case device = "Device Utilization %"
        case renderer = "Renderer Utilization %"
        case tiler = "Tiler Utilization %"

        static let priorityOrder: [CounterKey] = [.device, .renderer, .tiler]
    }

    private static let serviceMatchKey = "IOAccelerator"
    private static let statsKey = "PerformanceStatistics"

    // MARK: - State

    private let logger = Logger(subsystem: "com.github.Giovanni-Vespasiani.PulsePane", category: "gpu")
    private var cachedService: io_object_t = 0
    private var isServiceValid = false

    // MARK: - Public API

    func gpuUsage() -> Double? {
        // Ensure we have a valid service
        guard ensureValidService() else {
            logger.debug("GPU: no valid IOAccelerator service")
            return nil
        }

        guard let stats = readPerformanceStatistics(from: cachedService) else {
            logger.debug("GPU: PerformanceStatistics unavailable, invalidating service")
            invalidate()
            return nil
        }

        // Try keys in priority order
        for key in CounterKey.priorityOrder {
            if let value = extractValidUtilization(from: stats, key: key.rawValue) {
                logger.debug("GPU: read \(key.rawValue) = \(value)%")
                return value
            }
        }

        logger.debug("GPU: no valid utilization keys found in PerformanceStatistics")
        return nil
    }

    /// Invalidates the cached service, forcing rediscovery on next sample.
    /// Called when the service appears to have become invalid.
    func invalidate() {
        if cachedService != 0 {
            IOObjectRelease(cachedService)
            cachedService = 0
        }
        isServiceValid = false
        logger.debug("GPU: service invalidated, will rediscover on next sample")
    }

    // MARK: - Private: Service Discovery

    private func ensureValidService() -> Bool {
        if isServiceValid, cachedService != 0 {
            return true
        }

        // Release any stale reference
        if cachedService != 0 {
            IOObjectRelease(cachedService)
            cachedService = 0
        }

        let match = IOServiceMatching(Self.serviceMatchKey)
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == KERN_SUCCESS else {
            logger.debug("GPU: IOServiceGetMatchingServices failed")
            return false
        }
        defer { IOObjectRelease(iterator) }

        var service: io_object_t = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }

            if let stats = readPerformanceStatistics(from: service),
               CounterKey.priorityOrder.contains(where: { extractValidUtilization(from: stats, key: $0.rawValue) != nil }) {
                cachedService = service
                // Retain for our cache; the iterator release is balanced by our retain
                IOObjectRetain(service)
                isServiceValid = true
                logger.info("GPU: discovered service with valid PerformanceStatistics")
                return true
            }
            service = IOIteratorNext(iterator)
        }

        logger.debug("GPU: no IOAccelerator service with valid PerformanceStatistics found")
        return false
    }

    // MARK: - Private: Statistics Reading

    private func readPerformanceStatistics(from service: io_registry_entry_t) -> [String: Any]? {
        guard let cf = IORegistryEntryCreateCFProperty(
            service,
            Self.statsKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else {
            return nil
        }
        return cf as? [String: Any]
    }

    // MARK: - Private: Value Extraction & Validation

    /// Extracts and validates a utilization value from the stats dictionary.
    ///
    /// Validation rules:
    /// - Must be numeric (CFNumber, NSNumber, Int, Int32, Double, Float)
    /// - Must be finite (not NaN, not infinity)
    /// - Must be in range [0, 100]
    /// - Returns nil if any check fails
    private func extractValidUtilization(from dict: [String: Any], key: String) -> Double? {
        guard let raw = dict[key] else { return nil }

        let value: Double?
        switch raw {
        case let n as CFNumber:
            var out: Double = 0
            guard CFNumberGetValue(n, .doubleType, &out) else { return nil }
            value = out
        case let n as NSNumber:
            value = n.doubleValue
        case let n as Int:
            value = Double(n)
        case let n as Int32:
            value = Double(n)
        case let n as Double:
            value = n
        case let n as Float:
            value = Double(n)
        default:
            logger.debug("GPU: key '\(key)' has unexpected type \(type(of: raw))")
            return nil
        }

        guard let v = value, v.isFinite else {
            logger.debug("GPU: key '\(key)' is non-finite")
            return nil
        }

        // Clamp to valid percentage range
        let clamped = min(max(v, 0), 100)
        if clamped != v {
            logger.debug("GPU: key '\(key)' value \(v) clamped to \(clamped)")
        }
        return clamped
    }

    // MARK: - WakeHandler.BaselineResettable

    func resetBaselines() {
        invalidate()
        logger.debug("GPU: baselines reset (wake)")
    }
}