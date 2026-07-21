import Combine
import Foundation

@MainActor
final class AddWaterViewModel: ObservableObject {
    @Published var amountText = ""
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let trackingService: any HydrationTrackingServiceProtocol
    private let dateProvider: any DateProviding

    init(
        trackingService: any HydrationTrackingServiceProtocol,
        dateProvider: any DateProviding
    ) {
        self.trackingService = trackingService
        self.dateProvider = dateProvider
    }

    var amountInMilliliters: Double? {
        let trimmedText = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Int(trimmedText), amount > 0 else {
            return nil
        }
        return Double(amount)
    }

    var canSave: Bool {
        amountInMilliliters != nil && !isSaving
    }

    func save() async -> Bool {
        guard let amountInMilliliters else {
            errorMessage = HydrationError.invalidAmount.localizedDescription
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await trackingService.addWater(
                amountInMilliliters: amountInMilliliters,
                date: dateProvider.now,
                source: .manual
            )
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
