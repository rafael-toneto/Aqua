import AppIntents
import Foundation
import SwiftData
import SwiftUI
import WidgetKit

private struct AquaWidgetLog: Identifiable {
    let id: UUID
    let amountInMilliliters: Double
    let date: Date
}

private struct AquaWidgetEntry: TimelineEntry {
    let date: Date
    let consumedInMilliliters: Double
    let goalInMilliliters: Double
    let quickAddAmountsInMilliliters: [Double]
    let recentLogs: [AquaWidgetLog]
    let usesFluidOunces: Bool

    var progress: Double {
        guard goalInMilliliters > 0 else { return 0 }
        return min(max(consumedInMilliliters / goalInMilliliters, 0), 1)
    }

    var percentage: Int {
        Int((progress * 100).rounded())
    }

    static let placeholder = AquaWidgetEntry(
        date: .now,
        consumedInMilliliters: 1_250,
        goalInMilliliters: 2_000,
        quickAddAmountsInMilliliters: HydrationDefaults.quickAddAmountsInMilliliters,
        recentLogs: [
            AquaWidgetLog(id: UUID(), amountInMilliliters: 300, date: .now.addingTimeInterval(-1_800)),
            AquaWidgetLog(id: UUID(), amountInMilliliters: 200, date: .now.addingTimeInterval(-5_400))
        ],
        usesFluidOunces: false
    )
}

