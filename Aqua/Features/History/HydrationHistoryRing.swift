import SwiftUI

struct HydrationHistoryRing: View {
    let progress: DailyHydrationProgress
    var lineWidth: CGFloat = 18
    var showsLabel = false
    var isHighlighted = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var normalizedProgress: Double {
        min(max(progress.completionPercentage / 100, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    isHighlighted ? palette.accent.opacity(0.22) : palette.meterTrack,
                    lineWidth: lineWidth
                )

            if normalizedProgress > 0 {
                Circle()
                    .trim(from: 0, to: normalizedProgress)
                    .stroke(
                        AngularGradient(
                            colors: ringColors,
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(
                        reduceMotion ? nil : .smooth(duration: 0.55),
                        value: normalizedProgress
                    )
            }

            if showsLabel {
                VStack(spacing: 3) {
                    Image(systemName: progress.hasReachedGoal ? "checkmark" : "drop.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(progress.hasReachedGoal ? palette.success : palette.accent)

                    Text(percentageText)
                        .font(.system(size: 20, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(palette.primary)
                        .contentTransition(.numericText())

                    Text("goal")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(palette.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hydration progress")
        .accessibilityValue("\(Int(progress.completionPercentage.rounded())) percent of daily goal")
    }

    private var ringColors: [Color] {
        if progress.hasReachedGoal {
            return [palette.success.opacity(0.72), palette.success, palette.success.opacity(0.82)]
        }
        return [palette.accent.opacity(0.62), palette.accent, palette.accent.opacity(0.78)]
    }

    private var percentageText: String {
        "\(Int(progress.completionPercentage.rounded()))%"
    }

    private var palette: HistoryPalette {
        HistoryPalette(colorScheme: colorScheme)
    }
}
