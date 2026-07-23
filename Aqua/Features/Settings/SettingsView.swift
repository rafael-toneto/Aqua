import SwiftUI

struct SettingsView: View {
    private enum EditableValue: Identifiable {
        case dailyGoal
        case quickAddAmount(Int)

        var id: String {
            switch self {
            case .dailyGoal:
                "daily-goal"
            case .quickAddAmount(let index):
                "quick-add-\(index)"
            }
        }
    }

    @StateObject private var viewModel: SettingsViewModel
    @State private var editableValue: EditableValue?

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
            List {
                Section {
                    Button {
                        viewModel.toggleVolumeDisplayUnit()
                    } label: {
                        HStack(spacing: AquaSpacing.medium) {
                            Image(systemName: "ruler")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.blue)
                                .frame(width: 28)
                                .accessibilityHidden(true)

                            Text("Measurement Unit")
                                .foregroundStyle(.primary)

                            Spacer(minLength: AquaSpacing.small)

                            Text(viewModel.volumeDisplayUnit.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Image(systemName: "arrow.left.arrow.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.blue)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Measurement unit")
                    .accessibilityValue(viewModel.volumeDisplayUnit.accessibilityDescription)
                    .accessibilityHint("Switches between liters and milliliters, and fluid ounces")
                } header: {
                    Text("Units")
                } footer: {
                    Text("Tap to switch how water amounts are displayed and entered.")
                }

                Section {
                    editableSettingRow(
                        title: "Daily goal",
                        value: viewModel.formattedAmount(from: viewModel.savedGoalInMilliliters),
                        systemImage: "target",
                        accessibilityHint: "Sets the amount of water you aim to drink each day"
                    ) {
                        editableValue = .dailyGoal
                    }

                    if let errorMessage = viewModel.errorMessage {
                        AquaErrorMessage(message: errorMessage)
                    }
                } header: {
                    Text("Daily Water Goal")
                } footer: {
                    Text("Your goal is stored on this device. Changing it also updates today’s plan.")
                }

                Section {
                    ForEach(viewModel.savedQuickAddAmountsInMilliliters.indices, id: \.self) { index in
                        editableSettingRow(
                            title: "Slot \(index + 1)",
                            value: viewModel.formattedAmount(
                                from: viewModel.savedQuickAddAmountsInMilliliters[index]
                            ),
                            systemImage: "drop.fill",
                            accessibilityHint: "Sets the amount added by quick-add slot \(index + 1)"
                        ) {
                            editableValue = .quickAddAmount(index)
                        }
                    }

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
                    comingLaterRow("Intelligent insights", systemImage: "sparkles")
                    comingLaterRow("HealthKit", systemImage: "heart.fill")
                } header: {
                    Text("Coming Later")
                } footer: {
                    Text("These features are informational only and are not active in this version.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .onAppear { viewModel.load() }
            .sheet(item: $editableValue) { value in
                editor(for: value)
            }
            .sensoryFeedback(.success, trigger: viewModel.feedbackTrigger)
        }
    }

    private func editableSettingRow(
        title: String,
        value: String,
        systemImage: String,
        accessibilityHint: String,
        edit: @escaping () -> Void
    ) -> some View {
        HStack(spacing: AquaSpacing.medium) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 28)
                .accessibilityHidden(true)

            Text(title)

            Spacer(minLength: AquaSpacing.small)

            Text(value)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())

            Button(action: edit) {
                Image(systemName: "pencil")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .background(.blue.opacity(0.12), in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .accessibilityLabel("Edit \(title)")
            .accessibilityValue(value)
            .accessibilityHint(accessibilityHint)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func editor(for value: EditableValue) -> some View {
        switch value {
        case .dailyGoal:
            AmountEditorSheet(
                title: "Edit Daily Goal",
                fieldLabel: "Daily water goal",
                initialValue: viewModel.editorText(from: viewModel.savedGoalInMilliliters),
                unitSymbol: viewModel.volumeDisplayUnit.symbol,
                systemImage: "target",
                footer: "Enter an amount greater than zero.",
                accessibilityLabel: "Daily water goal in \(viewModel.volumeDisplayUnit.accessibilityDescription)"
            ) { newValue in
                viewModel.goalText = newValue
                viewModel.save()
                return viewModel.errorMessage
            }

        case .quickAddAmount(let index):
            AmountEditorSheet(
                title: "Edit Slot \(index + 1)",
                fieldLabel: "Quick-add amount",
                initialValue: viewModel.editorText(
                    from: viewModel.savedQuickAddAmountsInMilliliters[index]
                ),
                unitSymbol: viewModel.volumeDisplayUnit.symbol,
                systemImage: "drop.fill",
                footer: "Enter an amount greater than zero.",
                accessibilityLabel: "Quick-add slot \(index + 1) in \(viewModel.volumeDisplayUnit.accessibilityDescription)"
            ) { newValue in
                viewModel.saveQuickAddAmount(newValue, at: index)
                return viewModel.quickAddErrorMessage
            }
        }
    }

    private func comingLaterRow(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .foregroundStyle(.secondary)
            .accessibilityLabel("\(title), coming later")
    }
}

private struct AmountEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isAmountFieldFocused: Bool

    @State private var amountText: String
    @State private var errorMessage: String?

    private let title: String
    private let fieldLabel: String
    private let initialValue: String
    private let unitSymbol: String
    private let systemImage: String
    private let footer: String
    private let accessibilityLabel: String
    private let onSave: (String) -> String?

    init(
        title: String,
        fieldLabel: String,
        initialValue: String,
        unitSymbol: String,
        systemImage: String,
        footer: String,
        accessibilityLabel: String,
        onSave: @escaping (String) -> String?
    ) {
        self.title = title
        self.fieldLabel = fieldLabel
        self.initialValue = initialValue
        self.unitSymbol = unitSymbol
        self.systemImage = systemImage
        self.footer = footer
        self.accessibilityLabel = accessibilityLabel
        self.onSave = onSave
        _amountText = State(initialValue: initialValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: AquaSpacing.medium) {
                        Image(systemName: systemImage)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.blue)
                            .frame(width: 28)
                            .accessibilityHidden(true)

                        TextField(fieldLabel, text: $amountText)
                            .keyboardType(.decimalPad)
                            .focused($isAmountFieldFocused)
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                            .accessibilityLabel(accessibilityLabel)

                        Text(unitSymbol)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, AquaSpacing.extraSmall)
                } footer: {
                    Text(footer)
                }

                if let errorMessage {
                    Section {
                        AquaErrorMessage(message: errorMessage)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear { isAmountFieldFocused = true }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var parsedAmount: Double? {
        let trimmedText = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedText = trimmedText.replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(normalizedText), amount.isFinite, amount > 0 else { return nil }
        return amount
    }

    private var canSave: Bool {
        guard let parsedAmount,
              let initialAmount = Double(initialValue.replacingOccurrences(of: ",", with: ".")) else {
            return false
        }
        return parsedAmount != initialAmount
    }

    private func save() {
        guard parsedAmount != nil else { return }
        errorMessage = onSave(amountText.trimmingCharacters(in: .whitespacesAndNewlines))

        if errorMessage == nil {
            dismiss()
        }
    }
}
