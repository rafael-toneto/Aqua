import SwiftUI

struct PlanHeaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.waterVolumeUnit) private var waterVolumeUnit

    let data: PlanViewData
    let outsideActiveHours: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                sectionLabel("Today’s Plan")

                Text("Three flexible goals for morning, afternoon, and evening.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(palette.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    statusPill

                    Spacer(minLength: 8)

                    Text("\(data.completedPeriodCount) of 3 periods")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.secondary)
                }

                HStack(alignment: .center, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(formatted(data.progress.consumedAmount))
                            .font(.system(size: 38, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(palette.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .contentTransition(.numericText())

                        Text("of \(formatted(data.progress.dailyGoal))")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(palette.secondary)

                        Text(remainingText)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(palette.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    progressRing
                }

                HStack(spacing: 10) {
                    summaryMetric(
                        title: "Consumed",
                        value: formatted(data.progress.consumedAmount)
                    )
                    summaryMetric(
                        title: "Goal",
                        value: formatted(data.progress.dailyGoal)
                    )
                    summaryMetric(
                        title: "Periods",
                        value: "\(data.completedPeriodCount)/3"
                    )
                }
            }
            .padding(16)
            .background(
                palette.controlBackground,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(palette.divider.opacity(0.8), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily hydration plan, \(statusTitle)")
        .accessibilityValue(
            "\(formatted(data.progress.consumedAmount)) consumed, "
                + "\(formatted(data.progress.remainingAmount)) remaining, "
                + "\(data.completedPeriodCount) of 3 periods complete"
        )
    }

    private var statusPill: some View {
        Label(statusTitle, systemImage: statusIcon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(statusColor.opacity(0.28), lineWidth: 1)
            }
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(palette.accent.opacity(0.2), lineWidth: 9)

            Circle()
                .trim(from: 0, to: normalizedProgress)
                .stroke(
                    AngularGradient(
                        colors: [
                            statusColor.opacity(0.64),
                            statusColor,
                            statusColor.opacity(0.78)
                        ],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.55), value: normalizedProgress)

            VStack(spacing: 3) {
                Image(systemName: data.progress.hasReachedGoal ? "checkmark" : "drop.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(statusColor)

                Text("\(Int(data.progress.completionPercentage.rounded()))%")
                    .font(.system(size: 18, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(palette.primary)

                Text("goal")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(palette.secondary)
            }
        }
        .frame(width: 100, height: 100)
        .accessibilityHidden(true)
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(palette.secondary)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(palette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(
            palette.background.opacity(colorScheme == .dark ? 0.7 : 0.58),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.25)
            .foregroundStyle(palette.secondary)
    }

    private var remainingText: String {
        if data.progress.hasReachedGoal {
            return "Goal complete"
        }
        return "\(formatted(data.progress.remainingAmount)) remaining"
    }

    private var normalizedProgress: Double {
        min(max(data.progress.completionPercentage / 100, 0), 1)
    }

    private var statusTitle: String {
        if data.progress.hasReachedGoal { return "Goal Completed" }
        if data.periods.contains(where: { $0.state == .missed }) { return "Needs Catch-up" }
        if outsideActiveHours { return "Day Ended" }
        if data.plan == nil { return "No Plan Yet" }
        return "On Track"
    }

    private var statusIcon: String {
        switch statusTitle {
        case "Goal Completed": "checkmark.circle.fill"
        case "Needs Catch-up": "clock.badge.exclamationmark"
        case "Day Ended": "moon.stars.fill"
        default: "checkmark.circle"
        }
    }

    private var statusColor: Color {
        switch statusTitle {
        case "Goal Completed": palette.success
        case "Needs Catch-up": palette.warning
        default: palette.accent
        }
    }

    private var palette: PlanPalette {
        PlanPalette(colorScheme: colorScheme)
    }

    private func formatted(_ amount: Double) -> String {
        WaterAmountFormatter.preciseString(from: amount, unit: waterVolumeUnit)
    }
}
