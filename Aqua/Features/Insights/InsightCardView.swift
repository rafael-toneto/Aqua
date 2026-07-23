import SwiftUI

struct InsightCardView: View {
    let insight: HydrationInsight

    var body: some View {
        AquaCard {
            VStack(alignment: .leading, spacing: AquaSpacing.medium) {
                HStack(alignment: .center, spacing: AquaSpacing.small) {
                    Image(systemName: categoryIcon)
                        .font(.headline)
                        .foregroundStyle(categoryColor)
                        .frame(width: 36, height: 36)
                        .background(categoryColor.opacity(0.12), in: Circle())

                    Text(categoryTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(priorityTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(priorityColor)
                        .padding(.horizontal, AquaSpacing.small)
                        .padding(.vertical, AquaSpacing.extraSmall)
                        .background(priorityColor.opacity(0.12), in: Capsule())
                }

                VStack(alignment: .leading, spacing: AquaSpacing.small) {
                    Text(insight.title)
                        .font(.title3.bold())
                    Text(insight.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Label(insight.evidence, systemImage: "number")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.blue)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Label {
                    Text(insight.suggestedAction)
                        .font(.subheadline.weight(.medium))
                } icon: {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
        }
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
        case .consistency: .blue
        case .timing: .orange
        case .goalProgress: .cyan
        case .planAdherence: .indigo
        case .dayDistribution: .yellow
        case .recentEvolution: .green
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
        case .low: .secondary
        case .medium: .orange
        case .high: .red
        }
    }
}
