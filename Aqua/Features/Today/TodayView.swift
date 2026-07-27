import SwiftUI

struct TodayView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.waterVolumeUnit) private var waterVolumeUnit
    @StateObject private var viewModel: TodayViewModel
    @State private var entryOptionsID: UUID?
    @State private var isEntriesExpanded = false
    @State private var isShowingCustomAmount = false
    @State private var quickAddAmounts = HydrationDefaults.quickAddAmountsInMilliliters

    private let trackingService: any HydrationTrackingServiceProtocol
    private let quickAddAmountsService: any QuickAddAmountsServiceProtocol
    private let dateProvider: any DateProviding

    init(
        trackingService: any HydrationTrackingServiceProtocol,
        goalService: any HydrationGoalServiceProtocol,
        quickAddAmountsService: any QuickAddAmountsServiceProtocol,
        dateProvider: any DateProviding
    ) {
        self.trackingService = trackingService
        self.quickAddAmountsService = quickAddAmountsService
        self.dateProvider = dateProvider
        _viewModel = StateObject(
            wrappedValue: TodayViewModel(
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
                    .todayListRow(top: 12, bottom: 16)

                progressSection
                    .todayListRow(top: 0, bottom: 8)

                quickAddSection
                    .todayListRow(top: 0, bottom: 4)

                entriesDisclosureHeader
                    .todayListRow(top: 16, bottom: 16)

                if isEntriesExpanded {
                    if viewModel.entries.isEmpty {
                        emptyState
                            .todayListRow(top: 6, bottom: 24)
                    } else {
                        ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { index, entry in
                            entryRow(entry, isLast: index == viewModel.entries.count - 1)
                                .todayListRow(top: 0, bottom: 0)
                        }
                    }
                }

                Color.clear
                    .frame(height: 8)
                    .todayListRow(top: 0, bottom: 0)
                    .accessibilityHidden(true)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            .background(palette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .overlayPreferenceValue(TodayEntryOptionsAnchorKey.self) { anchors in
                entryOptionsOverlay(anchors: anchors)
            }
            .overlay {
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .onAppear {
                quickAddAmounts = quickAddAmountsService.amountsInMilliliters
                Task { await viewModel.load() }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                quickAddAmounts = quickAddAmountsService.amountsInMilliliters
                Task { await viewModel.load() }
            }
            .refreshable { await viewModel.load() }
            .sheet(isPresented: $isShowingCustomAmount) {
                AddWaterSheet(
                    trackingService: trackingService,
                    dateProvider: dateProvider,
                    waterVolumeUnit: waterVolumeUnit,
                    onSaved: { await viewModel.didAddCustomWater() }
                )
            }
            .sensoryFeedback(.success, trigger: viewModel.feedbackTrigger)
            .alert("Unable to Update Hydration", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Please try again.")
            }
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greeting)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(palette.secondary)

            HStack(alignment: .firstTextBaseline) {
                Text("Today")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(palette.primary)

                Spacer(minLength: 12)

                Text(
                    viewModel.displayedDate.formatted(
                        .dateTime.weekday(.wide).month(.abbreviated).day()
                    )
                )
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Divider()
                .overlay(palette.divider)
                .padding(.top, 8)
        }
        .contentFrame()
    }

    private var progressSection: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text(primaryAmountText)
                    .font(.system(size: 48, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .contentTransition(.numericText())

                VStack(alignment: .leading, spacing: 5) {
                    Text("of \(goalAmountText) today")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(palette.secondary)

                    Text(remainingText)
                        .font(.system(size: 13, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(palette.secondary)
                }

                statusPill
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                verticalProgressMeter

                Text(percentageText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.secondary)
                    .contentTransition(.numericText())
            }
            .frame(width: 48)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 16)
        .contentFrame()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily hydration progress")
        .accessibilityValue(progressAccessibilityValue)
    }

    private var verticalProgressMeter: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(palette.meterTrack)

                LinearGradient(
                    colors: [palette.accent.opacity(0.72), palette.accent],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: proxy.size.height * normalizedProgress)

                Rectangle()
                    .fill(palette.divider)
                    .frame(height: 1)
                    .padding(.horizontal, 8)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 48)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .animation(.smooth, value: normalizedProgress)
        }
        .frame(width: 48, height: 196)
    }

    private var statusPill: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(viewModel.progress.hasReachedGoal ? palette.success : palette.accent)
                .frame(width: 6, height: 6)

            Text(statusText)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(viewModel.progress.hasReachedGoal ? palette.success : palette.accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [
                    (viewModel.progress.hasReachedGoal ? palette.success : palette.accent).opacity(0.22),
                    (viewModel.progress.hasReachedGoal ? palette.success : palette.accent).opacity(0.09)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(
                    (viewModel.progress.hasReachedGoal ? palette.success : palette.accent).opacity(0.42),
                    lineWidth: 1
                )
        }
    }

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            Divider()
                .overlay(palette.divider)
                .padding(.bottom, 4)

            sectionLabel("Quick Add")

            HStack(spacing: 8) {
                ForEach(Array(quickAddAmounts.enumerated()), id: \.offset) { _, amount in
                    quickAddButton(
                        "+\(WaterAmountFormatter.string(from: amount, unit: waterVolumeUnit))"
                    ) {
                        Task { await viewModel.addQuickWater(amountInMilliliters: amount) }
                    }
                    .accessibilityLabel(
                        "Add \(WaterAmountFormatter.string(from: amount, unit: waterVolumeUnit)) of water"
                    )
                }

                quickAddButton("Other", isSecondary: true) {
                    isShowingCustomAmount = true
                }
                .accessibilityLabel("Add a custom amount of water")
            }
        }
        .contentFrame()
    }

    private func quickAddButton(
        _ title: String,
        isSecondary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSecondary ? palette.secondary : palette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(palette.controlBackground, in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isSecondary ? palette.divider : palette.accent.opacity(0.24),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
    }

    private var entriesDisclosureHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            Divider()
                .overlay(palette.divider)

            Button {
                withAnimation(.snappy) {
                    isEntriesExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .frame(width: 38, height: 38)
                        .background(palette.accent.opacity(0.11), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(palette.accent.opacity(0.2), lineWidth: 1)
                        }
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        sectionLabel("Today's Entries")

                        Text(entriesSummaryText)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(palette.secondary)
                    }

                    Spacer(minLength: 8)

                    Text(entriesTotalText)
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(palette.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(palette.accent.opacity(0.1), in: Capsule())

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(palette.secondary)
                        .frame(width: 26, height: 26)
                        .background(palette.divider.opacity(0.38), in: Circle())
                        .rotationEffect(.degrees(isEntriesExpanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .padding(14)
                .contentShape(Rectangle())
                .background(
                    palette.controlBackground,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            isEntriesExpanded ? palette.accent.opacity(0.3) : palette.divider,
                            lineWidth: 1
                        )
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Today's entries")
            .accessibilityValue("\(entriesSummaryText), \(entriesTotalText)")
            .accessibilityHint(isEntriesExpanded ? "Collapses today's entries" : "Expands today's entries")
        }
        .contentFrame()
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

                    Text(WaterAmountFormatter.string(from: entry.amountInMilliliters, unit: waterVolumeUnit))
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(palette.accent)

                    ZStack(alignment: .trailing) {
                        Button {
                            withAnimation(.snappy) {
                                entryOptionsID = entryOptionsID == entry.id ? nil : entry.id
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(palette.secondary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Entry options")
                    }
                    .anchorPreference(
                        key: TodayEntryOptionsAnchorKey.self,
                        value: .bounds
                    ) {
                        [entry.id: $0]
                    }
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
        .contentFrame()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(WaterAmountFormatter.string(from: entry.amountInMilliliters, unit: waterVolumeUnit)), "
                + "\(sourceName(for: entry))"
        )
        .accessibilityValue(entry.date.formatted(date: .omitted, time: .shortened))
    }

    private func entryOptionsOverlay(
        anchors: [UUID: Anchor<CGRect>]
    ) -> some View {
        GeometryReader { proxy in
            if let entryOptionsID,
               let anchor = anchors[entryOptionsID],
               let entry = viewModel.entries.first(where: { $0.id == entryOptionsID }) {
                let buttonFrame = proxy[anchor]

                ZStack {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.snappy) {
                                self.entryOptionsID = nil
                            }
                        }

                    deleteEntryMenu(for: entry)
                        .position(
                            x: buttonFrame.minX - 8 - 75,
                            y: buttonFrame.midY
                        )
                        .transition(.scale(scale: 0.9, anchor: .trailing).combined(with: .opacity))
                }
            }
        }
    }

    private func deleteEntryMenu(for entry: HydrationEntry) -> some View {
        Button(role: .destructive) {
            delete(entry)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 18, height: 18, alignment: .center)

                Text("Delete Entry")
                    .font(.system(size: 13, weight: .semibold))
            }
                .foregroundStyle(.red)
                .frame(width: 150, height: 48, alignment: .center)
                .contentShape(Rectangle())
                .background(
                    palette.controlBackground,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(palette.divider.opacity(0.55), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            TodayEntryMenuArrow()
                .fill(palette.controlBackground)
                .frame(width: 9, height: 18)
                .offset(x: 8)
        }
        .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
        .accessibilityLabel("Delete entry")
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "drop")
                .font(.system(size: 25, weight: .light))
                .foregroundStyle(palette.accent)

            Text("No water logged yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.primary)

            Text("Use a quick-add button or enter a custom amount to get started.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(palette.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .contentFrame()
        .accessibilityElement(children: .combine)
    }

    private var loadingOverlay: some View {
        ProgressView("Loading today’s hydration…")
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

    private var normalizedProgress: Double {
        min(max(viewModel.progress.completionPercentage / 100, 0), 1)
    }

    private var percentageText: String {
        "\(Int(viewModel.progress.completionPercentage.rounded()))%"
    }

    private var statusText: String {
        if viewModel.progress.hasReachedGoal {
            return "Daily goal reached"
        }

        switch viewModel.progress.completionPercentage {
        case ...0:
            return "Ready When You Are"
        case ...25:
            return "A Good Start"
        case ...60:
            return "Finding Your Flow"
        case ...85:
            return "Keeping the Flow"
        default:
            return "Almost There"
        }
    }

    private var primaryAmountText: String {
        switch waterVolumeUnit {
        case .metric:
            let liters = viewModel.progress.consumedAmount / 1_000
            return "\(liters.formatted(.number.grouping(.never).precision(.fractionLength(2)))) L"
        case .fluidOunces:
            return WaterAmountFormatter.string(
                from: viewModel.progress.consumedAmount,
                unit: waterVolumeUnit
            )
        }
    }

    private var goalAmountText: String {
        WaterAmountFormatter.string(from: viewModel.progress.dailyGoal, unit: waterVolumeUnit)
    }

    private var remainingText: String {
        if viewModel.progress.hasReachedGoal {
            return "Goal complete"
        }

        return "\(WaterAmountFormatter.string(from: viewModel.progress.remainingAmount, unit: waterVolumeUnit)) remaining"
    }

    private var entriesTotalText: String {
        switch waterVolumeUnit {
        case .metric:
            return "\(viewModel.progress.consumedAmount.formatted(.number.grouping(.never).precision(.fractionLength(0)))) ml"
        case .fluidOunces:
            return WaterAmountFormatter.string(
                from: viewModel.progress.consumedAmount,
                unit: waterVolumeUnit
            )
        }
    }

    private var entriesSummaryText: String {
        switch viewModel.entries.count {
        case 0:
            return "No entries logged"
        case 1:
            return "1 entry logged"
        default:
            return "\(viewModel.entries.count) entries logged"
        }
    }

    private var progressAccessibilityValue: String {
        "\(primaryAmountText) consumed of \(goalAmountText), \(remainingText), \(percentageText)"
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: viewModel.displayedDate)

        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<18:
            return "Good afternoon"
        default:
            return "Good evening"
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
        default:
            return "Added water"
        }
    }

    private func delete(_ entry: HydrationEntry) {
        entryOptionsID = nil
        guard let index = viewModel.entries.firstIndex(where: { $0.id == entry.id }) else { return }
        Task { await viewModel.deleteEntries(at: IndexSet(integer: index)) }
    }

    private var palette: TodayPalette {
        TodayPalette(colorScheme: colorScheme)
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

private struct TodayEntryMenuArrow: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: 0, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct TodayEntryOptionsAnchorKey: PreferenceKey {
    static var defaultValue: [UUID: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [UUID: Anchor<CGRect>],
        nextValue: () -> [UUID: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

private struct TodayPalette {
    let background: Color
    let controlBackground: Color
    let meterTrack: Color
    let primary: Color
    let secondary: Color
    let divider: Color
    let accent: Color
    let success: Color

    init(colorScheme: ColorScheme) {
        if colorScheme == .dark {
            background = Color(red: 0.025, green: 0.075, blue: 0.12)
            controlBackground = Color(red: 0.035, green: 0.12, blue: 0.18)
            meterTrack = Color(red: 0.045, green: 0.12, blue: 0.20)
            primary = Color(red: 0.81, green: 0.91, blue: 0.96)
            secondary = Color(red: 0.30, green: 0.55, blue: 0.68)
            divider = Color(red: 0.10, green: 0.25, blue: 0.34)
            accent = Color(red: 0.05, green: 0.78, blue: 0.94)
            success = Color(red: 0.30, green: 0.82, blue: 0.58)
        } else {
            background = Color(red: 0.95, green: 0.98, blue: 0.99)
            controlBackground = Color.white.opacity(0.82)
            meterTrack = Color(red: 0.86, green: 0.92, blue: 0.95)
            primary = Color(red: 0.05, green: 0.16, blue: 0.22)
            secondary = Color(red: 0.27, green: 0.47, blue: 0.57)
            divider = Color(red: 0.76, green: 0.86, blue: 0.90)
            accent = Color(red: 0.00, green: 0.56, blue: 0.76)
            success = Color(red: 0.08, green: 0.58, blue: 0.36)
        }
    }
}

private struct TodayListRowModifier: ViewModifier {
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
    func todayListRow(top: CGFloat, bottom: CGFloat) -> some View {
        modifier(TodayListRowModifier(top: top, bottom: bottom))
    }

    func contentFrame() -> some View {
        frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
