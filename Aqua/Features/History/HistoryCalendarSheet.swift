import SwiftUI

struct HistoryCalendarSheet: View {
    @ObservedObject var viewModel: HistoryViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.waterVolumeUnit) private var waterVolumeUnit

    private let calendar = HistoryCalendar.calendar
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                weekdayHeader
                    .padding(.horizontal, AquaSpacing.medium)
                    .padding(.vertical, AquaSpacing.small)

                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: AquaSpacing.extraLarge) {
                            ForEach(viewModel.visibleMonths, id: \.self) { month in
                                monthSection(month)
                                    .id(month)
                            }
                        }
                        .padding(.horizontal, AquaSpacing.medium)
                        .padding(.vertical, AquaSpacing.medium)
                        .padding(.bottom, AquaSpacing.extraLarge)
                    }
                    .onAppear {
                        Task { @MainActor in
                            await Task.yield()
                            proxy.scrollTo(viewModel.currentMonth, anchor: .top)
                        }
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Hydration Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, AquaSpacing.small)
    }

    private func monthSection(_ month: Date) -> some View {
        VStack(alignment: .leading, spacing: AquaSpacing.medium) {
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.title2.bold())
                .padding(.leading, AquaSpacing.extraSmall)

            LazyVGrid(columns: columns, spacing: AquaSpacing.medium) {
                ForEach(Array(monthGrid(for: month).enumerated()), id: \.offset) { _, date in
                    if let date {
                        calendarDay(date)
                    } else {
                        Color.clear
                            .frame(height: 64)
                    }
                }
            }
        }
    }

    private func calendarDay(_ date: Date) -> some View {
        let summary = viewModel.summary(for: date)
        let isFuture = date > viewModel.today
        let isSelected = viewModel.isSelected(date)
        let isToday = viewModel.isToday(date)

        return Button {
            viewModel.select(date)
            dismiss()
        } label: {
            VStack(spacing: 7) {
                Text(date.formatted(.dateTime.day()))
                    .font(.subheadline.weight(isSelected || isToday ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .frame(width: 28, height: 28)
                    .background {
                        if isSelected {
                            Circle().fill(Color.blue)
                        } else if isToday {
                            Circle().stroke(Color.blue, lineWidth: 2)
                        }
                    }

                HydrationHistoryRing(progress: summary.progress, lineWidth: 6)
                    .frame(width: 34, height: 34)
            }
            .frame(maxWidth: .infinity)
            .opacity(isFuture ? 0.28 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(
            isFuture
                ? "Future date"
                : "\(WaterAmountFormatter.string(from: summary.progress.consumedAmount, unit: waterVolumeUnit)) consumed"
        )
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let startIndex = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    private func monthGrid(for month: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let dayRange = calendar.range(of: .day, in: .month, for: month) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingEmptyDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        var dates = Array<Date?>(repeating: nil, count: leadingEmptyDays)
        dates.append(contentsOf: dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        })
        return dates
    }
}
