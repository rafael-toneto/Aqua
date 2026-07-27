import SwiftUI

struct PlanPeriodListView: View {
    @Environment(\.colorScheme) private var colorScheme

    let periods: [PlanPeriodViewData]
    @State private var expandedPeriods: Set<HydrationDayPeriod> = []

    var body: some View {
        LazyVStack(alignment: .leading, spacing: AquaSpacing.medium) {
            Text("Today’s periods")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.25)
                .textCase(.uppercase)
                .foregroundStyle(palette.secondary)

            ForEach(periods) { period in
                PlanPeriodCard(
                    data: period,
                    isExpanded: expandedPeriods.contains(period.period),
                    toggleExpansion: { toggle(period.period) }
                )
            }
        }
    }

    private var palette: PlanPalette {
        PlanPalette(colorScheme: colorScheme)
    }

    private func toggle(_ period: HydrationDayPeriod) {
        withAnimation(.snappy) {
            if expandedPeriods.contains(period) {
                expandedPeriods.remove(period)
            } else {
                expandedPeriods.insert(period)
            }
        }
    }
}

private struct PlanPeriodCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.waterVolumeUnit) private var waterVolumeUnit

    let data: PlanPeriodViewData
    let isExpanded: Bool
    let toggleExpansion: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggleExpansion) {
                VStack(alignment: .leading, spacing: AquaSpacing.medium) {
                    HStack(spacing: AquaSpacing.medium) {
                        Image(systemName: icon)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(accentColor)
                            .frame(width: 40, height: 40)
                            .background(accentColor.opacity(0.12), in: Circle())
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(palette.primary)
                            Text(timeRange)
                                .font(.caption)
                                .foregroundStyle(palette.secondary)
                        }

                        Spacer(minLength: AquaSpacing.small)
                        statusBadge

                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.secondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: AquaSpacing.small) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(formatted(data.consumedMilliliters)) logged")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primary)
                            Spacer()
                            Text("\(formatted(data.plannedMilliliters)) planned")
                                .font(.subheadline)
                                .foregroundStyle(palette.secondary)
                        }

                        ProgressView(value: progressValue, total: progressTotal)
                            .tint(data.isComplete ? palette.success : accentColor)

                        if data.consumedMilliliters > data.plannedMilliliters {
                            Text(
                                "\(formatted(data.consumedMilliliters - data.plannedMilliliters)) above this period’s goal"
                            )
                            .font(.caption)
                            .foregroundStyle(palette.secondary)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(statusTitle)")
            .accessibilityValue(
                "\(formatted(data.consumedMilliliters)) logged of \(formatted(data.plannedMilliliters)) planned"
            )
            .accessibilityHint(isExpanded ? "Collapses checkpoints" : "Expands checkpoints")

            if isExpanded {
                Divider()
                    .overlay(palette.divider)
                    .padding(.vertical, AquaSpacing.medium)

                if data.checkpoints.isEmpty {
                    Label("No checkpoints are needed for this period", systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, AquaSpacing.small)
                } else {
                    PlanCheckpointTimeline(data: data, accentColor: accentColor)
                }
            }
        }
        .padding(AquaSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            palette.controlBackground,
            in: RoundedRectangle(cornerRadius: AquaCornerRadius.card)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AquaCornerRadius.card)
                .stroke(borderColor, lineWidth: data.isComplete ? 1 : 0.5)
        }
    }

    private var statusBadge: some View {
        Label(statusTitle, systemImage: statusIcon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, AquaSpacing.small)
            .padding(.vertical, AquaSpacing.extraSmall)
            .background(statusColor.opacity(0.12), in: Capsule())
    }

    private var title: String {
        switch data.period {
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        }
    }

    private var timeRange: String {
        switch data.period {
        case .morning: "12:00 AM–11:59 AM"
        case .afternoon: "12:00 PM–5:59 PM"
        case .evening: "6:00 PM–11:59 PM"
        }
    }

    private var icon: String {
        switch data.period {
        case .morning: "sunrise.fill"
        case .afternoon: "sun.max.fill"
        case .evening: "moon.stars.fill"
        }
    }

    private var statusTitle: String {
        switch data.state {
        case .completed: "Complete"
        case .current: "Ongoing"
        case .upcoming: "Upcoming"
        case .missed: "Below goal"
        }
    }

    private var statusIcon: String {
        switch data.state {
        case .completed: "checkmark.circle.fill"
        case .current: "clock.fill"
        case .upcoming: "clock"
        case .missed: "exclamationmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch data.state {
        case .completed: palette.success
        case .missed: palette.warning
        case .current: palette.accent
        case .upcoming: palette.secondary
        }
    }

    private var accentColor: Color {
        palette.accent
    }

    private var borderColor: Color {
        data.isComplete ? palette.success.opacity(0.45) : palette.divider.opacity(0.8)
    }

    private var palette: PlanPalette {
        PlanPalette(colorScheme: colorScheme)
    }

    private var progressValue: Double {
        if data.plannedMilliliters == 0, data.isComplete {
            return progressTotal
        }
        return min(Double(data.consumedMilliliters), progressTotal)
    }

    private var progressTotal: Double {
        Double(max(data.plannedMilliliters, 1))
    }

    private func formatted(_ amount: Int) -> String {
        WaterAmountFormatter.string(from: Double(amount), unit: waterVolumeUnit)
    }
}

