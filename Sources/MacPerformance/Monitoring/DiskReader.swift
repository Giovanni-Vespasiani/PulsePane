import Foundation
import IOKit

/// Reads cumulative disk byte counters from the kernel's block-storage driver
/// layer via IOKit (`IOBlockStorageDriver` → `Statistics`), native and
/// subprocess-free, and computes read/write rate from the delta between two
/// samples (≈1 s apart).
///
/// The `Statistics` dictionary that we accept is the *physical* driver-level
/// one (identified by the presence of the aggregate `Total Time (Write)` key);
/// higher, overlay layers (APFS, volumes) also expose byte stats and would
/// double-count the same physical drive, so we ignore them.
final class DiskReader: @unchecked Sendable {

    private struct Sample {
        let bytesRead: UInt64
        let bytesWritten: UInt64
        let date: Date
    }

    private var previous: Sample?

    /// Keys that identify the physical IOBlockStorageDriver-level Statistics
    /// (as opposed to APFS/volume overlay counters).
    private static let markerKey = "Total Time (Write)"
    private static let readKey = "Bytes (Read)"
    private static let writeKey = "Bytes (Write)"

    func read() -> (readPerSec: Double?, writePerSec: Double?) {
        let match = IOServiceMatching("IOBlockStorageDriver")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == KERN_SUCCESS else {
            return (nil, nil)
        }
        defer { IOObjectRelease(iterator) }

        var bytesRead: UInt64 = 0
        var bytesWritten: UInt64 = 0

        var service: io_object_t = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }
            if let stats = statistics(of: service) {
                bytesRead += stats.0
                bytesWritten += stats.1
            }
            service = IOIteratorNext(iterator)
        }

        let now = Date()
        defer { previous = Sample(bytesRead: bytesRead, bytesWritten: bytesWritten, date: now) }

        guard let previous, now > previous.date else { return (nil, nil) }
        let elapsed = now.timeIntervalSince(previous.date)
        guard elapsed > 0 else { return (nil, nil) }

        let read = Self.rate(new: bytesRead, old: previous.bytesRead, elapsed: elapsed)
        let write = Self.rate(new: bytesWritten, old: previous.bytesWritten, elapsed: elapsed)
        return (read, write)
    }

    private func statistics(of service: io_registry_entry_t) -> (UInt64, UInt64)? {
        guard let cf = IORegistryEntryCreateCFProperty(
            service,
            "Statistics" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
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
    }

    private static func rate(new: UInt64, old: UInt64, elapsed: TimeInterval) -> Double? {
        guard new >= old else { return nil } // counter reset / wrap
        return Double(new - old) / elapsed
    }
}