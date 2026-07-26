//
//  TrialRadarSection.swift
//  Rubradar
//

import SwiftUI

/// Home's "Trials ending soon" list section: one row per free trial converting
/// within the radar window, soonest first. Rows push the standard detail screen
/// (the host's `navigationDestination(for: Subscription.self)`), where the user
/// can mark the trial cancelled before it charges.
struct TrialRadarSection: View {
    let trials: [EndingTrial]

    var body: some View {
        Section {
            ForEach(trials) { trial in
                NavigationLink(value: trial.subscription) {
                    TrialRadarRow(trial: trial)
                }
            }
        } header: {
            Label("Trials ending soon", systemImage: "hourglass")
                .foregroundStyle(.orange)
        }
    }
}

private struct TrialRadarRow: View {
    let trial: EndingTrial

    var body: some View {
        HStack(spacing: Spacing.md) {
            BrandLogoView(subscription: trial.subscription, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(trial.subscription.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(trial.endsLabel)
                    .font(.caption.weight(trial.isUrgent ? .semibold : .regular))
                    .foregroundStyle(trial.isUrgent ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
            }
            Spacer(minLength: Spacing.sm)
            // Same width fight as SubscriptionRow: unprioritised, this clipped
            // to "then US$20.00 /…", which hides the very number the row warns
            // the user they're about to start paying.
            VStack(alignment: .trailing, spacing: 2) {
                Text("then \(trial.subscription.priceLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .layoutPriority(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trial.subscription.name) free trial")
        .accessibilityValue("\(trial.endsLabel), then \(trial.subscription.priceLabel)")
    }
}

#Preview {
    let subs = SampleData.makeSamples()
    let trials = TrialRadar.endingTrials(in: subs)
    return List {
        TrialRadarSection(trials: trials)
    }
}
