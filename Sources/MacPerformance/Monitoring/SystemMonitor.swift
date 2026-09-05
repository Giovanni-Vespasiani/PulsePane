import Foundation

/// Coordinator that drives the sampling loop.
///
/// Data flow:
///     MetricSampler (background) → SystemStats (Sendable) → MainActor → model.stats
///
/// The sampling task runs detached on a utility executor so Mach/IOKit reads
/// never block SwiftUI.
final class SystemMonitor: @unchecked Sendable {
    private let sampler = MetricSampler()

    /// Runs until cancelled. Samples immediately, then every `interval`.
    func run(model: PerformanceModel, interval: Duration = .seconds(1)) async {
        while !Task.isCancelled {
            let snapshot = await Task.detached(priority: .utility) { [sampler] in
                sampler.sample()
            }.value

            await MainActor.run {
                model.update(snapshot)
                let debug = ProcessInfo.processInfo.environment["MP_DEBUG"]
                if debug != nil {
                    let memPct = snapshot.memoryTotal > 0
                        ? String(format: "%.0f%%", snapshot.memoryUsagePercent)
                        : "—"
                    let net = [
                        snapshot.networkUploadBytesPerSec.map { "↑\(ByteRate.string(bytesPerSec: $0))" },
                        snapshot.networkDownloadBytesPerSec.map { "↓\(ByteRate.string(bytesPerSec: $0))" }
                    ].compactMap { $0 }.joined(separator: "  ")
                    let disk = [
                        snapshot.diskReadBytesPerSec.map { "R\(ByteRate.string(bytesPerSec: $0))" },
                        snapshot.diskWriteBytesPerSec.map { "W\(ByteRate.string(bytesPerSec: $0))" }
                    ].compactMap { $0 }.joined(separator: "  ")
                    print(
                        "CPU \(String(format: "%.1f", snapshot.cpuUsage))%  " +
                        "GPU \(snapshot.gpuUsage.map { String(format: "%.1f%%", $0) } ?? "—")  " +
                        "MEM \(String(format: "%.1f", Double(snapshot.memoryUsed) / 1_073_741_824))/\(String(format: "%.1f", Double(snapshot.memoryTotal) / 1_073_741_824)) GB \(memPct)" +
                        (net.isEmpty ? "" : "  NET \(net)") +
                        (disk.isEmpty ? "" : "  DISK \(disk)") +
                        (snapshot.powerWatts.map { "  PWR \(ByteRate.watts($0))" } ?? "  PWR —") +
                        (snapshot.socTemperatureCelsius.map { "  TMP \(ByteRate.temperature($0))" } ?? "  TMP —")
                    )
                }
            }

            try? await Task.sleep(for: interval)
        }
    }
}