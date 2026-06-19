//
//  OnboardingStarterStep.swift
//  Rubradar
//

import SwiftUI

/// The onboarding "value moment": the user taps the subscriptions they already
/// pay for and immediately sees their total spend. It turns an abstract empty
/// app into "this knows I spend £X/yr" *before* the paywall — and seeds real
/// subscriptions so the user never lands on an empty list (the cold-start cliff).
///
/// Prices are typical, editable estimates (the bundled catalogue carries no
/// prices); the user adjusts exact amounts later in the app. Selection + the
/// persistence that follows it are owned by `OnboardingView`, which has the
/// `modelContext`; this view is pure presentation over a selection binding.
struct OnboardingStarterStep: View {
    let items: [OnboardingStarter]
    @Binding var selected: Set<String>
    /// Currency the typical prices + total are shown in (the device locale's,
    /// matching the currency `CatalogueProvider.makeDraft()` stamps on new subs).
    let currencyCode: String

    private var monthlyTotal: Decimal {
        items.reduce(0) { $0 + (selected.contains($1.id) ? $1.monthlyPrice : 0) }
    }

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: Spacing.sm)]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                header
                total
                LazyVGrid(columns: columns, spacing: Spacing.sm) {
                    ForEach(items) { item in
                        StarterChip(
                            item: item,
                            currencyCode: currencyCode,
                            isSelected: selected.contains(item.id)
                        ) { toggle(item.id) }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        VStack(spacing: Spacing.sm) {
            Text("What are you paying for?")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text("Tap the ones you have — we'll total it up. You can fix the amounts later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Spacing.sm)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var total: some View {
        if selected.isEmpty {
            Text("Tap a few to see your monthly spend")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)
                .cardStyle()
                .accessibilityHidden(true)
        } else {
            VStack(spacing: 2) {
                Text("You're tracking")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(monthlyTotal.formatted(.currency(code: currencyCode)) + " / mo")
                    .font(.largeTitle.bold())
                    .contentTransition(.numericText(value: monthlyDouble))
                Text((monthlyTotal * 12).formatted(.currency(code: currencyCode)) + " / yr")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .cardStyle()
            .animation(.snappy, value: monthlyDouble)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("You're tracking \(monthlyTotal.formatted(.currency(code: currencyCode))) per month")
        }
    }

    /// Drives `contentTransition`/`animation` — they key on an `Equatable`, and a
    /// `Double` snapshot of the total is stable and cheap to diff.
    private var monthlyDouble: Double { NSDecimalNumber(decimal: monthlyTotal).doubleValue }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }
}

// MARK: - Chip

private struct StarterChip: View {
    let item: OnboardingStarter
    let currencyCode: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Spacing.xs) {
                BrandLogoView(
                    symbolName: item.provider.symbolName,
                    logoAssetName: item.provider.logoAssetName,
                    brandDomain: item.provider.domain,
                    tint: Color(hex: item.provider.brandColorHex ?? "") ?? item.provider.category.tint,
                    category: item.provider.category,
                    size: 40
                )
                Text(item.provider.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.primary)
                Text(item.monthlyPrice.formatted(.currency(code: currencyCode)) + " / mo")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.sm)
            .background(Color.cardBackground, in: .rect(cornerRadius: Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card)
                    .strokeBorder(.tint, lineWidth: isSelected ? 2 : 0)
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.tint)
                        .padding(Spacing.xs)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityLabel("\(item.provider.name), \(item.monthlyPrice.formatted(.currency(code: currencyCode))) per month")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    @Previewable @State var selected: Set<String> = ["netflix", "spotify"]
    return OnboardingStarterStep(
        items: OnboardingStarter.load(),
        selected: $selected,
        currencyCode: "USD"
    )
}
