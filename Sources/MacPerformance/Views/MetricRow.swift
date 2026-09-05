import SwiftUI

/// Renders a single metric: label on the left, value on the right, and a
/// thin, discrete progress bar below.
struct MetricRow: View {
    let label: String
    let value: String
    let fraction: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }

            bar
        }
    }

    @ViewBuilder
    private var bar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                if let fraction {
                    Capsule()
                        .fill(fillGradient)
                        .frame(width: max(2, geo.size.width * fraction))
                }
            }
        }
        .frame(height: 3)
        .animation(.easeOut(duration: 0.4), value: fraction)
    }

    private var fillGradient: LinearGradient {
        LinearGradient(
            colors: [.white.opacity(0.85), .white.opacity(0.45)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}