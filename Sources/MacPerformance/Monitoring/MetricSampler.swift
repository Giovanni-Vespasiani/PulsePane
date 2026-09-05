import Foundation

/// Owns the three sub-system readers and produces a `SystemStats` snapshot.
///
/// Threading: this object runs exclusively on the sampling queue/task, never
/// on the main thread. It is `@unchecked Sendable` because all its mutable
/// state (CPUReader's previous-tick baseline) is confined to that single
/// sampling context.
final class MetricSampler: @unchecked Sendable {
    private let cpu = CPUReader()
    private let memory = MemoryReader()
    private let gpu = GPUReader()

    func sample() -> SystemStats {
        let cpuUsage = cpu.cpuUsage() ?? 0
        let gpuUsage = gpu.gpuUsage()
        let memorySnapshot = memory.read()

        return SystemStats(
            cpuUsage: cpuUsage,
            gpuUsage: gpuUsage,
            memoryUsed: memorySnapshot?.used ?? 0,
            memoryTotal: memorySnapshot?.total ?? 0,
            timestamp: Date()
        )
    }
}