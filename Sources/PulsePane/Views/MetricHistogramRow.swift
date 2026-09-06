import SwiftUI

/// CPU / GPU row: label + secondary line on the left, histogram in the
/// centre-right, percentage right-aligned at a fixed-width trailing column
/// (ensuring visual alignment across CPU / GPU rows).
struct MetricHistogramRow: View {
    let label: String
    let secondary: String
    let percent: String
    let history: [Double]
    let color: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(secondary)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            MiniHistogram(values: history, color: color)

            Spacer(minLength: 4)

            Text(percent)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(minWidth: 48, alignment: .trailing)
        }
    }
}