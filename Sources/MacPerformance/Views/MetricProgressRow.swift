import SwiftUI

/// Memory row: label + "X / Y GB" secondary, percentage right-aligned,
/// thin progress bar underneath spanning the full row width.
struct MetricProgressRow: View {
    let label: String
    let secondary: String
    let percent: String
    let fraction: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(secondary)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(percent)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(minWidth: 48, alignment: .trailing)
            }

            progressBar
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                if let fraction {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(fillGradient)
                        .frame(width: max(2, geo.size.width * fraction))
                        .animation(.easeOut(duration: 0.4), value: fraction)
                }
            }
        }
        .frame(height: 3)
    }

    private var fillGradient: LinearGradient {
        LinearGradient(
            colors: [.white.opacity(0.85), .white.opacity(0.45)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}