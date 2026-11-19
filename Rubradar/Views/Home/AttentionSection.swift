//
//  AttentionSection.swift
//  Rubradar
//

import SwiftUI

/// Home's "Needs attention" list section: everything that wants a keep-or-
/// cancel decision — trials about to convert, cancel deadlines coming up,
/// subscriptions that keep going unused, and recent price rises. Rows push the standard detail screen (the host's
/// `navigationDestination(for: Subscription.self)`), where the guided cancel
/// flow lives. Everything but a trial can be dismissed with "Keep".
struct AttentionSection: View {
    let items: [AttentionItem]
    /// The user decided to keep the subscription; passes the item's
    /// `dismissToken`.
    var onKeep: (String) -> Void

    var body: some View {
        Section {
            ForEach(items) { item in
                NavigationLink(value: item.subscription) {
                    switch item {
                    case .trial(let trial): TrialRadarRow(trial: trial)
                    case .deadline(let deadline): DeadlineRow(item: deadline)
                    case .unused(let sub, let months): UnusedRow(subscription: sub, months: months)
                    case .priceRise(let rise): PriceRiseRow(rise: rise)
                    }
                }
                .swipeActions(edge: .trailing) {
                    if let token = item.dismissToken {
                        Button("Keep", systemImage: "checkmark") { onKeep(token) }
                            .tint(.brand)
                    }
                }
            }
        } header: {
            Label("Needs attention", systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(Color.attention)
        }
    }
}

private struct TrialRadarRow: View {
    let trial: EndingTrial

    @Environment(CurrencyService.self) private var currency
    @AppStorage("preferredCurrencyCode") private var preferredCurrency =
        Locale.current.currency?.identifier ?? "GBP"

    /// In the preferred currency, like the rows below it: "then US$20.00"
    /// directly above the same subscription at "£15.21" read as two prices.
    private var price: String {
        trial.subscription.priceLabel(in: preferredCurrency, rates: currency.rates)
    }

    var body: some View {
        RowStack {
            BrandLogoView(subscription: trial.subscription, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(trial.subscription.name)
                    .font(.headline)
                    .rowTitle()
                // The section no longer says "trials", so the row has to. On
                // the second line: beside the name, a badge truncated it.
                HStack(spacing: Spacing.xs) {
                    Text("Trial")
                    Text(verbatim: "·")
                    Text(trial.endsLabel)
                }
                .font(.caption.weight(trial.isUrgent ? .semibold : .regular))
                .foregroundStyle(trial.isUrgent ? AnyShapeStyle(Color.attention) : AnyShapeStyle(.secondary))
                .rowTitle()
            }
            // Takes all the width the price leaves. With a Spacer here instead,
            // HStack split that width between the two and the name truncated
            // with room to spare.
            .frame(maxWidth: .infinity, alignment: .leading)
            // Same width fight as SubscriptionRow: unprioritised, this clipped
            // to "then US$20.00 /…", which hides the very number the row warns
            // the user they're about to start paying.
            VStack(alignment: .trailing, spacing: 2) {
                Text("then \(price)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .rowValue()
            }
            .layoutPriority(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trial.subscription.name) free trial")
        .accessibilityValue("\(trial.endsLabel), then \(price)")
    }
}

private struct DeadlineRow: View {
    let item: UpcomingDeadline

    private var relative: String {
        switch item.deadline.daysLeft {
        case ...0: String(localized: "Today")
        case 1: String(localized: "Tomorrow")
        default: String(localized: "in \(item.deadline.daysLeft) days")
        }
    }

    var body: some View {
        RowStack {
            BrandLogoView(subscription: item.subscription, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.subscription.name)
                    .font(.headline)
                    .rowTitle()
                Text("Last day to cancel")
                    .font(.caption.weight(item.isUrgent ? .semibold : .regular))
                    .foregroundStyle(item.isUrgent ? AnyShapeStyle(Color.attention) : AnyShapeStyle(.secondary))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.deadline.date, format: .dateTime.day().month(.abbreviated))
                    .font(.subheadline.weight(.semibold))
                Text(relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .rowValue()
            .layoutPriority(1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct UnusedRow: View {
    let subscription: Subscription
    let months: Int

    @Environment(CurrencyService.self) private var currency
    @AppStorage("preferredCurrencyCode") private var preferredCurrency =
        Locale.current.currency?.identifier ?? "GBP"

    private var yearly: String {
        let native = subscription.monthlyEquivalent * 12
        if subscription.currencyCode != preferredCurrency,
           let converted = currency.rates.convert(native, from: subscription.currencyCode, to: preferredCurrency) {
            return converted.formatted(.currency(code: preferredCurrency))
        }
        return native.formatted(.currency(code: subscription.currencyCode))
    }

    var body: some View {
        RowStack {
            BrandLogoView(subscription: subscription, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name)
                    .font(.headline)
                    .rowTitle()
                Text("Not used for \(months) months")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.attention)
                    .rowTitle()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Amount over unit, like the other rows: on one line the yearly
            // figure squeezed the name and wrapped the label.
            VStack(alignment: .trailing, spacing: 2) {
                Text(yearly)
                    .font(.subheadline.weight(.semibold))
                Text("/year")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .rowValue()
            .layoutPriority(1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PriceRiseRow: View {
    let rise: PriceRise

    private var percent: String? {
        rise.relativeChange?.formatted(.percent.precision(.fractionLength(0...1)).sign(strategy: .always()))
    }

    var body: some View {
        RowStack {
            BrandLogoView(subscription: rise.subscription, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(rise.subscription.name)
                    .font(.headline)
                    .rowTitle()
                Text("Price went up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.attention)
            }
            // Takes all the width the price leaves. With a Spacer here instead,
            // HStack split that width between the two and the name truncated
            // with room to spare.
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 2) {
                if let percent {
                    Text(percent)
                        .font(.subheadline.weight(.semibold))
                }
                Text(rise.transition)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .rowValue()
            .layoutPriority(1)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let subs = SampleData.makeSamples()
    return List {
        AttentionSection(items: AttentionRadar.items(in: subs), onKeep: { _ in })
    }
    .environment(CurrencyService())
}
