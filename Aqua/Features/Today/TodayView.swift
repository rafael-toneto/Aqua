import SwiftUI

struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.waterVolumeUnit) private var waterVolumeUnit
    @StateObject private var viewModel: TodayViewModel
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
                Section {
                    VStack(alignment: .leading, spacing: AquaSpacing.medium) {
                        Text(viewModel.displayedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HydrationProgressView(progress: viewModel.progress)
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Section {
                    QuickAddWaterView(
                        amountsInMilliliters: quickAddAmounts,
                        addWater: { amount in
                            Task { await viewModel.addQuickWater(amountInMilliliters: amount) }
                        },
                        showCustomAmount: { isShowingCustomAmount = true }
                    )
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Section("Today's Entries") {
                    if viewModel.entries.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.entries) { entry in
                            HydrationEntryRow(entry: entry)
                        }
                        .onDelete { offsets in
                            Task { await viewModel.deleteEntries(at: offsets) }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Today")
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading today’s hydration…")
                        .padding(AquaSpacing.large)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AquaCornerRadius.control))
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

    private var emptyState: some View {
        VStack(spacing: AquaSpacing.small) {
            Image(systemName: "drop")
                .font(.title2)
                .foregroundStyle(.blue)
            Text("No water logged yet")
                .font(.headline)
            Text("Use a quick-add button or enter a custom amount to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AquaSpacing.large)
        .accessibilityElement(children: .combine)
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
