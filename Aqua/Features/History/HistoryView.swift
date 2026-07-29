import SwiftUI

struct HistoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.waterVolumeUnit) private var waterVolumeUnit
    @StateObject private var viewModel: HistoryViewModel
    @State private var isShowingCalendar = false

    private let calendar = HistoryCalendar.calendar

    init(
        trackingService: any HydrationTrackingServiceProtocol,
        goalService: any HydrationGoalServiceProtocol,
        dateProvider: any DateProviding
    ) {
        _viewModel = StateObject(
            wrappedValue: HistoryViewModel(
                trackingService: trackingService,
                goalService: goalService,
                dateProvider: dateProvider
            )
        )
    }

    var body: some View {
        NavigationStack {
            List {
                pageHeader
                    .historyListRow(top: 12, bottom: 14)

                weekStrip
                    .historyListRow(top: 0, bottom: 18)

                selectedDaySummary
                    .historyListRow(top: 0, bottom: 18)
                
                weekSummary
                    .historyListRow(top: 18, bottom: 24)

                entriesHeader
                    .historyListRow(top: 0, bottom: 4)

                if viewModel.selectedSummary.entries.isEmpty {
                    emptyEntries
                        .historyListRow(top: 4, bottom: 20)
                } else {
                    ForEach(Array(viewModel.selectedSummary.entries.enumerated()), id: \.element.id) { index, entry in
                        entryRow(
                            entry,
                            isLast: index == viewModel.selectedSummary.entries.count - 1
                        )
                        .historyListRow(top: 0, bottom: 0)
                    }
                }

                Color.clear
                    .frame(height: 4)
                    .historyListRow(top: 0, bottom: 0)
                    .accessibilityHidden(true)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            .background(palette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .overlay {
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .task { await viewModel.load() }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task { await viewModel.load() }
            }
            .refreshable { await viewModel.load() }
            .sheet(isPresented: $isShowingCalendar) {
                HistoryCalendarSheet(viewModel: viewModel)
            }
            .sensoryFeedback(.selection, trigger: viewModel.selectedDate)
            .alert("Unable to Load History", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Please try again.")
            }
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your hydration")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(palette.secondary)

            HStack(alignment: .center, spacing: 12) {
                Text("History")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(palette.primary)

                Spacer(minLength: 12)

                Button {
                    isShowingCalendar = true
                } label: {
                    Label("Calendar", systemImage: "calendar")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.accent)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                        .background(palette.controlBackground, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(palette.accent.opacity(0.25), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open hydration calendar")
            }

            Divider()
                .overlay(palette.divider)
                .padding(.top, 8)
        }
        .historyContentFrame()
    }

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("This Week")

            HStack(alignment: .top, spacing: 3) {
                ForEach(viewModel.weekDates, id: \.self) { date in
                    weekDayButton(date)
                }
            }
        }
        .historyContentFrame()
    }

    private func weekDayButton(_ date: Date) -> some View {
        let summary = viewModel.summary(for: date)
        let isSelected = viewModel.isSelected(date)
        let isFuture = date > viewModel.today

        return Button {
            withAnimation(.snappy) {
                viewModel.select(date)
            }
        } label: {
            VStack(spacing: 6) {
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isSelected ? palette.accent : palette.secondary)

                HydrationHistoryRing(
                    progress: summary.progress,
                    lineWidth: 4,
                    isHighlighted: isSelected
                )
                .frame(width: 32, height: 32)

                Text("\(Int(summary.progress.completionPercentage.rounded()))%")
                    .font(.system(size: 9, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? palette.accent : palette.secondary)

                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? palette.primary : palette.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isSelected ? palette.accent.opacity(0.11) : Color.clear,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(palette.accent.opacity(0.22), lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
            .opacity(isFuture ? 0.28 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(
            "\(WaterAmountFormatter.string(from: summary.progress.consumedAmount, unit: waterVolumeUnit)) consumed, "
                + "\(Int(summary.progress.completionPercentage.rounded())) percent of goal"
        )
    }

    private var selectedDaySummary: some View {
        let summary = viewModel.selectedSummary
        let progress = summary.progress

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                sectionLabel(summaryTitle)

                Spacer(minLength: 12)

                Text(dateHeading)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.secondary)
            }

            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(primaryAmountText(for: progress))
                        .font(.system(size: 38, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(palette.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())

                    Text("of \(formattedAmount(progress.dailyGoal))")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(palette.secondary)

                    Text(remainingText(for: progress))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(palette.secondary)

                    statusPill(for: progress)
                        .padding(.top, 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HydrationHistoryRing(
                    progress: progress,
                    lineWidth: 10,
                    showsLabel: true,
                    isHighlighted: true
                )
                .frame(width: 108, height: 108)
            }

            HStack(spacing: 10) {
                summaryMetric(
                    title: "Consumed",
                    value: formattedAmount(progress.consumedAmount)
                )
                summaryMetric(
                    title: "Goal",
                    value: formattedAmount(progress.dailyGoal)
                )
                summaryMetric(
                    title: "Entries",
                    value: "\(summary.entries.count)"
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
        .historyContentFrame()
        .accessibilityElement(children: .contain)
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
                .minimumScaleFactor(0.74)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(
            palette.background.opacity(colorScheme == .dark ? 0.7 : 0.58),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private func statusPill(for progress: DailyHydrationProgress) -> some View {
        let color = progress.hasReachedGoal ? palette.success : palette.accent

        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(statusText(for: progress))
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
        .overlay {
            Capsule().stroke(color.opacity(0.28), lineWidth: 1)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var entriesHeader: some View {
        VStack(alignment: .leading, spacing: 17) {
            Divider()
                .overlay(palette.divider)

            HStack {
                sectionLabel("Entries")

                Spacer()

                Text(entryCountText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(palette.accent.opacity(0.1), in: Capsule())
            }
        }
        .historyContentFrame()
    }

    private func entryRow(_ entry: HydrationEntry, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Circle()
                    .fill(palette.accent)
                    .frame(width: 8, height: 8)
                    .padding(.top, 9)

                if !isLast {
                    Rectangle()
                        .fill(palette.divider)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 4)
                }
            }
            .frame(width: 20)

            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.date.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(palette.primary)

                        Text(sourceName(for: entry))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(palette.secondary)
                    }

                    Spacer(minLength: 8)

                    Text(formattedAmount(entry.amountInMilliliters))
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(palette.accent)
                }

                if !isLast {
                    Divider()
                        .overlay(palette.divider)
                        .padding(.top, 11)
                }
            }
            .padding(.top, 1)
        }
        .frame(minHeight: 58, alignment: .top)
        .historyContentFrame()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(formattedAmount(entry.amountInMilliliters)), \(sourceName(for: entry))")
        .accessibilityValue(entry.date.formatted(date: .omitted, time: .shortened))
    }

    private var emptyEntries: some View {
        VStack(spacing: 8) {
            Image(systemName: "drop")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(palette.accent)

            Text("No entries for this day")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.primary)

            Text("Choose another day to review its hydration entries.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(palette.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .historyContentFrame()
        .accessibilityElement(children: .combine)
    }

    private var weekSummary: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 34, height: 34)
                    .background(palette.accent.opacity(0.11), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("This week's pace")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.primary)

                    Text("\(viewModel.reachedGoalDaysThisWeek) goal days")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(palette.secondary)
                }

                Spacer(minLength: 8)

                Text(formattedAmount(viewModel.weeklyConsumedAmount))
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.accent)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(palette.meterTrack)

                    Capsule()
                        .fill(palette.accent)
                        .frame(width: proxy.size.width * weeklyNormalizedProgress)
                }
            }
            .frame(height: 6)

            HStack {
                Text("Weekly total")
                Spacer()
                Text("Goal: \(formattedAmount(viewModel.weeklyGoalAmount))")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(palette.secondary)
        }
        .padding(14)
        .background(
            palette.controlBackground,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.divider.opacity(0.8), lineWidth: 1)
        }
        .historyContentFrame()
    }

    private var loadingOverlay: some View {
        ProgressView("Loading hydration history…")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(palette.primary)
            .tint(palette.accent)
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.25)
            .foregroundStyle(palette.secondary)
    }

    private var summaryTitle: String {
        "\(viewModel.selectedDate.formatted(.dateTime.month(.abbreviated).day())) Summary"
    }

    private var dateHeading: String {
        if viewModel.isToday(viewModel.selectedDate) {
            return "Today"
        }
        if calendar.isDateInYesterday(viewModel.selectedDate) {
            return "Yesterday"
        }
        return viewModel.selectedDate.formatted(.dateTime.weekday(.wide))
    }

    private var entryCountText: String {
        let count = viewModel.selectedSummary.entries.count
        return count == 1 ? "1 entry" : "\(count) entries"
    }

    private var weeklyNormalizedProgress: Double {
        guard viewModel.weeklyGoalAmount > 0 else { return 0 }
        return min(max(viewModel.weeklyConsumedAmount / viewModel.weeklyGoalAmount, 0), 1)
    }

    private func primaryAmountText(for progress: DailyHydrationProgress) -> String {
        switch waterVolumeUnit {
        case .metric:
            let liters = progress.consumedAmount / 1_000
            return "\(liters.formatted(.number.grouping(.never).precision(.fractionLength(2)))) L"
        case .fluidOunces:
            return formattedAmount(progress.consumedAmount)
        }
    }

    private func formattedAmount(_ amountInMilliliters: Double) -> String {
        WaterAmountFormatter.string(from: amountInMilliliters, unit: waterVolumeUnit)
    }

    private func remainingText(for progress: DailyHydrationProgress) -> String {
        if progress.hasReachedGoal {
            return "Goal complete"
        }
        return "\(formattedAmount(progress.remainingAmount)) remaining"
    }

    private func statusText(for progress: DailyHydrationProgress) -> String {
        if progress.hasReachedGoal {
            return "Daily goal reached"
        }

        switch progress.completionPercentage {
        case ...0:
            return "No water logged"
        case ...25:
            return "A good start"
        case ...60:
            return "Finding your flow"
        case ...85:
            return "Keeping the flow"
        default:
            return "Almost there"
        }
    }

    private func sourceName(for entry: HydrationEntry) -> String {
        switch entry.source {
        case .quickAdd:
            return "Quick add"
        case .manual:
            return "Custom amount"
        case .plan:
            return "Daily plan"
        case .appIntent, .shortcut:
            return "Shortcut"
        default:
            return "Added water"
        }
    }

    private var palette: HistoryPalette {
        HistoryPalette(colorScheme: colorScheme)
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.errorMessage = nil
                }
            }
        )
    }
}

private struct HistoryListRowModifier: ViewModifier {
    let top: CGFloat
    let bottom: CGFloat

    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets(top: top, leading: 20, bottom: bottom, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

private extension View {
    func historyListRow(top: CGFloat, bottom: CGFloat) -> some View {
        modifier(HistoryListRowModifier(top: top, bottom: bottom))
    }

    func historyContentFrame() -> some View {
        frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
