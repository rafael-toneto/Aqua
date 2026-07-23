import SwiftUI

struct PlanAdjustmentCard: View {
    let summary: String

    var body: some View {
        Label {
            Text(summary)
                .font(.subheadline)
        } icon: {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.blue)
        }
        .padding(AquaSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.09), in: RoundedRectangle(cornerRadius: AquaCornerRadius.control))
        .accessibilityLabel("Plan adjustment: \(summary)")
    }
}

struct PlanEmptyStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No planned moments", systemImage: "list.bullet.clipboard")
        } description: {
            Text("Aqua will update the plan when your schedule or planning preferences change.")
        }
    }
}

struct PlanCompletedStateView: View {
    @Environment(\.waterVolumeUnit) private var waterVolumeUnit
    let progress: DailyHydrationProgress

    var body: some View {
        ContentUnavailableView {
            Label("Today’s goal is complete", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } description: {
            Text("You completed the goal you selected. No additional hydration moments are planned.")
            Text(
                "\(WaterAmountFormatter.string(from: progress.consumedAmount, unit: waterVolumeUnit)) logged today."
            )
        }
    }
}
