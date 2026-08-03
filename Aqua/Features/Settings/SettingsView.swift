import AppIntents
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

    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: SettingsViewModel
    @State private var editableValue: EditableValue?

    init(
        goalService: any HydrationGoalServiceProtocol,
        quickAddAmountsService: any QuickAddAmountsServiceProtocol,
        liveActivityController: any HydrationLiveActivityControlling
    ) {
        _viewModel = StateObject(
            wrappedValue: SettingsViewModel(
                goalService: goalService,
                quickAddAmountsService: quickAddAmountsService,
                liveActivityController: liveActivityController
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    pageHeader
                    unitsSection
                    dailyGoalSection
                    quickAddSection
                    liveActivitySection
                    shortcutsSection
                    aboutSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, AquaSpacing.extraLarge)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(palette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { viewModel.load() }
            .sheet(item: $editableValue) { value in
                editor(for: value)
            }
            .sensoryFeedback(.success, trigger: viewModel.feedbackTrigger)
        }
        .tint(palette.accent)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your hydration")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(palette.secondary)

            Text("Settings")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(palette.primary)

            Divider()
                .overlay(palette.divider)
                .padding(.top, 8)
        }
    }

    private var unitsSection: some View {
        SettingsSection(
            title: "Units",
            footer: "Tap to switch how water amounts are displayed and entered."
        ) {
            Button {
                viewModel.toggleVolumeDisplayUnit()
            } label: {
                HStack(spacing: 12) {
                    rowIcon("ruler")

                    Text("Measurement Unit")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.primary)

                    Spacer(minLength: AquaSpacing.small)

                    Text(viewModel.volumeDisplayUnit.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(palette.accent.opacity(0.1), in: Capsule())
                        .contentTransition(.numericText())

                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(palette.secondary)
                        .frame(width: 28, height: 28)
                        .background(palette.divider.opacity(0.38), in: Circle())
                        .accessibilityHidden(true)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Measurement unit")
            .accessibilityValue(viewModel.volumeDisplayUnit.accessibilityDescription)
            .accessibilityHint("Switches between liters and milliliters, and fluid ounces")
        }
    }

    private var dailyGoalSection: some View {
        SettingsSection(
            title: "Daily Water Goal",
            footer: "Your goal is stored on this device. Changing it also updates today’s plan."
        ) {
            VStack(spacing: 0) {
                editableSettingRow(
                    title: "Daily goal",
                    value: viewModel.formattedAmount(from: viewModel.savedGoalInMilliliters),
                    systemImage: "target",
                    accessibilityHint: "Sets the amount of water you aim to drink each day"
                ) {
                    editableValue = .dailyGoal
                }

                if let errorMessage = viewModel.errorMessage {
                    settingsDivider
                    settingsError(message: errorMessage)
                }
            }
        }
    }

    private var quickAddSection: some View {
        SettingsSection(
            title: "Quick Add Amounts",
            footer: "Choose the three amounts shown on the Today screen. These values are stored on this device."
        ) {
            VStack(spacing: 0) {
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

                    if index != viewModel.savedQuickAddAmountsInMilliliters.indices.last {
                        settingsDivider
                    }
                }

                if let errorMessage = viewModel.quickAddErrorMessage {
                    settingsDivider
                    settingsError(message: errorMessage)
                }
            }
        }
    }

    private var aboutSection: some View {
        SettingsSection(title: "About") {
            HStack(alignment: .top, spacing: 12) {
                rowIcon("heart.text.square")

                Text(
                    "\(AppBrand.displayName) supports healthy hydration habits but does not provide medical advice."
                )
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .accessibilityElement(children: .combine)
        }
    }

    private var liveActivitySection: some View {
        SettingsSection(
            title: "Live Activity",
            footer: viewModel.liveActivitiesAvailable
                ? "Shows today’s water progress on the Lock Screen and Dynamic Island."
                : "Live Activities are currently disabled in iOS Settings for AquaFlow."
        ) {
            Toggle(
                isOn: Binding(
                    get: { viewModel.liveActivitiesEnabled },
                    set: viewModel.setLiveActivitiesEnabled
                )
            ) {
                HStack(spacing: 12) {
                    rowIcon("drop.circle.fill")

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Daily progress")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.primary)

                        Text("Keep your hydration progress visible at a glance")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(palette.secondary)
                    }
                }
            }
            .tint(palette.accent)
            .padding(14)
            .accessibilityLabel("Live Activity for daily hydration progress")
            .accessibilityHint("Shows or hides hydration progress on the Lock Screen and Dynamic Island")
        }
    }

    private var shortcutsSection: some View {
        SettingsSection(
            title: "Shortcuts",
            footer: "Use AquaFlow from Shortcuts or Siri without opening the app."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    rowIcon("square.stack.3d.up.fill")

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Log water automatically")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.primary)

                        Text("Create automations or ask Siri to log an amount, check your progress, or see what remains.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(palette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                ShortcutsLink()
                    .shortcutsLinkStyle(.automaticOutline)
                    .frame(maxWidth: .infinity)
                    .accessibilityHint("Opens AquaFlow actions in the Shortcuts app")
            }
            .padding(14)
        }
    }

    private func editableSettingRow(
        title: String,
        value: String,
        systemImage: String,
        accessibilityHint: String,
        edit: @escaping () -> Void
    ) -> some View {
        Button(action: edit) {
            HStack(spacing: 12) {
                rowIcon(systemImage)

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.primary)

                Spacer(minLength: AquaSpacing.small)

                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.accent)
                    .contentTransition(.numericText())

                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 28, height: 28)
                    .background(palette.accent.opacity(0.11), in: Circle())
                    .accessibilityHidden(true)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit \(title)")
        .accessibilityValue(value)
        .accessibilityHint(accessibilityHint)
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
                footer: "Enter an amount greater than zero and no more than "
                    + "\(viewModel.maximumDailyGoalDescription).",
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
                footer: "Enter an amount greater than zero and no more than "
                    + "\(viewModel.maximumSingleEntryDescription).",
                accessibilityLabel: "Quick-add slot \(index + 1) in \(viewModel.volumeDisplayUnit.accessibilityDescription)"
            ) { newValue in
                viewModel.saveQuickAddAmount(newValue, at: index)
                return viewModel.quickAddErrorMessage
            }
        }
    }

    private func rowIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(palette.accent)
            .frame(width: 34, height: 34)
            .background(palette.accent.opacity(0.11), in: Circle())
            .accessibilityHidden(true)
    }

    private var settingsDivider: some View {
        Divider()
            .overlay(palette.divider)
            .padding(.leading, 60)
    }

    private func settingsError(message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(palette.danger)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Error: \(message)")
    }

    private var palette: SettingsPalette {
        SettingsPalette(colorScheme: colorScheme)
    }
}

