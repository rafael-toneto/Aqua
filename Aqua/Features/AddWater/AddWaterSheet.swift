import SwiftUI

struct AddWaterSheet: View {
    @Environment(\.colorScheme) private var colorScheme
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
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    introduction
                    amountField

                    if let errorMessage = viewModel.errorMessage {
                        errorView(errorMessage)
                    }
                }
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Add Water")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    toolbarButton(
                        systemImage: "xmark",
                        accessibilityLabel: "Cancel",
                        isProminent: false,
                        isEnabled: !viewModel.isSaving
                    ) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    toolbarButton(
                        systemImage: "checkmark",
                        accessibilityLabel: "Save",
                        isProminent: true,
                        isEnabled: viewModel.canSave
                    ) {
                        save()
                    }
                }
            }
            .interactiveDismissDisabled(viewModel.isSaving)
            .onAppear { isAmountFieldFocused = true }
        }
        .tint(palette.accent)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(palette.background)
    }

    private var introduction: some View {
        HStack(spacing: 16) {
            Image(systemName: "drop.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(palette.accent)
                .frame(width: 52, height: 52)
                .background(
                    LinearGradient(
                        colors: [palette.accent.opacity(0.22), palette.accent.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .stroke(palette.accent.opacity(0.28), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("Log your water")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(palette.primary)

                Text("Enter the amount you just drank.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(palette.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WATER AMOUNT")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.25)
                .foregroundStyle(palette.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                TextField("0", text: $viewModel.amountText)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFieldFocused)
                    .font(.system(size: 38, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.primary)
                    .tint(palette.accent)
                    .accessibilityLabel(
                        "Water amount in \(viewModel.waterVolumeUnit.accessibilityDescription)"
                    )

                Text(viewModel.waterVolumeUnit.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.secondary)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 76)
            .background(
                palette.controlBackground,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isAmountFieldFocused ? palette.accent.opacity(0.68) : palette.divider,
                        lineWidth: isAmountFieldFocused ? 1.5 : 1
                    )
            }
            .animation(.easeOut(duration: 0.18), value: isAmountFieldFocused)

            HStack(spacing: 7) {
                Circle()
                    .fill(palette.accent)
                    .frame(width: 5, height: 5)

                Text("Enter an amount greater than zero and no more than \(maximumEntryDescription).")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(palette.secondary)
            }
            .padding(.leading, 4)
        }
    }

    private func errorView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(palette.error)
        .padding(14)
        .background(palette.error.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(palette.error.opacity(0.24), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func toolbarButton(
        systemImage: String,
        accessibilityLabel: String,
        isProminent: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }

    private func toolbarIconColor(isProminent: Bool, isEnabled: Bool) -> Color {
        if isProminent {
            return isEnabled ? palette.prominentButtonForeground : palette.secondary.opacity(0.5)
        }
        return palette.secondary
    }

    private func toolbarBackground(isProminent: Bool, isEnabled: Bool) -> Color {
        guard isProminent else { return palette.controlBackground }
        return isEnabled ? palette.accent : palette.controlBackground
    }

    private func save() {
        Task {
            guard await viewModel.save() else { return }
            await onSaved()
            dismiss()
        }
    }

    private var maximumEntryDescription: String {
        WaterAmountFormatter.string(
            from: HydrationLimits.maximumSingleEntryInMilliliters,
            unit: viewModel.waterVolumeUnit
        )
    }

    private var palette: AddWaterPalette {
        AddWaterPalette(colorScheme: colorScheme)
    }
}