private struct PlanCheckpointTimeline: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.waterVolumeUnit) private var waterVolumeUnit

    let data: PlanPeriodViewData
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AquaSpacing.medium) {
            VStack(alignment: .leading, spacing: AquaSpacing.extraSmall) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Checkpoints")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.primary)
                    Spacer()
                    Text("\(data.completedCheckpointCount) of \(data.checkpoints.count) done")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            data.completedCheckpointCount == data.checkpoints.count
                                ? palette.success
                                : palette.secondary
                        )
                }

                Text("Cumulative targets from today’s adaptive plan")
                    .font(.caption)
                    .foregroundStyle(palette.secondary)
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(data.checkpoints.enumerated()), id: \.element.id) { index, checkpoint in
                    let progress = progressTowardCheckpoint(at: index)
                    let state = data.checkpointState(at: index)

                    HStack(alignment: .top, spacing: AquaSpacing.medium) {
                        CheckpointProgressMarker(
                            progress: progress,
                            connectorProgress: connectorProgress(after: index),
                            showsConnector: index < data.checkpoints.count - 1,
                            accentColor: accentColor,
                            state: state
                        )

                        VStack(alignment: .leading, spacing: AquaSpacing.extraSmall) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(checkpoint.scheduledDate.formatted(date: .omitted, time: .shortened))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(palette.primary)
                                Spacer()
                                checkpointStatus(state: state)
                            }

                            Text(formatted(checkpoint.cumulativeMilliliters))
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(palette.primary)
                            Text("total by this time")
                                .font(.caption)
                                .foregroundStyle(palette.secondary)
                        }
                        .padding(.top, 2)
                        .padding(.bottom, index < data.checkpoints.count - 1 ? AquaSpacing.medium : 0)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "Checkpoint at \(checkpoint.scheduledDate.formatted(date: .omitted, time: .shortened)), "
                            + "\(formatted(checkpoint.cumulativeMilliliters)) total"
                    )
                    .accessibilityValue(accessibilityValue(progress: progress, state: state))
                }
            }
        }
    }

    private func checkpointStatus(state: PlanCheckpointProgressState) -> some View {
        Label(checkpointStatusTitle(for: state), systemImage: checkpointStatusIcon(for: state))
        .font(.caption.weight(.semibold))
        .foregroundStyle(checkpointStatusColor(for: state))
        .padding(.horizontal, AquaSpacing.small)
        .padding(.vertical, AquaSpacing.extraSmall)
        .background(
            checkpointStatusColor(for: state).opacity(0.12),
            in: Capsule()
        )
    }

    private func checkpointStatusTitle(for state: PlanCheckpointProgressState) -> String {
        switch state {
        case .completed: "Done"
        case .missed: "Missed"
        case .next: "Next"
        case .upcoming: "Upcoming"
        }
    }

    private func checkpointStatusIcon(for state: PlanCheckpointProgressState) -> String {
        switch state {
        case .completed: "checkmark"
        case .missed: "exclamationmark"
        case .next: "drop.fill"
        case .upcoming: "clock"
        }
    }

    private func checkpointStatusColor(for state: PlanCheckpointProgressState) -> Color {
        switch state {
        case .completed: palette.success
        case .missed: palette.danger
        case .next: accentColor
        case .upcoming: palette.secondary
        }
    }

    private var palette: PlanPalette {
        PlanPalette(colorScheme: colorScheme)
    }

    private func progressTowardCheckpoint(at index: Int) -> Double {
        guard data.checkpoints.indices.contains(index) else { return 0 }
        let previousTarget = index == 0
            ? 0
            : data.checkpoints[index - 1].cumulativeMilliliters
        let target = data.checkpoints[index].cumulativeMilliliters
        let interval = max(target - previousTarget, 1)
        let progressInInterval = data.consumedMilliliters - previousTarget
        return min(max(Double(progressInInterval) / Double(interval), 0), 1)
    }

    private func connectorProgress(after index: Int) -> Double {
        guard data.checkpoints.indices.contains(index + 1) else { return 0 }
        return progressTowardCheckpoint(at: index + 1)
    }

    private func accessibilityValue(
        progress: Double,
        state: PlanCheckpointProgressState
    ) -> String {
        let percentage = Int((progress * 100).rounded())
        switch state {
        case .completed:
            return "Done"
        case .missed:
            return "Missed checkpoint, \(percentage) percent complete"
        case .next:
            return "Next checkpoint, \(percentage) percent complete"
        case .upcoming:
            return "Upcoming"
        }
    }

    private func formatted(_ amount: Int) -> String {
        WaterAmountFormatter.string(from: Double(amount), unit: waterVolumeUnit)
    }
}