private struct AmountEditorSheet: View {
    @Environment(\.colorScheme) private var colorScheme
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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    introduction
                    amountField

                    if let errorMessage {
                        errorCard(errorMessage)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, AquaSpacing.extraLarge)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    toolbarButton(
                        systemImage: "xmark",
                        accessibilityLabel: "Cancel",
                        isEnabled: true
                    ) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    toolbarButton(
                        systemImage: "checkmark",
                        accessibilityLabel: "Save",
                        isEnabled: canSave,
                        action: save
                    )
                }
            }
            .onAppear { isAmountFieldFocused = true }
        }
        .tint(palette.accent)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(palette.background)
    }

    private var introduction: some View {
        HStack(spacing: AquaSpacing.medium) {
            Image(systemName: systemImage)
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
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AquaSpacing.extraSmall) {
                Text(fieldLabel)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(palette.primary)

                Text("Enter the new amount using \(unitSymbol).")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(palette.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(fieldLabel.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.25)
                .foregroundStyle(palette.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFieldFocused)
                    .font(.system(size: 38, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.primary)
                    .tint(palette.accent)
                    .accessibilityLabel(accessibilityLabel)

                Text(unitSymbol)
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

                Text(footer)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(palette.secondary)
            }
            .padding(.leading, AquaSpacing.extraSmall)
        }
    }

    private func errorCard(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(palette.danger)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                palette.danger.opacity(0.09),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(palette.danger.opacity(0.24), lineWidth: 1)
            }
            .accessibilityLabel("Error: \(message)")
    }

    private func toolbarButton(
        systemImage: String,
        accessibilityLabel: String,
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

    private var palette: SettingsPalette {
        SettingsPalette(colorScheme: colorScheme)
    }
}

private struct SettingsSection<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let footer: String?
    let content: Content

    init(
        title: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.15)
                .foregroundStyle(palette.secondary)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    palette.controlBackground,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.divider.opacity(0.8), lineWidth: 1)
                }

            if let footer {
                Text(footer)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(palette.secondary)
                    .padding(.horizontal, AquaSpacing.extraSmall)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var palette: SettingsPalette {
        SettingsPalette(colorScheme: colorScheme)
    }
}
