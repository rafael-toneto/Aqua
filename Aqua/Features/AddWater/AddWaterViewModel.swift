import Combine
import Foundation

@MainActor
final class AddWaterViewModel: ObservableObject {
    @Published var amountText = ""
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    let waterVolumeUnit: WaterVolumeUnit

    private let trackingService: any HydrationTrackingServiceProtocol
    private let dateProvider: any DateProviding

    init(
        trackingService: any HydrationTrackingServiceProtocol,
        dateProvider: any DateProviding,
        waterVolumeUnit: WaterVolumeUnit
    ) {
        self.trackingService = trackingService
        self.dateProvider = dateProvider
        self.waterVolumeUnit = waterVolumeUnit
    }

    var amountInMilliliters: Double? {
        WaterAmountFormatter.milliliters(
            fromDisplayedText: amountText,
            unit: waterVolumeUnit
        )
    }

    var canSave: Bool {
        guard let amountInMilliliters else { return false }
        return amountInMilliliters <= HydrationLimits.maximumSingleEntryInMilliliters
            && !isSaving
    }

    func save() async -> Bool {
        guard let amountInMilliliters else {
            errorMessage = HydrationError.invalidAmount.localizedDescription
            return false
        }
        guard amountInMilliliters <= HydrationLimits.maximumSingleEntryInMilliliters else {
            errorMessage = HydrationError.amountExceedsSingleEntryLimit.localizedDescription
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
