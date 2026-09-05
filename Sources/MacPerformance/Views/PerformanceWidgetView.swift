import SwiftUI

/// Main widget view. Shows CPU / GPU / Memory with a dark, macOS-like layout.
struct PerformanceWidgetView: View {
    @StateObject private var model = PerformanceModel()
    @State private var monitor = SystemMonitor()

    private static let gbDivider = 1_073_741_824.0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            rows
        }
        .padding(18)
        .frame(width: 320)
        .task { await monitor.run(model: model) }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("PERFORMANCE")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .kerning(1.5)
                .foregroundStyle(.secondary)
            Spacer()
            Text("M4")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }

    private var rows: some View {
        VStack(spacing: 12) {
            MetricRow(
                label: "CPU",
                value: String(format: "%.0f%%", model.stats.cpuUsage),
                fraction: model.stats.cpuUsage / 100
            )

            MetricRow(
                label: "GPU",
                value: gpuValueText,
                fraction: model.stats.gpuUsage.map { $0 / 100 }
            )

            MetricRow(
                label: "MEMORY",
                value: memoryValueText,
                fraction: model.stats.memoryTotal > 0
                    ? model.stats.memoryUsagePercent / 100
                    : nil
            )

            HStack(spacing: 2) {
                Text(memoryDetailText)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
    }

    private var gpuValueText: String {
        guard let gpu = model.stats.gpuUsage else { return "—" }
        return String(format: "%.0f%%", gpu)
    }

    private var memoryValueText: String {
        guard model.stats.memoryTotal > 0 else { return "—" }
        return String(format: "%.0f%%", model.stats.memoryUsagePercent)
    }

    private var memoryDetailText: String {
        guard model.stats.memoryTotal > 0, model.stats.memoryUsed > 0 else { return "" }
        let used = Double(model.stats.memoryUsed) / Self.gbDivider
        let total = Double(model.stats.memoryTotal) / Self.gbDivider
        return String(format: "%.1f / %.0f GB", used, total)
    }
}