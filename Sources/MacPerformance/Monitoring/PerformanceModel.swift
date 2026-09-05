import Foundation
import Combine

/// Observable model consumed by SwiftUI.
///
/// Threading: `stats` is only mutated from the main thread (via
/// `MainActor.run` in SystemMonitor). Declared `@unchecked Sendable`
/// so it can be handed to the background sampling task; correctness is
/// guaranteed by the main-thread-only mutation convention.
final class PerformanceModel: ObservableObject, @unchecked Sendable {
    /// v2 histograms show 22 bars (~22 s of history at 1 Hz).
    static let historySize = 22

    @Published private(set) var stats: SystemStats = .empty
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var gpuHistory: [Double?] = []

    /// Called from the main thread only (see SystemMonitor.run).
    func update(_ snapshot: SystemStats) {
        stats = snapshot
        cpuHistory.append(snapshot.cpuUsage)
        if cpuHistory.count > Self.historySize {
            cpuHistory.removeFirst(cpuHistory.count - Self.historySize)
        }
        gpuHistory.append(snapshot.gpuUsage)
        if gpuHistory.count > Self.historySize {
            gpuHistory.removeFirst(gpuHistory.count - Self.historySize)
        }
    }
}