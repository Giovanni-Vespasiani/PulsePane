import Darwin

/// Computes a global CPU usage percentage using the Mach host processor
/// info API (PROCESSOR_CPU_LOAD_INFO).
///
/// The kernel returns cumulative ticks per CPU for each of the states
/// user / system / idle / nice. Usage is computed as the fraction of
/// non-idle ticks that elapsed between two consecutive samples:
///
///     usage% = (totalΔ - idleΔ) / totalΔ * 100
///
/// This class keeps the previous sample so each call returns the usage
/// *since the previous call* (not since boot). Call it at a fixed
/// interval (the monitor calls it ~1/s).
///
/// Reference: host_processor_info(3) mach man page. Public Mach API.
final class CPUReader: @unchecked Sendable {
    private var previousTotalTicks: UInt64 = 0
    private var previousIdleTicks: UInt64 = 0
    private var havePreviousSample = false

    func cpuUsage() -> Double? {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs, &cpuInfo, &numCpuInfo
        )
        guard result == KERN_SUCCESS, let info = cpuInfo else { return nil }
        defer {
            // Release the kernel-allocated buffer.
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: info)),
                vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }

        var user: UInt64 = 0
        var system: UInt64 = 0
        var idle: UInt64 = 0
        var nice: UInt64 = 0

        for cpu in 0..<Int(numCPUs) {
            let base = cpu * Int(CPU_STATE_MAX)
            user  += counter(info, base: base, state: CPU_STATE_USER)
            system += counter(info, base: base, state: CPU_STATE_SYSTEM)
            idle  += counter(info, base: base, state: CPU_STATE_IDLE)
            nice  += counter(info, base: base, state: CPU_STATE_NICE)
        }

        let total = user + system + idle + nice

        guard havePreviousSample, total >= previousTotalTicks else {
            // First sample or counter wraparound: record baseline only.
            previousTotalTicks = total
            previousIdleTicks = idle
            havePreviousSample = true
            return nil
        }

        let totalDelta = total - previousTotalTicks
        let idleDelta = idle - previousIdleTicks
        previousTotalTicks = total
        previousIdleTicks = idle

        guard totalDelta > 0 else { return 0 }

        let percent = (Double(totalDelta - idleDelta) / Double(totalDelta)) * 100
        return min(max(percent, 0), 100)
    }

    /// Reads one state tick, treating the raw Int32 bucket as unsigned
    /// (kernel counters are cumulative counts, cannot be negative).
    private func counter(_ info: processor_info_array_t, base: Int, state: Int32) -> UInt64 {
        UInt64(info[base + Int(state)])
    }
}