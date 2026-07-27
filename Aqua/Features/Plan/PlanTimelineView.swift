import SwiftUI

struct PlanTimelineView: View {
    @Environment(\.colorScheme) private var colorScheme

    let entries: [HydrationEntry]
    let moments: [HydrationPlanMoment]
    let addPlannedAmount: (HydrationPlanMoment) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            Text("Today’s Timeline")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.25)
                .textCase(.uppercase)
                .foregroundStyle(palette.secondary)
                .padding(.bottom, AquaSpacing.medium)

            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                HStack(alignment: .top, spacing: AquaSpacing.medium) {
                    PlanTimelineMarker(
                        status: .completed,
                        showsLine: index < entries.count - 1 || !moments.isEmpty
                    )
                    CompletedHydrationEntryCard(entry: entry)
                        .padding(.bottom, AquaSpacing.medium)
                }
            }

            ForEach(Array(moments.enumerated()), id: \.element.id) { index, moment in
                HStack(alignment: .top, spacing: AquaSpacing.medium) {
                    PlanTimelineMarker(
                        status: moment.status,
                        showsLine: index < moments.count - 1
                    )
                    PlanMomentCard(moment: moment) {
                        addPlannedAmount(moment)
                    }
                    .padding(.bottom, AquaSpacing.medium)
                }
            }
        }
    }

    private var palette: PlanPalette {
        PlanPalette(colorScheme: colorScheme)
    }
}

private struct CompletedHydrationEntryCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let entry: HydrationEntry

    var body: some View {
        VStack(alignment: .leading, spacing: AquaSpacing.small) {
            HydrationEntryRow(entry: entry)
            Divider()
                .overlay(palette.divider)
            Label("Completed", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.success)
        }
        .padding(.horizontal, AquaSpacing.medium)
        .padding(.vertical, AquaSpacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            palette.controlBackground,
            in: RoundedRectangle(cornerRadius: AquaCornerRadius.card)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AquaCornerRadius.card)
                .stroke(palette.divider.opacity(0.8), lineWidth: 0.5)
        }
    }

    private var palette: PlanPalette {
        PlanPalette(colorScheme: colorScheme)
    }
}

private struct PlanTimelineMarker: View {
    @Environment(\.colorScheme) private var colorScheme

    let status: HydrationPlanMomentStatus
    let showsLine: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(markerColor.opacity(status == .current ? 1 : 0.14))
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(status == .current ? palette.background : markerColor)
            }
            .frame(width: 32, height: 32)

            if showsLine {
                Rectangle()
                    .fill(palette.divider)
                    .frame(width: 2)
                    .frame(minHeight: 100)
            }
        }
        .accessibilityHidden(true)
    }

    private var markerColor: Color {
        switch status {
        case .completed: palette.success
        case .current: palette.accent
        case .missed, .partiallyCompleted, .adjusted: palette.warning
        case .upcoming: palette.accent
        case .cancelled: palette.secondary
        }
    }

    private var palette: PlanPalette {
        PlanPalette(colorScheme: colorScheme)
    }

    private var icon: String {
        switch status {
        case .completed: "checkmark"
        case .current: "drop.fill"
        case .missed: "arrow.right"
        case .partiallyCompleted: "circle.lefthalf.filled"
        case .adjusted: "arrow.triangle.2.circlepath"
        case .upcoming: "drop"
        case .cancelled: "xmark"
        }
    }
}
