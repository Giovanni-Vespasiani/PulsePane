import Foundation

/// Immutable snapshot of one sampling cycle. `Sendable` so it can cross
/// actor boundaries without data races.
struct SystemStats: Sendable {
    let cpuUsage: Double
    let gpuUsage: Double?
    let memoryUsed: UInt64
    let memoryTotal: UInt64
    let timestamp: Date

    var gpuAvailable: Bool { gpuUsage != nil }

    var memoryUsagePercent: Double {
        guard memoryTotal > 0 else { return 0 }
        return (Double(memoryUsed) / Double(memoryTotal)) * 100
    }

    static let empty = SystemStats(
        cpuUsage: 0,
        gpuUsage: nil,
        memoryUsed: 0,
        memoryTotal: 0,
        timestamp: Date.distantPast
    )
}