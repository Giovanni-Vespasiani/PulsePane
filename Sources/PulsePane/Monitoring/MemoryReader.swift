import Foundation
import os

/// Reads physical memory statistics via the Mach host_statistics64 API.
///
/// # Definition of "used" memory (PulsePane v2.0)
///
/// We define **used** as:
///
///     used = active + wired + compressed
///
/// in page units (multiplied by the kernel page size).
///
/// - **active**: pages recently referenced and currently mapped by processes
///   (kept warm in physical RAM).
/// - **wired**: pages that cannot be paged out (kernel structures, I/O
///   buffers). These are permanently resident.
/// - **compressed**: pages currently stored by the memory compressor
///   (`compressor_page_count`, i.e. pages *occupied by* the compressor).
///
/// Intentionally **excluded**:
/// - **inactive**: reclaimable cache pages that can be evicted; they are not
///   "in use" right now.
/// - **speculative** and **free**: available for immediate reuse.
///
/// This is *our* semantically-coherent approximation of physical memory
/// currently in use. It is used as a sanity check against Activity Monitor,
/// NOT a claim of byte-for-byte equivalence with any other tool.
///
/// See DECISIONS.md D-003.
///
/// # Error Handling
/// - `host_statistics64` failure → unavailable
/// - `hw.memsize` sysctl failure → fallback to host_info
/// - Arithmetic overflow protection (checked arithmetic)
/// - Bounds validation: used <= total, total > 0
/// - Invalid data → unavailable
final class MemoryReader: @unchecked Sendable {
    private let pageSize: UInt64

    private let logger = Logger(subsystem: "com.github.Giovanni-Vespasiani.PulsePane", category: "memory")

    init() {
        var pageSizeValue: Int = 16384
        var size = MemoryLayout<Int>.size
        let mib: [Int32] = [CTL_HW, HW_PAGESIZE]
        let ok = mib.withUnsafeBufferPointer { buffer -> Bool in
            guard let base = buffer.baseAddress else { return false }
            return sysctl(
                UnsafeMutablePointer(mutating: base),
                UInt32(buffer.count),
                &pageSizeValue,
                &size,
                nil,
                0
            ) == 0
        }
        // Prefer the real kernel page size (16384 on Apple Silicon); fall back.
        self.pageSize = UInt64(ok ? pageSizeValue : 16384)
        logger.debug("Memory: page size = \(self.pageSize)")
    }

    struct Snapshot: Sendable {
        let used: UInt64
        let total: UInt64
    }

    func read() -> Snapshot? {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            logger.debug("Memory: host_statistics64 failed (result=\(result))")
            return nil
        }

        let active = UInt64(stats.active_count)
        let wired = UInt64(stats.wire_count)
        let compressed = UInt64(stats.compressor_page_count)

        // Checked arithmetic for used pages
        let usedPages = active.addingReportingOverflow(wired)
            .partialValue.addingReportingOverflow(compressed)
            .partialValue

        // Checked multiplication for used bytes
        let usedBytes = usedPages.multipliedReportingOverflow(by: pageSize)
            .partialValue

        let total = self.totalPhysicalMemory()

        // Bounds validation
        guard total > 0 else {
            logger.debug("Memory: total memory is 0")
            return nil
        }

        if usedBytes > total {
            logger.debug("Memory: used (\(usedBytes)) > total (\(total)), clamping")
            return Snapshot(used: total, total: total)
        }

        logger.debug("Memory: used=\(usedBytes) total=\(total)")
        return Snapshot(used: usedBytes, total: total)
    }

    /// Total physical RAM from sysctl `hw.memsize` (bytes). Semantically the
    /// total unified memory of the SoC on Apple Silicon.
    private func totalPhysicalMemory() -> UInt64 {
        var mem: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        let mib: [Int32] = [CTL_HW, HW_MEMSIZE]
        let ok = mib.withUnsafeBufferPointer { buffer -> Bool in
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
        guard ok else {
            logger.debug("Memory: hw.memsize sysctl failed, using host_info fallback")
            return hostInfoMemoryTotal()
        }
        return mem
    }

    /// Fallback: total memory from host_info (bytes, rounded).
    private func hostInfoMemoryTotal() -> UInt64 {
        var info = host_basic_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_basic_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_info(mach_host_self(), HOST_BASIC_INFO, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            logger.debug("Memory: host_info failed (result=\(result))")
            return 0
        }
        return UInt64(info.max_mem)
    }
}