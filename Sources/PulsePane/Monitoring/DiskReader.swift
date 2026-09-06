import Foundation
import IOKit
import os

/// Reads cumulative disk byte counters from the kernel's block-storage driver
/// layer via IOKit (`IOBlockStorageDriver` → `Statistics`), native and
/// subprocess-free, and computes read/write rate from the delta between two
/// samples (≈1 s apart).
///
/// # Disk Selection Policy
/// We only accept the **physical driver-level** `Statistics` dictionary,
/// identified by the presence of the aggregate `Total Time (Write)` key.
/// This avoids double-counting from APFS/volume overlay layers that also
/// expose byte stats for the same physical drive.
///
/// # Counter Handling
/// - Uses `DeltaCounter` for safe delta computation
/// - Counter reset/rollover → returns nil, baseline reset
/// - First sample → returns nil, establishes baseline
/// - Negative delta (counter regression) → treated as reset
///
/// # Service Handling
/// - Iterates all `IOBlockStorageDriver` services
/// - Sums bytes from all physical drives (internal + external)
/// - Service disappearance handled gracefully (nil returned, baseline reset)
///
/// # Error Handling
/// - No matching service → unavailable
/// - Statistics dict missing → service skipped
/// - Marker key missing (APFS overlay) → service skipped
/// - Missing read/write keys → service skipped
/// - Malformed CFNumber → service skipped
/// - Counter reset → returns nil, baseline cleared
final class DiskReader: @unchecked Sendable, WakeHandler.BaselineResettable {

    // MARK: - Configuration

    private struct Sample {
        let bytesRead: UInt64
        let bytesWritten: UInt64
        let date: Date
    }

    // Keys that identify the physical IOBlockStorageDriver-level Statistics
    // (as opposed to APFS/volume overlay counters).
    private static let markerKey = "Total Time (Write)"
    private static let readKey = "Bytes (Read)"
    private static let writeKey = "Bytes (Write)"

    // MARK: - State

    private let logger = Logger(subsystem: "com.github.Giovanni-Vespasiani.PulsePane", category: "disk")
    private var previous: Sample?
    private let readCounter = DeltaCounter()
    private let writeCounter = DeltaCounter()

    // MARK: - Public API

    func read() -> (readPerSec: Double?, writePerSec: Double?) {
        let match = IOServiceMatching("IOBlockStorageDriver")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == KERN_SUCCESS else {
            logger.debug("Disk: IOServiceGetMatchingServices failed")
            readCounter.reset()
            writeCounter.reset()
            return (nil, nil)
        }
        defer { IOObjectRelease(iterator) }

        var bytesRead: UInt64 = 0
        var bytesWritten: UInt64 = 0
        var serviceCount = 0

        var service: io_object_t = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }
            if let stats = statistics(of: service) {
                bytesRead += stats.0
                bytesWritten += stats.1
                serviceCount += 1
            }
            service = IOIteratorNext(iterator)
        }

        logger.debug("Disk: sampled \(serviceCount) physical drives, read=\(bytesRead) written=\(bytesWritten)")

        let now = Date()
        let interval = previous.map { now.timeIntervalSince($0.date) } ?? 0

        // Use safe delta counters
        let read = readCounter.sample(newValue: bytesRead, interval: interval)
        let write = writeCounter.sample(newValue: bytesWritten, interval: interval)

        // Check for counter resets
        let readReset = bytesRead < (previous?.bytesRead ?? 0)
        let writeReset = bytesWritten < (previous?.bytesWritten ?? 0)
        if readReset || writeReset {
            logger.debug("Disk: counter reset detected, resetting baselines")
            readCounter.reset()
            writeCounter.reset()
        }

        previous = Sample(bytesRead: bytesRead, bytesWritten: bytesWritten, date: now)
        return (read, write)
    }

    // MARK: - Private

    private func statistics(of service: io_registry_entry_t) -> (UInt64, UInt64)? {
        guard let cf = IORegistryEntryCreateCFProperty(
            service,
            "Statistics" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        // Only accept physical driver-level Statistics (has aggregate timing keys)
        guard cf[Self.markerKey] != nil,
              let read = uint64(from: cf[Self.readKey]),
              let written = uint64(from: cf[Self.writeKey]) else {
            return nil
        }
        return (read, written)
    }

    private func uint64(from value: Any?) -> UInt64? {
        switch value {
        case let n as NSNumber:
            return n.uint64Value
        case let n as CFNumber:
            var out: UInt64 = 0
            guard CFNumberGetValue(n, .sInt64Type, &out) else { return nil }
            return out
        default:
            return nil
        }
    // MARK: - WakeHandler.BaselineResettable

    func resetBaselines() {
        previous = nil
        readCounter.reset()
        writeCounter.reset()
        logger.debug("Disk: baselines reset (wake)")
    }
}