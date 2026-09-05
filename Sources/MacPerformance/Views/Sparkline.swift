import SwiftUI

/// Extremely discreet sparkline: a single thin line, no axes, no grid.
/// Values are percentages (0–100). `nil` entries create a visible gap.
struct Sparkline: View {
    let values: [Double?]

    var body: some View {
        GeometryReader { geo in
            Path { path in
                draw(in: geo.size, into: &path)
            }
            .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
        }
        .frame(height: 14)
    }

    private func draw(in size: CGSize, into path: inout Path) {
        guard values.count > 1, size.width > 0 else { return }

        let stepX = size.width / CGFloat(values.count - 1)
        var started = false

        for (index, value) in values.enumerated() {
            guard let value else {
                started = false
                continue
            }
            let clamped = min(max(value, 0), 100)
            let point = CGPoint(
                x: CGFloat(index) * stepX,
                y: size.height - (CGFloat(clamped) / 100) * size.height
            )
            if started {
                path.addLine(to: point)
            } else {
                path.move(to: point)
                started = true
            }
        }
    }
}