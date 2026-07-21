import SwiftUI

struct QuickAddWaterView: View {
    @Environment(\.waterVolumeUnit) private var waterVolumeUnit

    let amountsInMilliliters: [Double]
    let addWater: (Double) -> Void
    let showCustomAmount: () -> Void

    var body: some View {
        AquaCard {
            VStack(alignment: .leading, spacing: AquaSpacing.medium) {
                Text("Add Water")
                    .font(.headline)

                HStack(spacing: AquaSpacing.small) {
                    ForEach(Array(amountsInMilliliters.enumerated()), id: \.offset) { _, amount in
                        Button {
                            addWater(amount)
                        } label: {
                            Text(
                                "+\(WaterAmountFormatter.string(from: amount, unit: waterVolumeUnit))"
                            )
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: AquaCornerRadius.control))
                        .accessibilityLabel(
                            "Add \(WaterAmountFormatter.string(from: amount, unit: waterVolumeUnit)) of water"
                        )
                    }
                }

                Button(action: showCustomAmount) {
                    Label("Custom Amount", systemImage: "plus")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: AquaCornerRadius.control))
            }
        }
    }
}
