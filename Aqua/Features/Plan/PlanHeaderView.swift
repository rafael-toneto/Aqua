import SwiftUI

struct PlanHeaderView: View {
    @Environment(\.waterVolumeUnit) private var waterVolumeUnit

    let data: PlanViewData
    let outsideActiveHours: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AquaSpacing.medium) {
            VStack(alignment: .leading, spacing: AquaSpacing.extraSmall) {
                Text("Daily Hydration Plan")
                    .font(.title.bold())
                Text("Three flexible goals for morning, afternoon, and evening.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            AquaCard {
                VStack(alignment: .leading, spacing: AquaSpacing.medium) {
                    HStack(alignment: .center, spacing: AquaSpacing.medium) {
                        ZStack {
                            Circle()
                                .stroke(.blue.opacity(0.12), lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: data.progress.completionPercentage / 100)
                                .stroke(.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(Int(data.progress.completionPercentage.rounded()))%")
                                .font(.caption.bold())
                        }
                        .frame(width: 70, height: 70)
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: AquaSpacing.extraSmall) {
                            Label(statusTitle, systemImage: statusIcon)
                                .font(.headline)
                                .foregroundStyle(statusColor)
                            Text(
                                "\(formatted(data.progress.consumedAmount)) consumed · "
                                    + "\(formatted(data.progress.remainingAmount)) remaining"
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    Label(
                        "\(data.completedPeriodCount) of 3 periods complete",
                        systemImage: "checkmark.circle"
                    )
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                }
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
        case "Goal Completed": .green
        case "Needs Catch-up": .orange
        default: .blue
        }
    }

    private func formatted(_ amount: Double) -> String {
        WaterAmountFormatter.string(from: amount, unit: waterVolumeUnit)
    }
}
