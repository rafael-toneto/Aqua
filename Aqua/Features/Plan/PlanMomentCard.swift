import SwiftUI

struct PlanMomentCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.waterVolumeUnit) private var waterVolumeUnit

    let moment: HydrationPlanMoment
    let addPlannedAmount: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AquaSpacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                Text(moment.scheduledDate.formatted(date: .omitted, time: .shortened))
                    .font(.headline)
                    .foregroundStyle(palette.primary)
                Spacer()
                statusLabel
            }

            HStack(alignment: .firstTextBaseline, spacing: AquaSpacing.small) {
                Text(formatted(Double(moment.plannedMilliliters)))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(palette.primary)
                    .strikethrough(moment.status == .completed)
                if moment.completedMilliliters > 0 && moment.status != .completed {
                    Text("· \(formatted(Double(moment.completedMilliliters))) logged")
                        .font(.caption)
                        .foregroundStyle(cardSecondaryColor)
                }
            }

            if let contextualText {
                Text(contextualText)
                    .font(.subheadline)
                    .foregroundStyle(cardSecondaryColor)
            }

            if moment.status == .current || moment.status == .partiallyCompleted {
                Button(action: addPlannedAmount) {
                    Label("Add planned amount", systemImage: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(palette.background)
                        .background(
                            palette.accent,
                            in: RoundedRectangle(cornerRadius: AquaCornerRadius.control)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Creates a real hydration entry and updates the plan")
            }
        }
        .padding(AquaSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: AquaCornerRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: AquaCornerRadius.card)
                .stroke(borderColor, lineWidth: moment.status == .current ? 1 : 0.5)
        }
        .opacity([.completed, .cancelled].contains(moment.status) ? 0.68 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    private var statusLabel: some View {
        Label(statusTitle, systemImage: statusIcon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, AquaSpacing.small)
            .padding(.vertical, AquaSpacing.extraSmall)
            .background(statusBadgeBackground, in: Capsule())
    }

    private var statusTitle: String {
        switch moment.status {
        case .completed: "Completed"
        case .partiallyCompleted: "Partly logged"
        case .current: "Now"
        case .upcoming: "Upcoming"
        case .missed: "Missed"
        case .adjusted: "Adjusted"
        case .cancelled: "Cancelled"
        }
    }

    private var statusIcon: String {
        switch moment.status {
        case .completed: "checkmark"
        case .partiallyCompleted: "circle.lefthalf.filled"
        case .current: "drop.fill"
        case .upcoming: "clock"
        case .missed: "clock.badge.exclamationmark"
        case .adjusted: "slider.horizontal.2.square"
        case .cancelled: "xmark"
        }
    }

    private var contextualText: String? {
        switch moment.status {
        case .missed:
            "This amount was included in the updated schedule."
        case .partiallyCompleted:
            "\(formatted(Double(moment.remainingMilliliters))) remains for this moment."
        case .adjusted:
            "Updated to reflect the rest of today."
        case .cancelled:
            "No longer part of the active schedule."
        default:
            moment.rationale
        }
    }

    private var cardBackground: Color {
        palette.controlBackground
    }

    private var cardSecondaryColor: Color {
        palette.secondary
    }

    private var borderColor: Color {
        switch moment.status {
        case .current:
            palette.accent.opacity(0.5)
        case .adjusted:
            palette.warning.opacity(0.45)
        default:
            palette.divider.opacity(0.8)
        }
    }

    private var statusBadgeBackground: Color {
        statusColor.opacity(0.12)
    }

    private var statusColor: Color {
        switch moment.status {
        case .completed:
            palette.success
        case .missed, .partiallyCompleted, .adjusted:
            palette.warning
        case .current, .upcoming:
            palette.accent
        case .cancelled:
            palette.secondary
        }
    }

    private var palette: PlanPalette {
        PlanPalette(colorScheme: colorScheme)
    }

    private var accessibilityLabel: String {
        "\(statusTitle) hydration moment, \(formatted(Double(moment.plannedMilliliters))) scheduled for "
            + moment.scheduledDate.formatted(date: .omitted, time: .shortened)
    }

    private var accessibilityValue: String {
        guard moment.completedMilliliters > 0 else { return statusTitle }
        return "\(formatted(Double(moment.completedMilliliters))) logged, "
            + "\(formatted(Double(moment.remainingMilliliters))) remaining"
    }

    private func formatted(_ amount: Double) -> String {
        WaterAmountFormatter.preciseString(from: amount, unit: waterVolumeUnit)
    }
}
