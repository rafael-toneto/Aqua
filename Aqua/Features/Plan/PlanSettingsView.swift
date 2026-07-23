import SwiftUI

struct PlanSettingsView: View {
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
            Form {
                Section("Active Day") {
                    DatePicker(
                        "Start time",
                        selection: timeBinding(for: \PlanningPreferences.activeDayStartMinutes),
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        "End time",
                        selection: timeBinding(for: \PlanningPreferences.activeDayEndMinutes),
                        displayedComponents: .hourAndMinute
                    )
                }

                Section {
                    Stepper(value: $preferences.preferredMomentCount, in: 1...12) {
                        LabeledContent(
                            "Preferred daily moments",
                            value: "\(preferences.preferredMomentCount)"
                        )
                    }
                    Stepper(value: $preferences.minimumIntervalMinutes, in: 15...240, step: 15) {
                        LabeledContent(
                            "Minimum interval",
                            value: "\(preferences.minimumIntervalMinutes) min"
                        )
                    }
                    Stepper(value: $preferences.preferredAmountMilliliters, in: 50...10_000, step: 50) {
                        LabeledContent(
                            "Default amount",
                            value: WaterAmountFormatter.string(
                                from: Double(preferences.preferredAmountMilliliters),
                                unit: waterVolumeUnit
                            )
                        )
                    }
                } header: {
                    Text("Schedule")
                } footer: {
                    Text(
                        "These preferences shape how the daily goal is distributed across the three periods."
                    )
                }

                Section("Adjustments") {
                    adjustmentToggle(
                        title: "Automatic redistribution",
                        description: "Adjusts later period goals when an earlier period finishes below its goal or goes above it.",
                        isOn: $preferences.automaticRedistributionEnabled
                    )
                    adjustmentToggle(
                        title: "May add new moments",
                        description: "Allows an updated plan to add moments when more are needed to organize the remaining goal.",
                        isOn: $preferences.mayAddMoments
                    )
                }

                Section {
                    Label(
                        "Aqua organizes the goal you selected and does not provide medical advice.",
                        systemImage: "info.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section { AquaErrorMessage(message: errorMessage) }
                }
            }
            .navigationTitle("Plan Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .fontWeight(.semibold)
                        .disabled(preferences == initialPreferences || !preferences.isValid)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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

    private func adjustmentToggle(
        title: String,
        description: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: AquaSpacing.extraSmall) {
                Text(title)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, AquaSpacing.extraSmall)
        }
        .accessibilityHint(description)
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
