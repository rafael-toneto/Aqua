import SwiftUI

struct HistoryView: View {
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
            ScrollView {
                VStack(spacing: AquaSpacing.extraLarge) {
                    selectedDateHeader
                    weekStrip
                    selectedDayProgress
                    weekSummary
                }
                .padding(.horizontal, AquaSpacing.medium)
                .padding(.bottom, AquaSpacing.extraLarge)
            }
            .navigationTitle("History")
            .background(Color(uiColor: .systemGroupedBackground))
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading hydration history…")
                        .padding(AquaSpacing.large)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AquaCornerRadius.control))
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
            .alert("Unable to Load History", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Please try again.")
            }
        }
    }

    private var selectedDateHeader: some View {
        HStack(spacing: AquaSpacing.medium) {
            VStack(alignment: .leading, spacing: AquaSpacing.extraSmall) {
                Text(dateHeading)
                    .font(.title.bold())
                    .contentTransition(.numericText())

                Text(viewModel.selectedDate.formatted(.dateTime.month(.wide).day().year()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                isShowingCalendar = true
            } label: {
                Image(systemName: "calendar")
                    .font(.title3.weight(.semibold))
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Open hydration calendar")
        }
    }

    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.weekDates, id: \.self) { date in
                let summary = viewModel.summary(for: date)
                let isSelected = viewModel.isSelected(date)
                let isFuture = date > viewModel.today

                Button {
                    viewModel.select(date)
                } label: {
                    VStack(spacing: AquaSpacing.small) {
                        Text(date.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isSelected ? Color.white : Color.secondary)
                            .frame(width: 27, height: 27)
                            .background(isSelected ? Color.blue : Color.clear, in: Circle())

                        HydrationHistoryRing(progress: summary.progress, lineWidth: 7)
                            .frame(width: 42, height: 42)

                        Text(date.formatted(.dateTime.day()))
                            .font(.caption2.weight(isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.blue : Color.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(isFuture ? 0.28 : 1)
                }
                .buttonStyle(.plain)
                .disabled(isFuture)
                .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                .accessibilityValue(
                    "\(WaterAmountFormatter.string(from: summary.progress.consumedAmount, unit: waterVolumeUnit)) consumed"
                )
            }
        }
        .padding(.vertical, AquaSpacing.medium)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: AquaCornerRadius.card))
    }

    private var selectedDayProgress: some View {
        let progress = viewModel.selectedSummary.progress

        return VStack(spacing: AquaSpacing.large) {
            HydrationHistoryRing(progress: progress, lineWidth: 24, showsLabel: true)
                .frame(width: 245, height: 245)
                .padding(.top, AquaSpacing.small)

            VStack(spacing: AquaSpacing.extraSmall) {
                Text(
                    WaterAmountFormatter.string(
                        from: progress.consumedAmount,
                        unit: waterVolumeUnit
                    )
                )
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.blue)
                    .contentTransition(.numericText())

                Text(
                    "of \(WaterAmountFormatter.string(from: progress.dailyGoal, unit: waterVolumeUnit))"
                )
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 0) {
                metric(
                    title: "Remaining",
                    value: WaterAmountFormatter.string(
                        from: progress.remainingAmount,
                        unit: waterVolumeUnit
                    ),
                    systemImage: "drop"
                )

                Divider().frame(height: 48)

                metric(
                    title: "Entries",
                    value: "\(viewModel.selectedSummary.entries.count)",
                    systemImage: "list.bullet"
                )
            }
        }
        .padding(AquaSpacing.large)
        .frame(maxWidth: .infinity)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: AquaCornerRadius.card))
        .accessibilityElement(children: .contain)
    }

    private var weekSummary: some View {
        AquaCard {
            VStack(alignment: .leading, spacing: AquaSpacing.medium) {
                Label("This Week", systemImage: "chart.bar.fill")
                    .font(.headline)
                    .foregroundStyle(.blue)

                Text(
                    WaterAmountFormatter.string(
                        from: viewModel.weeklyConsumedAmount,
                        unit: waterVolumeUnit
                    )
                )
                    .font(.title.bold())
                    .contentTransition(.numericText())

                if viewModel.weeklyGoalAmount > 0 {
                    ProgressView(
                        value: min(viewModel.weeklyConsumedAmount, viewModel.weeklyGoalAmount),
                        total: viewModel.weeklyGoalAmount
                    )
                    .tint(.blue)
                }

                HStack {
                    Text("\(viewModel.reachedGoalDaysThisWeek) goal days")
                    Spacer()
                    Text(
                        "Goal: \(WaterAmountFormatter.string(from: viewModel.weeklyGoalAmount, unit: waterVolumeUnit))"
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func metric(title: String, value: String, systemImage: String) -> some View {
        VStack(spacing: AquaSpacing.small) {
            Image(systemName: systemImage)
                .foregroundStyle(.blue)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
