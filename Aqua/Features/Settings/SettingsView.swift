import SwiftUI

struct SettingsView: View {
    private enum FocusedField: Hashable {
        case dailyGoal
        case quickAddAmount(Int)
    }

    @StateObject private var viewModel: SettingsViewModel
    @FocusState private var focusedField: FocusedField?

    init(
        goalService: any HydrationGoalServiceProtocol,
        quickAddAmountsService: any QuickAddAmountsServiceProtocol
    ) {
        _viewModel = StateObject(
            wrappedValue: SettingsViewModel(
                goalService: goalService,
                quickAddAmountsService: quickAddAmountsService
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Daily goal", text: $viewModel.goalText)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .dailyGoal)
                            .accessibilityLabel("Daily water goal in milliliters")

                        Text("ml")
                            .foregroundStyle(.secondary)
                    }

                    Button("Save Goal") {
                        focusedField = nil
                        viewModel.save()
                    }
                    .disabled(!viewModel.canSave)

                    if let errorMessage = viewModel.errorMessage {
                        AquaErrorMessage(message: errorMessage)
                    }
                } header: {
                    Text("Daily Water Goal")
                } footer: {
                    Text("Your goal is stored on this device and can be changed at any time.")
                }

                Section {
                    ForEach(viewModel.quickAddAmountTexts.indices, id: \.self) { index in
                        HStack {
                            Text("Slot \(index + 1)")

                            Spacer()

                            TextField(
                                "Amount",
                                text: $viewModel.quickAddAmountTexts[index]
                            )
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .quickAddAmount(index))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                            .accessibilityLabel("Quick-add slotem  \(index + 1) in milliliters")

                            Text("ml")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("Save Quick Add Amounts") {
                        focusedField = nil
                        viewModel.saveQuickAddAmounts()
                    }
                    .disabled(!viewModel.canSaveQuickAddAmounts)

                    if let errorMessage = viewModel.quickAddErrorMessage {
                        AquaErrorMessage(message: errorMessage)
                    }
                } header: {
                    Text("Quick Add Amounts")
                } footer: {
                    Text("Choose the three amounts shown on the Today screen. These values are stored on this device.")
                }

                Section("About") {
                    Label(
                        "\(AppBrand.displayName) supports healthy hydration habits but does not provide medical advice.",
                        systemImage: "heart.text.square"
                    )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section {
                    comingLaterRow("Siri and Shortcuts", systemImage: "waveform")
                    comingLaterRow("Intelligent insights", systemImage: "sparkles")
                    comingLaterRow("HealthKit", systemImage: "heart.fill")
                } header: {
                    Text("Coming Later")
                } footer: {
                    Text("These features are informational only and are not active in this version.")
                }
            }
            .onTapGesture {
                focusedField = nil
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Settings")
            .onAppear { viewModel.load() }
            .sensoryFeedback(.success, trigger: viewModel.feedbackTrigger)
        }
    }

    private func comingLaterRow(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .foregroundStyle(.secondary)
            .accessibilityLabel("\(title), coming later")
    }
}
