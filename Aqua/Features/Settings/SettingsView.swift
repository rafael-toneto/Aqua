import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(goalService: any HydrationGoalServiceProtocol) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(goalService: goalService))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Daily goal", text: $viewModel.goalText)
                            .keyboardType(.numberPad)
                            .accessibilityLabel("Daily water goal in milliliters")

                        Text("ml")
                            .foregroundStyle(.secondary)
                    }

                    Button("Save Goal") {
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
