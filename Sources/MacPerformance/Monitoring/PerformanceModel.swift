import Foundation
import Combine

/// Observable model consumed by SwiftUI.
///
/// Threading: `stats` is only mutated from the main thread (via
/// `MainActor.run` in SystemMonitor). Declared `@unchecked Sendable`
/// so it can be handed to the background sampling task; correctness is
/// guaranteed by the main-thread-only mutation convention.
final class PerformanceModel: ObservableObject, @unchecked Sendable {
    @Published private(set) var stats: SystemStats = .empty

    /// Called from the main thread only (see SystemMonitor.run).
    func update(_ snapshot: SystemStats) {
        stats = snapshot
    }
}