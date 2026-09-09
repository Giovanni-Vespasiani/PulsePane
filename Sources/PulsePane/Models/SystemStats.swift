import Foundation
import CoreWLAN

/// Immutable snapshot of one sampling cycle. `Sendable` so it can cross
/// actor boundaries without data races.
///
/// Metric availability rule (see DECISIONS D-002): if a metric cannot be read,
/// the field is `nil` — never `0`. 0 is "idle/actual zero", nil is "unavailable".
struct SystemStats: Sendable {
    // Primary metrics (v1)
    let cpuUsage: Double
    let gpuUsage: Double?

    // Memory (v1)
    let memoryUsed: UInt64
    let memoryTotal: UInt64

    // v2 metrics — all optional, nil means "unavailable right now".
    let cpuFrequencyGHz: Double?
    let gpuName: String?
    let networkUploadBytesPerSec: Double?
    let networkDownloadBytesPerSec: Double?
    let networkQuality: NetworkQualityReader.Snapshot?
    let diskReadBytesPerSec: Double?
    let diskWriteBytesPerSec: Double?
    let powerWatts: Double?
    let socTemperatureCelsius: Double?

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
        cpuFrequencyGHz: nil,
        gpuName: nil,
        networkUploadBytesPerSec: nil,
        networkDownloadBytesPerSec: nil,
        networkQuality: nil,
        diskReadBytesPerSec: nil,
        diskWriteBytesPerSec: nil,
        powerWatts: nil,
        socTemperatureCelsius: nil,
        timestamp: Date.distantPast
    )
}