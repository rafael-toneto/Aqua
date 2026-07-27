import SwiftUI

struct InsightCardView: View {
    @Environment(\.colorScheme) private var colorScheme

    let insight: HydrationInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: categoryIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(categoryColor)
                    .frame(width: 36, height: 36)
                    .background(categoryColor.opacity(0.11), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(categoryColor.opacity(0.2), lineWidth: 1)
                    }
                    .accessibilityHidden(true)

                Text(categoryTitle.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(categoryColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 8)

                Text(priorityTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(priorityColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(priorityColor.opacity(0.11), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(insight.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.primary)

                Text(insight.description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 24, height: 24)
                    .background(palette.accent.opacity(0.11), in: Circle())
                    .accessibilityHidden(true)

                Text(insight.evidence)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(11)
            .background(
                palette.background.opacity(colorScheme == .dark ? 0.7 : 0.58),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )

            Divider()
                .overlay(palette.divider)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 26, height: 26)
                    .background(palette.accent.opacity(0.11), in: Circle())
                    .accessibilityHidden(true)

                Text(insight.suggestedAction)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .insightsCard(palette: palette, cornerRadius: 18)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(categoryTitle) insight: \(insight.title)")
    }

    private var categoryTitle: String {
        switch insight.category {
        case .consistency: "Consistency"
        case .timing: "Timing"
        case .goalProgress: "Goal Progress"
        case .planAdherence: "Plan Adherence"
        case .dayDistribution: "Daily Distribution"
        case .recentEvolution: "Recent Evolution"
        }
    }

    private var categoryIcon: String {
        switch insight.category {
        case .consistency: "checkmark.circle.fill"
        case .timing: "clock.fill"
        case .goalProgress: "target"
        case .planAdherence: "list.bullet.clipboard.fill"
        case .dayDistribution: "sun.horizon.fill"
        case .recentEvolution: "arrow.up.right"
        }
    }

    private var categoryColor: Color {
        switch insight.category {
        case .consistency: palette.success
        case .timing: palette.warning
        case .goalProgress: palette.accent
        case .planAdherence: palette.accent
        case .dayDistribution: palette.warning
        case .recentEvolution: palette.success
        }
    }

    private var priorityTitle: String {
        switch insight.priority {
        case .low: "Helpful"
        case .medium: "Worth trying"
        case .high: "Focus"
        }
    }

    private var priorityColor: Color {
        switch insight.priority {
        case .low: palette.secondary
        case .medium: palette.accent
        case .high: palette.warning
        }
    }

    private var palette: InsightsPalette {
        InsightsPalette(colorScheme: colorScheme)
    }
}
