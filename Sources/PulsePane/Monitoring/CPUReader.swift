import Darwin
import os

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
/// # Error Handling
/// - First sample / counter reset → returns nil, establishes new baseline
/// - Zero elapsed time / zero total delta → returns nil
/// - Mach API failure → unavailable
/// - Result clamped to [0, 100]
///
/// Reference: host_processor_info(3) mach man page. Public Mach API.
final class CPUReader: @unchecked Sendable, WakeHandler.BaselineResettable {
    private var previousTotalTicks: UInt64 = 0
    private var previousIdleTicks: UInt64 = 0
    private var havePreviousSample = false

    private let logger = Logger(subsystem: "com.github.Giovanni-Vespasiani.PulsePane", category: "cpu")

    func cpuUsage() -> Double? {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs, &cpuInfo, &numCpuInfo
        )
        guard result == KERN_SUCCESS, let info = cpuInfo else {
            logger.debug("CPU: host_processor_info failed (result=\(result))")
            return nil
        }
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

        // Handle first sample or counter reset/wraparound
        guard havePreviousSample, total >= previousTotalTicks else {
            previousTotalTicks = total
            previousIdleTicks = idle
            havePreviousSample = true
            logger.debug("CPU: first sample or counter reset, baseline established")
            return nil
        }

        let totalDelta = total - previousTotalTicks
        let idleDelta = idle - previousIdleTicks
        previousTotalTicks = total
        previousIdleTicks = idle

        guard totalDelta > 0 else {
            logger.debug("CPU: zero total delta")
            return nil
        }

        let percent = (Double(totalDelta - idleDelta) / Double(totalDelta)) * 100
        let clamped = min(max(percent, 0), 100)

        if clamped != percent {
            logger.debug("CPU: value \(percent)% clamped to \(clamped)%")
        }

        return clamped
    }

    /// Reads one state tick, treating the raw Int32 bucket as unsigned
    /// (kernel counters are cumulative counts, cannot be negative).
    private func counter(_ info: processor_info_array_t, base: Int, state: Int32) -> UInt64 {
        UInt64(info[base + Int(state)])
    // MARK: - BaselineResettable

    func resetBaselines() {
        previousTotalTicks = 0
        previousIdleTicks = 0
        havePreviousSample = false
        logger.debug("CPU: baselines reset (wake)")
    }
}