import SwiftUI

struct HistoryCalendarSheet: View {
    @ObservedObject var viewModel: HistoryViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.waterVolumeUnit) private var waterVolumeUnit

    private let calendar = HistoryCalendar.calendar
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sheetHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 18)

                weekdayHeader
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)

                Divider()
                    .overlay(palette.divider)
                    .padding(.horizontal, 20)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 30) {
                            ForEach(viewModel.visibleMonths, id: \.self) { month in
                                monthSection(month)
                                    .id(month)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                        .frame(maxWidth: 640)
                        .frame(maxWidth: .infinity)
                    }
                    .onAppear {
                        Task { @MainActor in
                            await Task.yield()
                            proxy.scrollTo(viewModel.currentMonth, anchor: .top)
                        }
                    }
                }
            }
            .background(palette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationBackground(palette.background)
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
    }

    private var sheetHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                    Text("Hydration Calendar")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(palette.primary)

                Spacer(minLength: 12)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(palette.secondary)
                        .frame(width: 36, height: 36)
                        .background(palette.controlBackground, in: Circle())
                        .overlay {
                            Circle().stroke(palette.divider, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close hydration calendar")
            }
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.7)
                    .foregroundStyle(palette.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func monthSection(_ month: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette.primary)
                .padding(.leading, 3)

            LazyVGrid(columns: columns, spacing: 9) {
                ForEach(Array(monthGrid(for: month).enumerated()), id: \.offset) { _, date in
                    if let date {
                        calendarDay(date)
                    } else {
                        Color.clear
                            .frame(height: 62)
                            .accessibilityHidden(true)
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
            withAnimation(.snappy) {
                viewModel.select(date)
            }
            dismiss()
        } label: {
            VStack(spacing: 6) {
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 12, weight: isSelected || isToday ? .bold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? palette.accent : palette.primary)
                    .frame(height: 16)

                HydrationHistoryRing(
                    progress: summary.progress,
                    lineWidth: 4,
                    isHighlighted: isSelected
                )
                .frame(width: 30, height: 30)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(
                isSelected ? palette.accent.opacity(0.11) : Color.clear,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                if isSelected || isToday {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            palette.accent.opacity(isSelected ? 0.34 : 0.2),
                            lineWidth: 1
                        )
                }
            }
            .contentShape(Rectangle())
            .opacity(isFuture ? 0.24 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(
            isFuture
                ? "Future date"
                : "\(WaterAmountFormatter.string(from: summary.progress.consumedAmount, unit: waterVolumeUnit)) consumed, "
                    + "\(Int(summary.progress.completionPercentage.rounded())) percent of goal"
        )
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.25)
            .foregroundStyle(palette.secondary)
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

    private var palette: HistoryPalette {
        HistoryPalette(colorScheme: colorScheme)
    }
}
