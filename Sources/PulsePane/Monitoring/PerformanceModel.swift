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

    // Network display hold: keep last valid value for up to 2 cycles after invalid sample
    private var lastValidUpload: Double? = nil
    private var lastValidDownload: Double? = nil
    private var uploadNilCount: Int = 0
    private var downloadNilCount: Int = 0
    private let maxHoldCycles = 2

    @Published private(set) var stats: SystemStats = .empty
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var gpuHistory: [Double?] = []

    /// Display upload/download that hold last valid value briefly during invalid samples.
    var displayUpload: Double? {
        if let upload = stats.networkUploadBytesPerSec {
            return upload
        } else if uploadNilCount > 0 && uploadNilCount <= maxHoldCycles {
            return lastValidUpload
        } else {
            return nil
        }
    }

    var displayDownload: Double? {
        if let download = stats.networkDownloadBytesPerSec {
            return download
        } else if downloadNilCount > 0 && downloadNilCount <= maxHoldCycles {
            return lastValidDownload
        } else {
            return nil
        }
    }

    /// Called from the main thread only (see SystemMonitor.run).
    func update(_ snapshot: SystemStats) {
        // Update hold logic for network upload
        if let upload = snapshot.networkUploadBytesPerSec {
            lastValidUpload = upload
            uploadNilCount = 0
        } else {
            uploadNilCount += 1
        }

        // Update hold logic for network download
        if let download = snapshot.networkDownloadBytesPerSec {
            lastValidDownload = download
            downloadNilCount = 0
        } else {
            downloadNilCount += 1
        }

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