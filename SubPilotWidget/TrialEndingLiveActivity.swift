//
//  TrialEndingLiveActivity.swift
//  SubPilotWidget
//
//  Lock Screen banner and Dynamic Island for a free trial's last day. All text
//  arrives localised in the attributes; nothing here needs the string catalog.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct TrialEndingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrialEndingAttributes.self) { context in
            HStack(spacing: 12) {
                TrialChip(attributes: context.attributes, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: context.attributes.title)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(verbatim: context.attributes.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .activityBackgroundTint(nil)
            .widgetURL(WidgetDeepLink.home)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TrialChip(attributes: context.attributes, size: 36)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(verbatim: context.state.formattedAmount)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(verbatim: context.attributes.name)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(verbatim: context.attributes.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: context.attributes.symbolName)
                    .foregroundStyle(context.attributes.tint)
            } compactTrailing: {
                Text(verbatim: context.state.formattedAmount)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: context.attributes.symbolName)
                    .foregroundStyle(context.attributes.tint)
            }
            .widgetURL(WidgetDeepLink.home)
        }
    }
}

/// The tinted symbol chip the widgets use when no logo is available. Live
/// Activity attributes are capped at 4 KB, so the logo PNG can't ride along.
private struct TrialChip: View {
    let attributes: TrialEndingAttributes
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(attributes.tint.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: attributes.symbolName)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

private extension TrialEndingAttributes {
    var tint: Color {
        if let hex = brandColorHex, let color = Color(hex: hex) { return color }
        return SubscriptionCategory(rawValue: categoryRaw)?.tint ?? .accentColor
    }
}
