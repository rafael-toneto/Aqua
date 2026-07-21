import SwiftUI

struct HydrationHistoryRing: View {
    let progress: DailyHydrationProgress
    var lineWidth: CGFloat = 18
    var showsLabel = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var normalizedProgress: Double {
        min(max(progress.completionPercentage / 100, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.12), lineWidth: lineWidth)

            if normalizedProgress > 0 {
                Circle()
                    .trim(from: 0, to: normalizedProgress)
                    .stroke(
                        AngularGradient(
                            colors: [.cyan, .blue, .indigo, .cyan],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .smooth(duration: 0.55), value: normalizedProgress)
            }

            if showsLabel {
                VStack(spacing: AquaSpacing.extraSmall) {
                    Image(systemName: progress.hasReachedGoal ? "checkmark" : "drop.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(progress.hasReachedGoal ? .green : .blue)

                    Text("\(Int(progress.completionPercentage.rounded()))%")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .contentTransition(.numericText())

                    Text("of daily goal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hydration progress")
        .accessibilityValue("\(Int(progress.completionPercentage.rounded())) percent of daily goal")
    }
}
