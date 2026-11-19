//
//  UsageCheckInView.swift
//  Rubradar
//

import SwiftUI

/// Home's once-a-month prompt to run the usage check-in.
struct UsageCheckInRow: View {
    let month: Date

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Decorative, and its fixed tile clips the scaled glyph at
            // accessibility sizes — where the text wants the width anyway.
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: "checklist")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.brand, in: .rect(cornerRadius: 40 * 0.28, style: .continuous))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Monthly check-in")
                    .font(.headline)
                Text("Which did you use in \(month.formatted(.dateTime.month(.wide)))?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// The check-in itself: every candidate starts as "used"; the user switches
/// off what they didn't use and taps Done. Nothing is written until then, so
/// Skip and swipe-to-dismiss both leave the data alone.
struct UsageCheckInView: View {
    let subscriptions: [Subscription]
    let month: Date
    /// Called with the ids switched off, or nil when skipped.
    var onFinish: (Set<UUID>?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var unused: Set<UUID> = []

    private var monthName: String { month.formatted(.dateTime.month(.wide)) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(subscriptions) { sub in
                        Toggle(isOn: binding(for: sub.id)) {
                            HStack(spacing: Spacing.md) {
                                BrandLogoView(subscription: sub, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sub.name)
                                        .font(.headline)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Text(sub.priceLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(.brand)
                    }
                } header: {
                    // In the list, not the bar: the inline title truncated it.
                    Text("Which did you use in \(monthName)?")
                        .textCase(nil)
                } footer: {
                    Text("Switch off anything you didn't use in \(monthName). We'll flag subscriptions that go unused two months running.")
                }
            }
            .navigationTitle("Monthly check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        onFinish(nil)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onFinish(unused)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// On = used. Stored inverted so the common case (used everything) is an
    /// empty set and a single tap on Done.
    private func binding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { !unused.contains(id) },
            set: { used in
                if used { unused.remove(id) } else { unused.insert(id) }
            }
        )
    }
}

#Preview {
    UsageCheckInView(subscriptions: SampleData.makeSamples(), month: Date(), onFinish: { _ in })
}
