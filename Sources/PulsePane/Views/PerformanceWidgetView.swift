import SwiftUI

/// v2 main widget view: a dark, Apple-widget-style glass panel.
///
/// Layout:
///   header (PulsePane + M4 badge)
///   ── CPU (histogram + %)
///   ── GPU (histogram + %)
///   ── Memory (progress bar + % / GB)
///   ── divider ──
///   Network  ↑/↓    Disk  R/W    Power    Temperature
///
/// The panel draws its own rounded background (material over a dark tint)
/// because the window is transparent and borderless. The window is forced to
/// `.darkAqua` so the material stays dark regardless of system mode.
struct PerformanceWidgetView: View {
    @StateObject private var model = PerformanceModel()
    @State private var monitor = SystemMonitor()

    private static let gbDivider = 1_073_741_824.0
    private static let cpuColor = Color(red: 0.35, green: 0.55, blue: 1.0)      // calm blue
    private static let gpuColor = Color(red: 0.55, green: 0.45, blue: 1.0)      // muted violet

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 18)

            MetricHistogramRow(
                label: "CPU",
                secondary: frequencyText,
                percent: percentText(model.stats.cpuUsage),
                history: model.cpuHistory,
                color: Self.cpuColor
            )
            .padding(.bottom, 16)

            MetricHistogramRow(
                label: "GPU",
                secondary: model.stats.gpuName ?? "—",
                percent: gpuValueText,
                history: gpuHistoryNumbers,
                color: Self.gpuColor
            )
            .padding(.bottom, 16)

            MetricProgressRow(
                label: "Memory",
                secondary: memoryDetailText,
                percent: percentText(model.stats.memoryUsagePercent),
                fraction: fractionText
            )
            .padding(.bottom, 9)

            divider
                .padding(.vertical, 10)

            SecondaryMetricRow(
                label: "Network",
                values: [
                    (prefix: "↑", text: model.stats.networkUploadBytesPerSec.map { ByteRate.string(bytesPerSec: $0) } ?? "—"),
                    (prefix: "↓", text: model.stats.networkDownloadBytesPerSec.map { ByteRate.string(bytesPerSec: $0) } ?? "—")
                ]
            )
            .padding(.vertical, 6)

            SecondaryMetricRow(
                label: "Disk",
                values: [
                    (prefix: "R", text: model.stats.diskReadBytesPerSec.map { ByteRate.string(bytesPerSec: $0) } ?? "—"),
                    (prefix: "W", text: model.stats.diskWriteBytesPerSec.map { ByteRate.string(bytesPerSec: $0) } ?? "—")
                ]
            )
            .padding(.vertical, 6)

            HStack(spacing: 6) {
                Text("Power")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Text(MetricFormatters.power(model.stats.powerWatts))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                Text("·")

                Text("Temp")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(MetricFormatters.temperature(model.stats.socTemperatureCelsius))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 6)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .frame(width: 340)
        .task { await monitor.run(model: model) }
        .background {
            panelBackground
        }
    }

    /// Rounded translucent dark panel + subtle border + soft shadow.
    private var panelBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.42))
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.regularMaterial)
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 8)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PulsePane")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(headerSubtitle)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("M4")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.1)))
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(height: 1)
    }

    private var headerSubtitle: String {
        model.stats.gpuName ?? "System Monitor"
    }

    private func percentText(_ value: Double) -> String {
        MetricFormatters.percent(MetricSanitizers.percent(value))
    }

    private var gpuValueText: String {
        guard let gpu = model.stats.gpuUsage else { return "—" }
        return MetricFormatters.percent(MetricSanitizers.percent(gpu))
    }

    private var frequencyText: String {
        guard let ghz = model.stats.cpuFrequencyGHz else { return "M4" }
        return MetricFormatters.frequency(MetricSanitizers.frequencyGHz(ghz))
    }

    private var gpuHistoryNumbers: [Double] {
        model.gpuHistory.map { $0 ?? 0 }
    }

    private var fractionText: Double? {
        model.stats.memoryTotal > 0 ? model.stats.memoryUsagePercent / 100 : nil
    }

    private var memoryDetailText: String {
        guard model.stats.memoryTotal > 0, model.stats.memoryUsed > 0 else { return "—" }
        let used = Double(model.stats.memoryUsed) / Self.gbDivider
        let total = Double(model.stats.memoryTotal) / Self.gbDivider
        return String(format: "%.1f / %.0f GB", used, total)
    }
}