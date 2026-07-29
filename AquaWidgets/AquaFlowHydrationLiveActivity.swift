import ActivityKit
import SwiftUI
import WidgetKit

struct AquaFlowHydrationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HydrationActivityAttributes.self) { context in
            HydrationLiveActivityLockScreenView(
                state: context.state,
                isStale: context.isStale
            )
            .activityBackgroundTint(HydrationActivityColors.background)
            .activitySystemActionForegroundColor(HydrationActivityColors.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 7) {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(HydrationActivityColors.accent)

                        Text("AquaFlow")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(HydrationActivityColors.primary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.percentage)%")
                        .font(.title3.bold())
                        .monospacedDigit()
                        .foregroundStyle(HydrationActivityColors.accent)
                        .contentTransition(.numericText())
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        
                        HydrationActivityProgressBar(progress: context.state.progress)
//                            .padding(.horizontal, 4)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(HydrationActivityFormatter.amount(
                                context.state.consumedInMilliliters,
                                usesFluidOunces: context.state.usesFluidOunces
                            ))
                            .font(.title3.bold())
                            .foregroundStyle(HydrationActivityColors.primary)

                            Text(
                                "of " + HydrationActivityFormatter.amount(
                                    context.state.goalInMilliliters,
                                    usesFluidOunces: context.state.usesFluidOunces
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(HydrationActivityColors.secondary)

                            Spacer(minLength: 8)

                            Text(HydrationActivityFormatter.status(context.state))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(HydrationActivityColors.secondary)
                                .lineLimit(1)
                        }

                    }
                    .padding(.vertical, 2)
                }
            } compactLeading: {
                Image(systemName: "drop.fill")
                    .foregroundStyle(HydrationActivityColors.accent)
                    .accessibilityLabel("AquaFlow hydration")
            } compactTrailing: {
                Text("\(context.state.percentage)%")
                    .font(.caption.bold())
                    .monospacedDigit()
                    .foregroundStyle(HydrationActivityColors.accent)
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(context.state.percentage) percent of daily water goal")
            } minimal: {
                ZStack {
                    Circle()
                        .stroke(HydrationActivityColors.track, lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(
                            HydrationActivityColors.accent,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "drop.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(HydrationActivityColors.accent)
                }
                .padding(3)
                .accessibilityLabel("Hydration progress, \(context.state.percentage) percent")
            }
            .keylineTint(HydrationActivityColors.accent)
        }
    }
}

private struct HydrationLiveActivityLockScreenView: View {
    let state: HydrationActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "drop.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HydrationActivityColors.accent)
                    .frame(width: 30, height: 30)
                    .background(HydrationActivityColors.accent.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text("AquaFlow")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(HydrationActivityColors.primary)

                    Text(isStale ? "Open the app to refresh" : "Today’s hydration")
                        .font(.caption2)
                        .foregroundStyle(HydrationActivityColors.secondary)
                }

                Spacer(minLength: 12)

                Text("\(state.percentage)%")
                    .font(.title2.bold())
                    .monospacedDigit()
                    .foregroundStyle(HydrationActivityColors.accent)
                    .contentTransition(.numericText())
            }

            HydrationActivityProgressBar(progress: state.progress)
                .frame(height: 7)
                .padding(.horizontal, 4)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(HydrationActivityFormatter.amount(
                    state.consumedInMilliliters,
                    usesFluidOunces: state.usesFluidOunces
                ))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(HydrationActivityColors.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

                Text(
                    "of " + HydrationActivityFormatter.amount(
                        state.goalInMilliliters,
                        usesFluidOunces: state.usesFluidOunces
                    )
                )
                .font(.subheadline)
                .foregroundStyle(HydrationActivityColors.secondary)
                .lineLimit(1)

                Spacer(minLength: 8)

                Text(HydrationActivityFormatter.status(state))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(state.progress >= 1
                        ? HydrationActivityColors.accent
                        : HydrationActivityColors.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(HydrationActivityFormatter.accessibilitySummary(state))
    }
}

private struct HydrationActivityProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let fillWidth = proxy.size.width * min(max(progress, 0), 1)
            let shape = RoundedRectangle(
                cornerRadius: height / 2,
                style: .continuous
            )

            shape
                .fill(HydrationActivityColors.track)
                .frame(width: proxy.size.width, height: height)
                .overlay(alignment: .leading) {
                    shape
                        .fill(HydrationActivityColors.accent)
                        .frame(width: fillWidth, height: height)
                }
                .clipShape(shape)
        }
        .frame(height: 7)
        .accessibilityHidden(true)
    }
}

private enum HydrationActivityFormatter {
    static func amount(_ milliliters: Double, usesFluidOunces: Bool) -> String {
        if usesFluidOunces {
            let fluidOunces = milliliters / 29.5735295625
            return "\(fluidOunces.formatted(.number.precision(.fractionLength(0...1)))) fl oz"
        }

        if milliliters >= 1_000 {
            let liters = milliliters / 1_000
            return "\(liters.formatted(.number.precision(.fractionLength(0...1)))) L"
        }
        return "\(milliliters.formatted(.number.precision(.fractionLength(0)))) ml"
    }

    static func status(_ state: HydrationActivityAttributes.ContentState) -> String {
        if state.progress >= 1 {
            return "Goal reached"
        }
        return "\(amount(state.remainingInMilliliters, usesFluidOunces: state.usesFluidOunces)) left"
    }

    static func accessibilitySummary(_ state: HydrationActivityAttributes.ContentState) -> String {
        "Today you have consumed "
            + "\(amount(state.consumedInMilliliters, usesFluidOunces: state.usesFluidOunces)) "
            + "of your \(amount(state.goalInMilliliters, usesFluidOunces: state.usesFluidOunces)) goal, "
            + "\(state.percentage) percent."
    }
}

private enum HydrationActivityColors {
    static let accent = Color(red: 0.12, green: 0.67, blue: 0.82)
    static let background = Color(red: 0.055, green: 0.067, blue: 0.071)
    static let primary = Color(red: 0.941, green: 0.957, blue: 0.961)
    static let secondary = Color(red: 0.655, green: 0.702, blue: 0.722)
    static let track = Color(red: 0.153, green: 0.184, blue: 0.196)
}
