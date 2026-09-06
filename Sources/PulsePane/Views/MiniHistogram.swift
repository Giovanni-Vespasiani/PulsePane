import SwiftUI

/// v2 bar chart: a row of 22 thin vertical bars filling bottom-to-top.
/// Percentage values 0–100 drive bar height. Bars align to a fixed height
/// defined by the caller so that CPU / GPU histograms are the same visual
/// height and therefore percent values are directly comparable across rows.
struct MiniHistogram: View {
    let values: [Double]
    let color: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(color)
                    .frame(width: 3, height: max(2, clampedFraction(value) * maxHeight))
            }
        }
        .frame(height: maxHeight)
        .animation(.easeInOut(duration: 0.3), value: values)
    }

    /// Fixed visual height so caller controls it and all histograms match.
    private let maxHeight: CGFloat = 24

    private func clampedFraction(_ value: Double) -> CGFloat {
        min(max(value, 0), 100) / 100.0
    }
}