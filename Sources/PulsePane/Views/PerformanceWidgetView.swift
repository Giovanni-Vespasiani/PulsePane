import SwiftUI
import CoreWLAN

/// v2.4 main widget view: a native macOS desktop panel with semantic theming.
///
/// Layout:
///   header (PulsePane + M4 badge)
///   ── CPU (ring + %)
///   ── GPU (ring + %)
///   ── Memory (ring + %)
///   ── divider ──
///   Network  ↑/↓
///   ── footer (system info)
///
/// The panel uses semantic materials that adapt to Light/Dark mode automatically.
struct PerformanceWidgetView: View {
    @StateObject private var model = PerformanceModel()
    @State private var monitor = SystemMonitor()

    private static let gbDivider = 1_073_741_824.0

    // Semantic accent colors (work in both Light/Dark mode)
    private static let cpuAccent = Color.accentColor // system blue
    private static let gpuAccent = Color.purple
    private static let memoryAccent = Color.green
    private static let networkAccent = Color.blue

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 16)

            // Primary metrics: CPU, GPU, Memory rings
MetricRingRow(
            label: "CPU",
            secondary: frequencyText,
            percent: model.stats.cpuUsage,
            accent: Self.cpuAccent
        )
        .padding(.bottom, 14)

        MetricRingRow(
            label: "GPU",
            secondary: model.stats.gpuName ?? "—",
            percent: model.stats.gpuUsage ?? 0,
            accent: Self.gpuAccent
        )
        .padding(.bottom, 14)

            MetricRingRow(
                label: "Memory",
                secondary: memoryDetailText,
                percent: model.stats.memoryUsagePercent,
                accent: Self.memoryAccent
            )
            .padding(.bottom, 8)

            divider
                .padding(.vertical, 8)

            // Secondary metric: Network
            NetworkMetricRow(
                upload: model.displayUpload,
                download: model.displayDownload,
                quality: model.stats.networkQuality
            )
            .padding(.vertical, 6)

            // Footer
            footer
                .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(width: 340)
        .task { await monitor.run(model: model) }
        .background {
            panelBackground
        }
    }

    /// Panel background using semantic materials that adapt to Light/Dark mode.
    private var panelBackground: some View {
        ZStack {
            // Base tint - subtle dark in Dark mode, subtle light in Light mode
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.primary.opacity(0.06))
            // Native material for vibrancy
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.regularMaterial)
            // Subtle border
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.15), radius: 14, x: 0, y: 4)
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
            // SoC badge
            Text("M4")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.primary.opacity(0.1)))
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
    }

    private var headerSubtitle: String {
        model.stats.gpuName ?? "System Monitor"
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Spacer()
            // Version/build info
            Text("PulsePane v2.4")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
    }

    // MARK: - Formatted values

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

    private var memoryDetailText: String {
        guard model.stats.memoryTotal > 0, model.stats.memoryUsed > 0 else { return "—" }
        let used = Double(model.stats.memoryUsed) / Self.gbDivider
        let total = Double(model.stats.memoryTotal) / Self.gbDivider
        return String(format: "%.1f / %.0f GB", used, total)
    }
}

/// Circular metric ring row with label, secondary text, percentage, and ring.
private struct MetricRingRow: View {
    let label: String
    let secondary: String
    let percent: Double
    let accent: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Label + secondary
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(secondary)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            // Percentage + Ring
            HStack(alignment: .center, spacing: 10) {
                Text(MetricFormatters.percent(MetricSanitizers.percent(percent)))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(minWidth: 44, alignment: .trailing)

                CircularProgressRing(progress: percent / 100, accent: accent)
                    .frame(width: 48, height: 48)
            }
        }
    }
}

/// Circular progress ring with semantic accent color.
private struct CircularProgressRing: View {
    let progress: Double // 0.0 to 1.0
    let accent: Color
    let lineWidth: CGFloat = 4
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(accent.opacity(0.15), lineWidth: lineWidth)

            // Progress
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    accent,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: progress)
        }
        .frame(width: 48, height: 48)
    }
}

/// Network metric row showing upload/download with semantic colors.
private struct NetworkMetricRow: View {
    let upload: Double?
    let download: Double?
    let quality: NetworkQualityReader.Snapshot?

    var body: some View {
        HStack(spacing: 12) {
            Text("Network")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: 64, alignment: .leading)

            Spacer(minLength: 12)

            // Upload
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.blue)
                Text(MetricFormatters.byteRate(upload))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            // Download
            HStack(spacing: 4) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
                Text(MetricFormatters.byteRate(download))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            // Quality
            if let quality = quality {
                Text(quality.quality.rawValue.capitalized)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.1)))
            }
        }
    }
}