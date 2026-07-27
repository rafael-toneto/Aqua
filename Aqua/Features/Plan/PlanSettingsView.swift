import SwiftUI

struct PlanSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.waterVolumeUnit) private var waterVolumeUnit
    @State private var preferences: PlanningPreferences
    @State private var errorMessage: String?

    private let initialPreferences: PlanningPreferences
    private let save: (PlanningPreferences) throws -> Void
    private var calendar: Calendar { .autoupdatingCurrent }

    init(
        initialPreferences: PlanningPreferences,
        save: @escaping (PlanningPreferences) throws -> Void
    ) {
        self.initialPreferences = initialPreferences
        self.save = save
        _preferences = State(initialValue: initialPreferences)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    sheetHeader

                    activeDaySection
                    scheduleSection
                    informationCard

                    if let errorMessage {
                        errorCard(errorMessage)
                    }

                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 36)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(palette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationBackground(palette.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var sheetHeader: some View {
        VStack(alignment: .leading, spacing: 14) {

            HStack(alignment: .center, spacing: 16) {
                Text("Plan Settings")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(palette.primary)

                Spacer(minLength: 12)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(palette.secondary)
                        .frame(width: 36, height: 36)
                        .background(palette.controlBackground, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(palette.divider, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel plan settings")
            }

            Divider()
                .overlay(palette.divider)
        }
    }

    private var activeDaySection: some View {
        PlanSettingsSection(
            title: "Active Day",
            systemImage: "sun.horizon.fill"
        ) {
            timeRow(
                title: "Start time",
                systemImage: "sunrise.fill",
                selection: timeBinding(for: \PlanningPreferences.activeDayStartMinutes)
            )

            settingsDivider

            timeRow(
                title: "End time",
                systemImage: "moon.stars.fill",
                selection: timeBinding(for: \PlanningPreferences.activeDayEndMinutes)
            )
        }
    }

    private var scheduleSection: some View {
        PlanSettingsSection(
            title: "Schedule",
            systemImage: "clock.fill",
            footer: "These preferences shape how the daily goal is distributed across the three periods."
        ) {
            stepperRow(
                title: "Preferred daily moments",
                value: "\(preferences.preferredMomentCount)",
                systemImage: "list.number",
                selection: $preferences.preferredMomentCount,
                range: 1...12,
                step: 1
            )

            settingsDivider

            stepperRow(
                title: "Minimum interval",
                value: "\(preferences.minimumIntervalMinutes) min",
                systemImage: "timer",
                selection: $preferences.minimumIntervalMinutes,
                range: 15...240,
                step: 15
            )

            settingsDivider

            stepperRow(
                title: "Default amount",
                value: WaterAmountFormatter.string(
                    from: Double(preferences.preferredAmountMilliliters),
                    unit: waterVolumeUnit
                ),
                systemImage: "drop.fill",
                selection: $preferences.preferredAmountMilliliters,
                range: 50...10_000,
                step: 50
            )
        }
    }

    private func timeRow(
        title: String,
        systemImage: String,
        selection: Binding<Date>
    ) -> some View {
        HStack(spacing: 12) {
            rowIcon(systemImage)

            DatePicker(
                title,
                selection: selection,
                displayedComponents: .hourAndMinute
            )
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(palette.primary)
            .tint(palette.accent)
        }
        .padding(14)
    }

    private func stepperRow(
        title: String,
        value: String,
        systemImage: String,
        selection: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int
    ) -> some View {
        HStack(spacing: 12) {
            rowIcon(systemImage)

            Stepper(value: selection, in: range, step: step) {
                VStack(alignment: .leading, spacing: 4) {
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
            .tint(palette.accent)
        }
        .padding(14)
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

    private var informationCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.accent)
                .padding(.top, 1)
                .accessibilityHidden(true)

            Text("Aqua organizes the goal you selected and does not provide medical advice.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(palette.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            palette.accent.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.accent.opacity(0.2), lineWidth: 1)
        }
    }

    private func errorCard(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(palette.danger)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                palette.danger.opacity(0.09),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(palette.danger.opacity(0.24), lineWidth: 1)
            }
            .accessibilityLabel("Error: \(message)")
    }

    private var saveButton: some View {
        Button(action: saveChanges) {
            Label("Save Changes", systemImage: "checkmark")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(palette.background)
                .background(
                    palette.accent,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(preferences == initialPreferences || !preferences.isValid)
        .opacity(preferences == initialPreferences || !preferences.isValid ? 0.4 : 1)
    }

    private var palette: PlanPalette {
        PlanPalette(colorScheme: colorScheme)
    }

    private func timeBinding(for keyPath: WritableKeyPath<PlanningPreferences, Int>) -> Binding<Date> {
        Binding(
            get: { timeDate(minutes: preferences[keyPath: keyPath]) },
            set: { newDate in
                let components = calendar.dateComponents([.hour, .minute], from: newDate)
                preferences[keyPath: keyPath] = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            }
        )
    }

    private func timeDate(minutes: Int) -> Date {
        let start = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        return calendar.date(byAdding: .minute, value: minutes, to: start) ?? start
    }

    private func saveChanges() {
        do {
            try save(preferences)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PlanSettingsSection<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let systemImage: String
    let footer: String?
    let content: Content

    init(
        title: String,
        systemImage: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title.uppercased(), systemImage: systemImage)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.15)
                .foregroundStyle(palette.secondary)

            VStack(spacing: 0) {
                content
            }
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
                    .padding(.horizontal, 4)
            }
        }
    }

    private var palette: PlanPalette {
        PlanPalette(colorScheme: colorScheme)
    }
}