private struct AquaWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> AquaWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (AquaWidgetEntry) -> Void) {
        Task { @MainActor in
            completion(loadEntry() ?? .placeholder)
        }
    }

    func getTimeline(
        in context: Context,
        completion: @escaping @Sendable (Timeline<AquaWidgetEntry>) -> Void
    ) {
        Task { @MainActor in
            let entry = loadEntry() ?? fallbackEntry
            let calendar = Calendar.autoupdatingCurrent
            let nextRefresh = calendar.date(
                byAdding: .minute,
                value: 30,
                to: entry.date
            ) ?? entry.date.addingTimeInterval(1_800)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    @MainActor
    private func loadEntry(now: Date = .now) -> AquaWidgetEntry? {
        do {
            let container = try AquaSharedStore.makeModelContainer()
            let context = ModelContext(container)
            let calendar = Calendar.autoupdatingCurrent
            let startOfDay = calendar.startOfDay(for: now)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                return nil
            }

            let descriptor = FetchDescriptor<SwiftDataHydrationEntry>(
                predicate: #Predicate { entry in
                    entry.date >= startOfDay && entry.date < endOfDay
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let storedEntries = try context.fetch(descriptor)
            let consumed = storedEntries.reduce(0) { partialResult, storedEntry in
                partialResult + max(storedEntry.amountInMilliliters, 0)
            }

            return AquaWidgetEntry(
                date: now,
                consumedInMilliliters: consumed,
                goalInMilliliters: Self.dailyGoal,
                quickAddAmountsInMilliliters: Self.quickAddAmounts,
                recentLogs: storedEntries.prefix(4).map {
                    AquaWidgetLog(
                        id: $0.id,
                        amountInMilliliters: $0.amountInMilliliters,
                        date: $0.date
                    )
                },
                usesFluidOunces: Self.usesFluidOunces
            )
        } catch {
            return nil
        }
    }

    private var fallbackEntry: AquaWidgetEntry {
        AquaWidgetEntry(
            date: .now,
            consumedInMilliliters: 0,
            goalInMilliliters: Self.dailyGoal,
            quickAddAmountsInMilliliters: Self.quickAddAmounts,
            recentLogs: [],
            usesFluidOunces: Self.usesFluidOunces
        )
    }

    private static var dailyGoal: Double {
        let storedGoal = AquaSharedStore.userDefaults.double(
            forKey: AquaSharedStore.PreferenceKey.dailyGoalInMilliliters
        )
        return storedGoal.isFinite
            && storedGoal > 0
            && storedGoal <= HydrationLimits.maximumDailyGoalInMilliliters
            ? storedGoal
            : HydrationDefaults.dailyGoalInMilliliters
    }

    private static var quickAddAmounts: [Double] {
        guard let storedValues = AquaSharedStore.userDefaults.array(
            forKey: AquaSharedStore.PreferenceKey.quickAddAmountsInMilliliters
        ) else {
            return HydrationDefaults.quickAddAmountsInMilliliters
        }

        let amounts = storedValues.compactMap { ($0 as? NSNumber)?.doubleValue }
        guard amounts.count == HydrationDefaults.quickAddAmountsInMilliliters.count,
              amounts.allSatisfy({
                  $0.isFinite
                      && $0 > 0
                      && $0 <= HydrationLimits.maximumSingleEntryInMilliliters
              }) else {
            return HydrationDefaults.quickAddAmountsInMilliliters
        }
        return amounts
    }

    private static var usesFluidOunces: Bool {
        AquaSharedStore.userDefaults.string(
            forKey: AquaSharedStore.PreferenceKey.volumeDisplayUnit
        ) == "fluidOunces"
    }
}

private struct AquaFlowWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    let entry: AquaWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallWidget
            case .systemMedium:
                mediumWidget
            case .systemLarge:
                largeWidget
            default:
                smallWidget
            }
        }
        .containerBackground(for: .widget) {
            backgroundColor
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 4) {
            brandHeader(compact: true)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formattedAmount(entry.consumedInMilliliters))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 0)

                Text("\(entry.percentage)%")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(accentColor)
            }

            progressBar

            VStack(spacing: 3) {
                quickAddButtons(vertical: true)
            }
        }
    }

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 9) {
                brandHeader(compact: false)

                Spacer(minLength: 0)

                Text(formattedAmount(entry.consumedInMilliliters))
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("of \(formattedAmount(entry.goalInMilliliters)) today")
                    .font(.caption)
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1)

                progressBar
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 7) {
                Text("QUICK ADD")
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(secondaryColor)

                quickAddButtons(vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 16) {
            brandHeader(compact: false)

            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(trackColor, lineWidth: 11)
                    Circle()
                        .trim(from: 0, to: entry.progress)
                        .stroke(
                            accentColor,
                            style: StrokeStyle(lineWidth: 11, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 1) {
                        Text("\(entry.percentage)%")
                            .font(.title2.bold())
                            .monospacedDigit()
                        Text("today")
                            .font(.caption2)
                            .foregroundStyle(secondaryColor)
                    }
                }
                .frame(width: 104, height: 104)

                VStack(alignment: .leading, spacing: 7) {
                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondaryColor)
                    Text(formattedAmount(entry.consumedInMilliliters))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("Goal · \(formattedAmount(entry.goalInMilliliters))")
                        .font(.subheadline)
                        .foregroundStyle(secondaryColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("QUICK ADD")
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(secondaryColor)
                quickAddButtons(vertical: false)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("RECENT")
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(secondaryColor)

                if entry.recentLogs.isEmpty {
                    Label("No water logged yet today", systemImage: "drop")
                        .font(.subheadline)
                        .foregroundStyle(secondaryColor)
                        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                } else {
                    ForEach(entry.recentLogs.prefix(3)) { log in
                        HStack(spacing: 9) {
                            Image(systemName: "drop.fill")
                                .font(.caption)
                                .foregroundStyle(accentColor)
                            Text(formattedAmount(log.amountInMilliliters))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(primaryColor)
                            Spacer()
                            Text(log.date, style: .time)
                                .font(.caption)
                                .foregroundStyle(secondaryColor)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func quickAddButtons(vertical: Bool) -> some View {
        if vertical {
            ForEach(Array(entry.quickAddAmountsInMilliliters.enumerated()), id: \.offset) { _, amount in
                quickAddButton(amount)
            }
        } else {
            HStack(spacing: 8) {
                ForEach(Array(entry.quickAddAmountsInMilliliters.enumerated()), id: \.offset) { _, amount in
                    quickAddButton(amount)
                }
            }
        }
    }

    private func quickAddButton(_ amount: Double) -> some View {
        Button(intent: LogQuickAddWaterIntent(amountInMilliliters: amount)) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.caption2.bold())
                Text(formattedAmount(amount))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(accentColor)
            .frame(maxWidth: .infinity, minHeight: family == .systemSmall ? 22 : 27)
            .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(accentColor.opacity(0.22), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(formattedAmount(amount)) of water")
    }

    private func brandHeader(compact: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "drop.fill")
                .font(compact ? .caption : .subheadline)
                .foregroundStyle(accentColor)
                .frame(width: compact ? 22 : 28, height: compact ? 22 : 28)
                .background(accentColor.opacity(0.12), in: Circle())

            Text("AquaFlow")
                .font(compact ? .caption.weight(.bold) : .subheadline.weight(.bold))
                .foregroundStyle(primaryColor)

            Spacer(minLength: 0)
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(trackColor)
                Capsule()
                    .fill(accentColor)
                    .frame(width: proxy.size.width * entry.progress)
            }
        }
        .frame(height: family == .systemSmall ? 5 : 7)
        .accessibilityHidden(true)
    }

    private func formattedAmount(_ milliliters: Double) -> String {
        if entry.usesFluidOunces {
            let fluidOunces = milliliters / 29.5735295625
            return "\(fluidOunces.formatted(.number.precision(.fractionLength(0...1)))) fl oz"
        }

        if milliliters >= 1_000 {
            let liters = milliliters / 1_000
            return "\(liters.formatted(.number.precision(.fractionLength(0...1)))) L"
        }
        return "\(milliliters.formatted(.number.precision(.fractionLength(0)))) ml"
    }

    private var accentColor: Color {
        colorScheme == .dark
            ? Color(red: 0.20, green: 0.71, blue: 0.85)
            : Color(red: 0.03, green: 0.49, blue: 0.64)
    }

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color(red: 0.055, green: 0.067, blue: 0.071)
            : Color(red: 0.98, green: 0.99, blue: 0.99)
    }

    private var primaryColor: Color {
        colorScheme == .dark
            ? Color(red: 0.941, green: 0.957, blue: 0.961)
            : Color(red: 0.086, green: 0.125, blue: 0.137)
    }

    private var secondaryColor: Color {
        colorScheme == .dark
            ? Color(red: 0.655, green: 0.702, blue: 0.722)
            : Color(red: 0.353, green: 0.404, blue: 0.424)
    }

    private var trackColor: Color {
        colorScheme == .dark
            ? Color(red: 0.153, green: 0.184, blue: 0.196)
            : Color(red: 0.886, green: 0.906, blue: 0.910)
    }
}

struct AquaFlowHydrationWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: AquaSharedStore.widgetKind,
            provider: AquaWidgetProvider()
        ) { entry in
            AquaFlowWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Add Water")
        .description("Track today’s hydration and log your configured quick-add amounts.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
