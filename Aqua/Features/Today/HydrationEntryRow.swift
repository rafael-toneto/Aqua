import SwiftUI

struct HydrationEntryRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.waterVolumeUnit) private var waterVolumeUnit

    let entry: HydrationEntry

    var body: some View {
        HStack(spacing: AquaSpacing.medium) {
            Image(systemName: sourceIcon)
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 38, height: 38)
                .background(palette.accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: AquaSpacing.extraSmall) {
                Text(
                    WaterAmountFormatter.string(
                        from: entry.amountInMilliliters,
                        unit: waterVolumeUnit
                    )
                )
                    .font(.body.weight(.semibold))
                Text(sourceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.date.formatted(date: .omitted, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, AquaSpacing.extraSmall)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(WaterAmountFormatter.string(from: entry.amountInMilliliters, unit: waterVolumeUnit)), \(sourceName)"
        )
        .accessibilityValue(entry.date.formatted(date: .omitted, time: .shortened))
    }

    private var sourceName: String {
        switch entry.source {
        case .quickAdd:
            "Quick add"
        case .manual:
            "Custom amount"
        case .plan:
            "Daily plan"
        default:
            "Added water"
        }
    }

    private var palette: AquaPalette {
        AquaPalette(colorScheme: colorScheme)
    }

    private var sourceIcon: String {
        switch entry.source {
        case .quickAdd: "bolt.fill"
        case .plan: "clock.badge.checkmark"
        default: "drop.fill"
        }
    }
}
