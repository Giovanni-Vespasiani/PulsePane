import Foundation
import Combine

/// Observable model consumed by SwiftUI.
///
/// Threading: `stats` is only mutated from the main thread (via
/// `MainActor.run` in SystemMonitor). Declared `@unchecked Sendable`
/// so it can be handed to the background sampling task; correctness is
/// guaranteed by the main-thread-only mutation convention.
final class PerformanceModel: ObservableObject, @unchecked Sendable {
    /// Rolling history for mini sparklines (last ~30 samples). GPU history keeps
    /// `nil` entries when the GPU was unreadable, so the line visibly gaps.
    static let historySize = 30

    @Published private(set) var stats: SystemStats = .empty
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var gpuHistory: [Double?] = []

    /// Called from the main thread only (see SystemMonitor.run).
    func update(_ snapshot: SystemStats) {
        stats = snapshot
        cpuHistory.append(snapshot.cpuUsage)
        if cpuHistory.count > Self.historySize { cpuHistory.removeFirst(cpuHistory.count - Self.historySize) }
        gpuHistory.append(snapshot.gpuUsage)
        if gpuHistory.count > Self.historySize { gpuHistory.removeFirst(gpuHistory.count - Self.historySize) }
    }
}