private struct CheckpointProgressMarker: View {
    @Environment(\.colorScheme) private var colorScheme

    let progress: Double
    let connectorProgress: Double
    let showsConnector: Bool
    let accentColor: Color
    let state: PlanCheckpointProgressState

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(markerBackgroundColor)

                if progress > 0, progress < 1 {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            markerForegroundColor,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .padding(2)
                }

                Image(systemName: markerIcon)
                    .font(.caption.bold())
                    .foregroundStyle(markerForegroundColor)
            }
            .frame(width: 28, height: 28)

            if showsConnector {
                ZStack(alignment: .top) {
                    Capsule()
                        .fill(palette.divider.opacity(0.8))
                    Capsule()
                        .fill(connectorProgress >= 1 ? palette.success : accentColor)
                        .scaleEffect(y: connectorProgress, anchor: .top)
                }
                .frame(width: 3, height: 64)
            }
        }
        .accessibilityHidden(true)
    }

    private var markerBackgroundColor: Color {
        switch state {
        case .completed: palette.success
        case .missed: palette.danger.opacity(0.12)
        case .next, .upcoming: palette.meterTrack
        }
    }

    private var markerForegroundColor: Color {
        switch state {
        case .completed: palette.background
        case .missed: palette.danger
        case .next, .upcoming: accentColor
        }
    }

    private var palette: PlanPalette {
        PlanPalette(colorScheme: colorScheme)
    }

    private var markerIcon: String {
        switch state {
        case .completed: "checkmark"
        case .missed: "exclamationmark"
        case .next, .upcoming: "drop.fill"
        }
    }
}
