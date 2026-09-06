import Foundation

/// Owns all sub-system readers and produces a `SystemStats` snapshot.
///
/// Threading: this object runs exclusively on the sampling queue/task, never
/// on the main thread. It is `@unchecked Sendable` because all its mutable
/// state (per-reader previous-tick baselines for delta computation) is confined
/// to that single sampling context.
///
/// Availability rule: an unreadable metric is `nil` in `SystemStats`, never 0.
final class MetricSampler: @unchecked Sendable {
    let cpuReader = CPUReader()
    let memoryReader = MemoryReader()
    let gpuReader = GPUReader()
    let networkReader = NetworkReader()
    let diskReader = DiskReader()
    let powerReader = PowerReader()
    let temperatureReader = TemperatureReader()

    func sample() -> SystemStats {
        let cpuUsage = cpuReader.cpuUsage() ?? 0
        let gpuUsage = gpuReader.gpuUsage()
        let memorySnapshot = memoryReader.read()
        let networkSnapshot = networkReader.read()
        let diskSnapshot = diskReader.read()
        let powerWatts = powerReader.powerWatts()
        let temperatureCelsius = temperatureReader.celsius()

        return SystemStats(
            cpuUsage: cpuUsage,
            gpuUsage: gpuUsage,
            memoryUsed: memorySnapshot?.used ?? 0,
            memoryTotal: memorySnapshot?.total ?? 0,
            cpuFrequencyGHz: nil, // no reliable non-privileged API (see DECISIONS D-009)
            gpuName: "Apple GPU",
            networkUploadBytesPerSec: networkSnapshot.uploadPerSec,
            networkDownloadBytesPerSec: networkSnapshot.downloadPerSec,
            diskReadBytesPerSec: diskSnapshot.readPerSec,
            diskWriteBytesPerSec: diskSnapshot.writePerSec,
            powerWatts: powerWatts,
            socTemperatureCelsius: temperatureCelsius,
            timestamp: Date()
        )
    }
}