import SwiftUI

struct AddWaterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isAmountFieldFocused: Bool
    @StateObject private var viewModel: AddWaterViewModel

    private let onSaved: @MainActor () async -> Void

    init(
        trackingService: any HydrationTrackingServiceProtocol,
        dateProvider: any DateProviding,
        waterVolumeUnit: WaterVolumeUnit,
        onSaved: @escaping @MainActor () async -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: AddWaterViewModel(
                trackingService: trackingService,
                dateProvider: dateProvider,
                waterVolumeUnit: waterVolumeUnit
            )
        )
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Amount", text: $viewModel.amountText)
                            .keyboardType(.decimalPad)
                            .focused($isAmountFieldFocused)
                            .font(.title2.weight(.semibold))
                            .accessibilityLabel(
                                "Water amount in \(viewModel.waterVolumeUnit.accessibilityDescription)"
                            )

                        Text(viewModel.waterVolumeUnit.symbol)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Water Amount")
                } footer: {
                    Text("Enter an amount greater than zero.")
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        AquaErrorMessage(message: errorMessage)
                    }
                }
            }
            .navigationTitle("Add Water")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            guard await viewModel.save() else { return }
                            await onSaved()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.canSave)
                }
            }
            .interactiveDismissDisabled(viewModel.isSaving)
            .onAppear { isAmountFieldFocused = true }
        }
        .presentationDetents([.medium])
    }
}
