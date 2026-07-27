import SwiftUI

struct HydrationProgressView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.waterVolumeUnit) private var waterVolumeUnit

    let progress: DailyHydrationProgress

    private var normalizedProgress: Double {
        progress.completionPercentage / 100
    }

    private var percentageText: String {
        "\(Int(progress.completionPercentage.rounded()))%"
    }

    var body: some View {
        AquaCard {
            VStack(alignment: .leading, spacing: AquaSpacing.large) {
                HStack(alignment: .center, spacing: AquaSpacing.large) {
                    progressRing

                    VStack(alignment: .leading, spacing: AquaSpacing.small) {
                        Text("Today")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(
                            WaterAmountFormatter.string(
                                from: progress.consumedAmount,
                                unit: waterVolumeUnit
                            )
                        )
                            .font(.title2.weight(.bold))
                            .contentTransition(.numericText())

                        Text(
                            "of \(WaterAmountFormatter.string(from: progress.dailyGoal, unit: waterVolumeUnit))"
                        )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                Label {
                    Text(statusText)
                        .font(.subheadline.weight(.medium))
                } icon: {
                    Image(systemName: progress.hasReachedGoal ? "checkmark.circle.fill" : "drop.fill")
                }
                .foregroundStyle(progress.hasReachedGoal ? palette.success : palette.accent)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily hydration progress")
        .accessibilityValue(accessibilityValue)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(palette.meterTrack, lineWidth: 12)

            Circle()
                .trim(from: 0, to: normalizedProgress)
                .stroke(
                    AngularGradient(
                        colors: [palette.accent.opacity(0.72), palette.accent, palette.accent.opacity(0.82)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.smooth, value: normalizedProgress)

            VStack(spacing: 2) {
                Text(percentageText)
                    .font(.title2.weight(.bold))
                    .contentTransition(.numericText())
                Text("complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 128, height: 128)
    }

    private var statusText: String {
        if progress.hasReachedGoal {
            return "Daily goal reached"
        }
        return "\(WaterAmountFormatter.string(from: progress.remainingAmount, unit: waterVolumeUnit)) remaining"
    }

    private var palette: AquaPalette {
        AquaPalette(colorScheme: colorScheme)
    }

    private var accessibilityValue: String {
        "\(WaterAmountFormatter.string(from: progress.consumedAmount, unit: waterVolumeUnit)) consumed of "
            + "\(WaterAmountFormatter.string(from: progress.dailyGoal, unit: waterVolumeUnit)), "
            + "\(statusText), \(percentageText)"
    }
}
