import SwiftUI

/// Main widget view. Dark, macOS-widget-style panel showing
/// CPU / GPU / Memory with thin bars.
///
/// The panel draws its own rounded background (material over a dark tint)
/// because the window itself is transparent and borderless. The window is
/// forced to `.darkAqua` so the material stays dark regardless of system mode.
struct PerformanceWidgetView: View {
    @StateObject private var model = PerformanceModel()
    @State private var monitor = SystemMonitor()

    private static let gbDivider = 1_073_741_824.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            rows
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(width: 320)
        .background(panelBackground, alignment: .top)
        .task { await monitor.run(model: model) }
    }

    /// Rounded translucent dark panel + subtle border + soft shadow.
    private var panelBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.black.opacity(0.42))
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.regularMaterial)
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 8)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("PERFORMANCE")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .kerning(1.8)
                .foregroundStyle(.secondary)
            Spacer()
            Text("M4")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }

    private var rows: some View {
        VStack(spacing: 13) {
            MetricRow(
                label: "CPU",
                value: String(format: "%.0f%%", model.stats.cpuUsage),
                fraction: model.stats.cpuUsage / 100,
                spark: model.cpuHistory
            )

            MetricRow(
                label: "GPU",
                value: gpuValueText,
                fraction: model.stats.gpuUsage.map { $0 / 100 },
                spark: model.gpuHistory
            )

            MetricRow(
                label: "MEMORY",
                value: memoryValueText,
                fraction: model.stats.memoryTotal > 0
                    ? model.stats.memoryUsagePercent / 100
                    : nil
            )

            HStack {
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