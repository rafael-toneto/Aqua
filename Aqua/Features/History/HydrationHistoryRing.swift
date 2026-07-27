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

struct HistoryPalette {
    let background: Color
    let controlBackground: Color
    let meterTrack: Color
    let primary: Color
    let secondary: Color
    let divider: Color
    let accent: Color
    let success: Color

    init(colorScheme: ColorScheme) {
        if colorScheme == .dark {
            background = Color(red: 0.025, green: 0.075, blue: 0.12)
            controlBackground = Color(red: 0.035, green: 0.12, blue: 0.18)
            meterTrack = Color(red: 0.045, green: 0.12, blue: 0.20)
            primary = Color(red: 0.81, green: 0.91, blue: 0.96)
            secondary = Color(red: 0.30, green: 0.55, blue: 0.68)
            divider = Color(red: 0.10, green: 0.25, blue: 0.34)
            accent = Color(red: 0.05, green: 0.78, blue: 0.94)
            success = Color(red: 0.30, green: 0.82, blue: 0.58)
        } else {
            background = Color(red: 0.95, green: 0.98, blue: 0.99)
            controlBackground = Color.white.opacity(0.82)
            meterTrack = Color(red: 0.86, green: 0.92, blue: 0.95)
            primary = Color(red: 0.05, green: 0.16, blue: 0.22)
            secondary = Color(red: 0.27, green: 0.47, blue: 0.57)
            divider = Color(red: 0.76, green: 0.86, blue: 0.90)
            accent = Color(red: 0.00, green: 0.56, blue: 0.76)
            success = Color(red: 0.08, green: 0.58, blue: 0.36)
        }
    }
}
