import SwiftUI

/// Temporary view used for the first compilable build (Milestone A).
/// Replaced by PerformanceWidgetView as features land.
struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "gauge.with.needle")
                .font(.system(size: 40, weight: .light))
            Text("MacPerformance")
                .font(.title2.weight(.semibold))
            Text("v0.1 scaffolding")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}