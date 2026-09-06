import SwiftUI

/// Small two-value row for the network / disk / power section.
/// Left side is the metric label, right side one or two values (e.g. network
/// shows both ↑ and ↓; disk shows R and W). Values formatted with
/// monospaced digits so columns don't jump.
struct SecondaryMetricRow: View {
    let label: String
    let values: [(prefix: String, text: String)]
    var separator: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if separator {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
            }

            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                ForEach(Array(values.enumerated()), id: \.offset) { _, pair in
                    HStack(spacing: 3) {
                        if pair.prefix.isEmpty == false {
                            Text(pair.prefix)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Text(pair.text)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}