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
