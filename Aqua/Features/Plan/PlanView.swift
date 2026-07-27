import SwiftUI

struct PlanView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: PlanViewModel
    @State private var isShowingSettings = false
    @State private var isVisible = false

    init(
        adaptivePlanService: AdaptivePlanService,
        goalService: any HydrationGoalServiceProtocol,
        trackingService: any HydrationTrackingServiceProtocol,
        dateProvider: any DateProviding
    ) {
        _viewModel = StateObject(
            wrappedValue: PlanViewModel(
                service: adaptivePlanService,
                goalService: goalService,
                trackingService: trackingService,
                dateProvider: dateProvider
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    pageHeader
                        .padding(.bottom, 20)

                    stateContent
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, AquaSpacing.extraLarge)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(palette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                await viewModel.refresh()
            }
            .onAppear {
                isVisible = true
                viewModel.viewDidAppear()
            }
            .onDisappear {
                isVisible = false
                viewModel.viewDidDisappear()
            }
            .onChange(of: scenePhase) { _, phase in
                guard isVisible, phase == .active else { return }
                viewModel.requestRefresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .hydrationPlanDidChange)) { _ in
                guard isVisible else { return }
                viewModel.requestRefresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .hydrationGoalDidChange)) { _ in
                guard isVisible else { return }
                viewModel.dailyGoalDidChange()
            }
            .sheet(isPresented: $isShowingSettings) {
                PlanSettingsView(
                    initialPreferences: viewModel.planningPreferences,
                    save: viewModel.updatePreferences
                )
            }
            .sensoryFeedback(.success, trigger: viewModel.feedbackTrigger)
            .alert("Unable to Update Plan", isPresented: errorAlertBinding) {
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
                Text("Plan")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(palette.primary)

                Spacer(minLength: 12)

                Button {
                    isShowingSettings = true
                } label: {
                    Label("Settings", systemImage: "slider.horizontal.3")
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
                .accessibilityLabel("Open plan settings")
            }

            Divider()
                .overlay(palette.divider)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch viewModel.state {
        case .loading:
            loadingState
        case .failed(let message):
            failedState(message: message)
        case .empty(let data):
            planContent(data, outsideActiveHours: data.isOutsideActiveHours)
        case .completed(let data):
            planContent(data, outsideActiveHours: false, completed: true)
        case .outsideActiveHours(let data):
            planContent(data, outsideActiveHours: true)
        case .loaded(let data):
            planContent(data, outsideActiveHours: false)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(palette.accent)

            Text("Preparing today’s plan…")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.primary)

            Text("Your morning, afternoon, and evening goals will appear when today’s plan is ready.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(palette.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 320)
        .background(
            palette.controlBackground,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(palette.divider.opacity(0.8), lineWidth: 1)
        }
    }

    private func failedState(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(palette.warning)

            Text("Plan Unavailable")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.primary)

            Text(message)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(palette.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") { viewModel.viewDidAppear() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.background)
                .padding(.horizontal, 20)
                .frame(minHeight: 42)
                .background(palette.accent, in: Capsule())
                .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 320)
        .background(
            palette.controlBackground,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(palette.divider.opacity(0.8), lineWidth: 1)
        }
    }

    private func planContent(
        _ data: PlanViewData,
        outsideActiveHours: Bool,
        completed: Bool = false
    ) -> some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            PlanHeaderView(data: data, outsideActiveHours: outsideActiveHours)

            if let summary = data.plan?.adjustmentSummary,
               data.plan?.revision ?? 0 > 0 {
                PlanAdjustmentCard(summary: summary)
            }

            PlanPeriodListView(periods: data.periods)

            if completed {
                Label("Today’s goal is complete", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.success)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        palette.success.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(palette.success.opacity(0.28), lineWidth: 1)
                    }
            }

            Text("Aqua organizes the goal you selected and does not provide medical advice.")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(palette.secondary)
                .padding(.horizontal, AquaSpacing.extraSmall)
                .padding(.top, 4)
        }
    }

    private var palette: PlanPalette {
        PlanPalette(colorScheme: colorScheme)
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}
