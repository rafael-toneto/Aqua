import SwiftUI

struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isGoalFieldFocused: Bool
    @StateObject private var viewModel: OnboardingViewModel

    private let onComplete: () -> Void
    private let calendar = Calendar.autoupdatingCurrent

    init(
        goalService: any HydrationGoalServiceProtocol,
        planningPreferencesStore: any PlanningPreferencesStoring,
        volumeUnit: WaterVolumeUnit,
        onComplete: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: OnboardingViewModel(
                goalService: goalService,
                planningPreferencesStore: planningPreferencesStore,
                volumeUnit: volumeUnit
            )
        )
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            decorativeBackground

            VStack(spacing: 0) {
                topBar

                TabView(selection: stepBinding) {
                    welcomeStep.tag(OnboardingViewModel.Step.welcome)
                    overviewStep.tag(OnboardingViewModel.Step.overview)
                    goalStep.tag(OnboardingViewModel.Step.goal)
                    planStep.tag(OnboardingViewModel.Step.plan)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomBar
            }
            .frame(maxWidth: 720)
        }
        .tint(palette.accent)
        .animation(.easeInOut(duration: 0.28), value: viewModel.step)
        .sensoryFeedback(.selection, trigger: viewModel.step)
        .onTapGesture {
            isGoalFieldFocused = false
        }
        .onChange(of: viewModel.step) { _, newStep in
            isGoalFieldFocused = false

            if newStep == .goal {
                Task { @MainActor in
                    isGoalFieldFocused = true
                }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image("aquaFlowLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                Text(AppBrand.displayName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.primary)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            Text("\(viewModel.step.rawValue + 1) of \(OnboardingViewModel.Step.allCases.count)")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(palette.secondary)

            Button("Skip") {
                isGoalFieldFocused = false
                onComplete()
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(palette.accent)
            .padding(.horizontal, 13)
            .frame(minHeight: 36)
            .background(palette.accent.opacity(0.1), in: Capsule())
            .accessibilityHint("Uses the app’s current default settings and opens AquaFlow")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var welcomeStep: some View {
        onboardingScrollView {
            VStack(spacing: 28) {
                waterHero

                VStack(spacing: 12) {
                    Text("Meet AquaFlow")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(palette.primary)

                    Text("A calmer way to build a steady hydration rhythm.")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .multilineTextAlignment(.center)

                    Text("Water supports how you feel throughout the day. AquaFlow makes it simple to set a goal, log each drink, and keep moving at your own pace.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(palette.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 470)
                }

                HStack(spacing: 8) {
                    welcomePill("Simple", icon: "hand.tap.fill")
                    welcomePill("Flexible", icon: "arrow.triangle.2.circlepath")
                    welcomePill("Private", icon: "iphone")
                }
            }
        }
    }

    private var overviewStep: some View {
        onboardingScrollView {
            VStack(alignment: .leading, spacing: 22) {
                stepHeading(
                    eyebrow: "YOUR DAY IN AQUAFLOW",
                    title: "A clear view of your hydration",
                    message: "Log quickly, follow your progress, and let AquaFlow turn your entries into a useful picture of your routine."
                )

                hydrationPreview

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    featureCard(
                        title: "Today",
                        message: "Log water in a tap.",
                        icon: "drop.fill"
                    )
                    featureCard(
                        title: "History",
                        message: "Review days and entries.",
                        icon: "chart.bar.fill"
                    )
                    featureCard(
                        title: "Plan",
                        message: "Use flexible checkpoints.",
                        icon: "list.bullet.clipboard"
                    )
                    featureCard(
                        title: "Insights",
                        message: "Notice recent patterns.",
                        icon: "sparkles"
                    )
                }
            }
        }
    }

    private var goalStep: some View {
        onboardingScrollView {
            VStack(alignment: .leading, spacing: 22) {
                stepHeading(
                    eyebrow: "YOUR DAILY TARGET",
                    title: "Choose a goal that feels right",
                    message: "Type a daily target to continue. AquaFlow uses it to show progress and shape your plan, and you can change it later in Settings."
                )

                goalCard

                infoNote(
                    "AquaFlow supports healthy hydration habits but does not provide medical advice."
                )
            }
        }
    }

    private var planStep: some View {
        onboardingScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepHeading(
                    eyebrow: "YOUR HYDRATION RHYTHM",
                    title: "Make the plan fit your day",
                    message: "Set your active hours and a comfortable checkpoint cadence. AquaFlow keeps the schedule flexible as you log water."
                )

                onboardingSection(title: "Active day", icon: "sun.horizon.fill") {
                    onboardingTimeRow(
                        title: "Start time",
                        icon: "sunrise.fill",
                        selection: startTimeBinding
                    )

                    onboardingDivider

                    onboardingTimeRow(
                        title: "End time",
                        icon: "moon.stars.fill",
                        selection: endTimeBinding
                    )
                }

                onboardingSection(title: "Checkpoints", icon: "clock.fill") {
                    onboardingStepperRow(
                        title: "Per active period",
                        value: "\(viewModel.preferredCheckpointsPerPeriod)",
                        icon: "list.number",
                        selection: checkpointsBinding,
                        range: 1...4,
                        step: 1
                    )

                    onboardingDivider

                    onboardingStepperRow(
                        title: "Minimum interval",
                        value: "\(viewModel.planningPreferences.minimumIntervalMinutes) min",
                        icon: "timer",
                        selection: intervalBinding,
                        range: 15...240,
                        step: 15
                    )

                    onboardingDivider

                    onboardingStepperRow(
                        title: "Default amount",
                        value: WaterAmountFormatter.preciseString(
                            from: Double(
                                viewModel.planningPreferences.preferredAmountMilliliters
                            ),
                            unit: viewModel.volumeUnit
                        ),
                        icon: "drop.fill",
                        selection: amountBinding,
                        range: 50...10_000,
                        step: 50
                    )
                }

                infoNote(
                    "These are preferences, not rigid reminders. You can fine-tune them anytime from Plan Settings."
                )

                if let errorMessage = viewModel.errorMessage {
                    errorCard(errorMessage)
                }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            HStack(spacing: 7) {
                ForEach(OnboardingViewModel.Step.allCases) { step in
                    Capsule()
                        .fill(step == viewModel.step ? palette.accent : palette.divider)
                        .frame(width: step == viewModel.step ? 24 : 7, height: 7)
                }
            }
            .accessibilityHidden(true)

            HStack(spacing: 12) {
                if viewModel.step != .welcome {
                    Button {
                        viewModel.moveBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 48, height: 50)
                            .foregroundStyle(palette.secondary)
                            .background(
                                palette.controlBackground,
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(palette.divider, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Previous step")
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }

                Button(action: primaryAction) {
                    HStack(spacing: 8) {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(palette.prominentButtonForeground)
                        } else {
                            Text(viewModel.isLastStep ? "Start with AquaFlow" : "Continue")
                            Image(
                                systemName: viewModel.isLastStep
                                    ? "checkmark"
                                    : "arrow.right"
                            )
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(palette.prominentButtonForeground)
                    .background(
                        palette.accent,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canContinue || viewModel.isSaving)
                .opacity(!viewModel.canContinue || viewModel.isSaving ? 0.45 : 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private var waterHero: some View {
        ZStack {
            Circle()
                .fill(palette.accent.opacity(0.07))
                .frame(width: 250, height: 250)

            Circle()
                .stroke(palette.accent.opacity(0.14), lineWidth: 1)
                .frame(width: 210, height: 210)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [palette.accent.opacity(0.24), palette.accent.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 168, height: 168)
                .overlay {
                    Circle()
                        .stroke(palette.accent.opacity(0.3), lineWidth: 1)
                }

            Image("aquaFlowLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 142, height: 142)

            Image(systemName: "sparkle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(palette.accent)
                .offset(x: 78, y: -72)

            Image(systemName: "sparkle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.accent.opacity(0.7))
                .offset(x: -82, y: 62)
        }
        .accessibilityHidden(true)
    }

    private var hydrationPreview: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(palette.secondary)

                    Text("1.25 L")
                        .font(.system(size: 34, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(palette.primary)

                    Text("of 2 L")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.secondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(palette.meterTrack, lineWidth: 11)
                    Circle()
                        .trim(from: 0, to: 0.62)
                        .stroke(
                            palette.accent,
                            style: StrokeStyle(lineWidth: 11, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Text("62%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(palette.primary)
                }
                .frame(width: 86, height: 86)
            }

            HStack(spacing: 9) {
                previewQuickAdd("+200 ml")
                previewQuickAdd("+300 ml")
                previewQuickAdd("+500 ml")
            }
        }
        .padding(20)
        .background(
            palette.controlBackground,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(palette.divider, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.12 : 0.04), radius: 18, y: 9)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Example Today card showing sixty-two percent of a daily goal")
    }

    private var goalCard: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(palette.meterTrack, lineWidth: 9)
                Circle()
                    .trim(from: 0, to: 0.72)
                    .stroke(
                        palette.accent,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Image(systemName: "target")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 92, height: 92)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("DAILY WATER GOAL")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(palette.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    TextField("0", text: $viewModel.goalText)
                        .keyboardType(.decimalPad)
                        .focused($isGoalFieldFocused)
                        .font(.system(size: 38, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(palette.primary)
                        .tint(palette.accent)
                        .accessibilityLabel(
                            "Daily goal in \(viewModel.volumeUnit.accessibilityDescription)"
                        )

                    Text(viewModel.volumeUnit.symbol)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(palette.accent)
                }

                Divider().overlay(palette.divider)

                Text("Enter the amount using \(viewModel.volumeUnit.symbol).")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(palette.secondary)
            }

            if let errorMessage = viewModel.errorMessage {
                errorCard(errorMessage)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            palette.controlBackground,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(palette.divider, lineWidth: 1)
        }
    }

    private var decorativeBackground: some View {
        GeometryReader { proxy in
            Circle()
                .fill(palette.accent.opacity(colorScheme == .dark ? 0.055 : 0.07))
                .frame(width: min(proxy.size.width * 0.9, 620))
                .blur(radius: 2)
                .offset(x: proxy.size.width * 0.48, y: -proxy.size.width * 0.5)

            Circle()
                .fill(palette.accent.opacity(colorScheme == .dark ? 0.035 : 0.045))
                .frame(width: min(proxy.size.width * 0.65, 420))
                .offset(x: -proxy.size.width * 0.35, y: proxy.size.height * 0.7)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func onboardingScrollView<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            content()
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 30)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
    }

    private func stepHeading(
        eyebrow: String,
        title: String,
        message: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.35)
                .foregroundStyle(palette.accent)

            Text(title)
                .font(.system(size: 29, weight: .bold))
                .foregroundStyle(palette.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(palette.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func welcomePill(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(palette.secondary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(minHeight: 34)
            .background(palette.controlBackground, in: Capsule())
            .overlay { Capsule().stroke(palette.divider, lineWidth: 1) }
    }

    private func featureCard(title: String, message: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 42, height: 42)
                .background(palette.accent.opacity(0.11), in: Circle())

            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(palette.primary)

            Text(message)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(
            palette.controlBackground,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(palette.divider, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func previewQuickAdd(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(palette.accent)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(palette.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
    }

    private func onboardingSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title.uppercased(), systemImage: icon)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(palette.secondary)

            VStack(spacing: 0) {
                content()
            }
            .background(
                palette.controlBackground,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(palette.divider, lineWidth: 1)
            }
        }
    }

    private func onboardingTimeRow(
        title: String,
        icon: String,
        selection: Binding<Date>
    ) -> some View {
        HStack(spacing: 12) {
            onboardingRowIcon(icon)
            DatePicker(title, selection: selection, displayedComponents: .hourAndMinute)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.primary)
        }
        .padding(14)
    }

    private func onboardingStepperRow(
        title: String,
        value: String,
        icon: String,
        selection: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int
    ) -> some View {
        HStack(spacing: 12) {
            onboardingRowIcon(icon)

            Stepper(value: selection, in: range, step: step) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.primary)

                    Text(value)
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(palette.accent)
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(14)
    }

    private func onboardingRowIcon(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(palette.accent)
            .frame(width: 34, height: 34)
            .background(palette.accent.opacity(0.11), in: Circle())
            .accessibilityHidden(true)
    }

    private var onboardingDivider: some View {
        Divider()
            .overlay(palette.divider)
            .padding(.leading, 60)
    }

    private func infoNote(_ message: String) -> some View {
        Label(message, systemImage: "info.circle.fill")
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(palette.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(palette.accent.opacity(0.18), lineWidth: 1)
            }
    }

    private func errorCard(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(palette.danger)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.danger.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityLabel("Error: \(message)")
    }

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: {
                timeDate(minutes: viewModel.planningPreferences.activeDayStartMinutes)
            },
            set: { viewModel.updateActiveDayStart(minutes: minutes(from: $0)) }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: {
                timeDate(minutes: viewModel.planningPreferences.activeDayEndMinutes)
            },
            set: { viewModel.updateActiveDayEnd(minutes: minutes(from: $0)) }
        )
    }

    private var checkpointsBinding: Binding<Int> {
        Binding(
            get: { viewModel.preferredCheckpointsPerPeriod },
            set: viewModel.updatePreferredCheckpointsPerPeriod
        )
    }

    private var intervalBinding: Binding<Int> {
        Binding(
            get: { viewModel.planningPreferences.minimumIntervalMinutes },
            set: viewModel.updateMinimumInterval
        )
    }

    private var amountBinding: Binding<Int> {
        Binding(
            get: { viewModel.planningPreferences.preferredAmountMilliliters },
            set: viewModel.updatePreferredAmount
        )
    }

    private var stepBinding: Binding<OnboardingViewModel.Step> {
        Binding(get: { viewModel.step }, set: viewModel.move(to:))
    }

    private func timeDate(minutes: Int) -> Date {
        let start = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        return calendar.date(byAdding: .minute, value: minutes, to: start) ?? start
    }

    private func minutes(from date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func primaryAction() {
        isGoalFieldFocused = false
        if viewModel.isLastStep {
            if viewModel.finish() {
                onComplete()
            }
        } else {
            viewModel.moveForward()
        }
    }

    private var palette: AquaPalette {
        AquaPalette(colorScheme: colorScheme)
    }
}
