import SwiftUI

struct PlanAdjustmentCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let summary: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 34, height: 34)
                .background(palette.accent.opacity(0.11), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("PLAN UPDATED")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.15)
                    .foregroundStyle(palette.secondary)

                Text(summary)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(palette.primary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            palette.controlBackground,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.accent.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Plan adjustment: \(summary)")
    }

    private var palette: PlanPalette {
        PlanPalette(colorScheme: colorScheme)
    }
}

struct PlanEmptyStateView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(palette.accent)

            Text("No planned moments")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.primary)

            Text("Aqua will update the plan when your schedule or planning preferences change.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(palette.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            palette.controlBackground,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(palette.divider.opacity(0.8), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var palette: PlanPalette {
        PlanPalette(colorScheme: colorScheme)
    }
}

struct PlanCompletedStateView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.waterVolumeUnit) private var waterVolumeUnit

    let progress: DailyHydrationProgress

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(palette.success)

            Text("Today’s goal is complete")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.primary)

            Text("You completed the goal you selected. No additional hydration moments are planned.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(palette.secondary)
                .multilineTextAlignment(.center)

            Text(
                "\(WaterAmountFormatter.string(from: progress.consumedAmount, unit: waterVolumeUnit)) logged today."
            )
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(palette.success)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            palette.controlBackground,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(palette.success.opacity(0.28), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var palette: PlanPalette {
        PlanPalette(colorScheme: colorScheme)
    }
}
