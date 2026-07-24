import SwiftUI

struct PlanView: View {
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
            Group {
                switch viewModel.state {
                case .loading:
                    VStack(spacing: AquaSpacing.medium) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Preparing today’s plan…")
                            .font(.headline)
                        Text("Your morning, afternoon, and evening goals will appear when today’s plan is ready.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(AquaSpacing.extraLarge)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Plan Unavailable", systemImage: "clock.badge.exclamationmark")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") { viewModel.viewDidAppear() }
                    }
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
            .navigationTitle("Plan")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Plan settings", systemImage: "slider.horizontal.3") {
                        isShowingSettings = true
                    }
                }
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

    private func planContent(
        _ data: PlanViewData,
        outsideActiveHours: Bool,
        completed: Bool = false
    ) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AquaSpacing.large) {
                PlanHeaderView(data: data, outsideActiveHours: outsideActiveHours)

                if let summary = data.plan?.adjustmentSummary,
                   data.plan?.revision ?? 0 > 0 {
                    PlanAdjustmentCard(summary: summary)
                }

                PlanPeriodListView(periods: data.periods)

                if completed {
                    Label("Today’s goal is complete", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AquaSpacing.medium)
                        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: AquaCornerRadius.control))
                }

                Text("Aqua organizes the goal you selected and does not provide medical advice.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, AquaSpacing.extraSmall)
            }
            .padding(.horizontal, AquaSpacing.medium)
            .padding(.bottom, AquaSpacing.extraLarge)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}
