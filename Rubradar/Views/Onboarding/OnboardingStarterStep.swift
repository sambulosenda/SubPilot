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
                    .appearEntrance(0)
                total
                    .appearEntrance(1)
                LazyVGrid(columns: columns, spacing: Spacing.sm) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        StarterChip(
                            item: item,
                            currencyCode: currencyCode,
                            isSelected: selected.contains(item.id)
                        ) { toggle(item.id) }
                        // Stagger by row (3-up), capped so the grid settles in
                        // ~0.3s and late rows scrolled into view don't crawl.
                        .appearEntrance(min(index / 3, 3) + 2)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.md)
        }
        .scrollIndicators(.hidden)
        // The page's bars are safe-area insets, so chips scroll *under* them.
        // Soft at the top (the title just needs to not hard-cut); hard at the
        // bottom, where the CTA has to stay readable over whatever brand logo
        // happens to scroll behind it.
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectStyle(.hard, for: .bottom)
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

    /// One container across both states, so the first tap *grows* a bare hint
    /// line into the running total instead of swapping one element for another —
    /// the moment the screen exists for should feel like a reveal, not a redraw.
    /// Empty gets no card: a full-width blank surface reads as a broken element
    /// and steals a chip row's worth of height.
    private var total: some View {
        VStack(spacing: 2) {
            if selected.isEmpty {
                Text("Tap a few to see your monthly spend")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("You're tracking")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(monthlyText)
                    .font(.largeTitle.bold())
                    .contentTransition(.numericText(value: monthlyDouble))
                Text(yearlyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, selected.isEmpty ? Spacing.sm : Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: Radius.card)
                .fill(Color.cardBackground)
                .overlay {
                    // Ring lights up once there's a number worth reading.
                    RoundedRectangle(cornerRadius: Radius.card)
                        .strokeBorder(Color.brand.opacity(0.35), lineWidth: 1)
                }
                .opacity(selected.isEmpty ? 0 : 1)
        }
        .animation(.snappy, value: monthlyDouble)
        .animation(.snappy, value: selected.isEmpty)
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(selected.isEmpty)
        .accessibilityLabel("You're tracking \(monthlyTotal.formatted(.currency(code: currencyCode))) per month")
    }

    /// Drives `contentTransition`/`animation` — they key on an `Equatable`, and a
    /// `Double` snapshot of the total is stable and cheap to diff.
    private var monthlyDouble: Double { NSDecimalNumber(decimal: monthlyTotal).doubleValue }

    // Hoisted out of the view body: `Decimal.formatted(...) + String` inside a
    // container is a type-checker sinkhole (SourceKit times out on it inline).
    private var monthlyText: String {
        monthlyTotal.formatted(.currency(code: currencyCode)) + " / mo"
    }

    private var yearlyText: String {
        (monthlyTotal * 12).formatted(.currency(code: currencyCode)) + " / yr"
    }

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
                    // Two lines so accessibility sizes truncate long names
                    // ("YouTube Premium") rather than clipping them to "YouTu…".
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.primary)
                Text(item.monthlyPrice.formatted(.currency(code: currencyCode)) + " / mo")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.sm)
            .background {
                RoundedRectangle(cornerRadius: Radius.card)
                    .fill(Color.cardBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.card)
                            .fill(Color.accentColor.opacity(isSelected ? 0.10 : 0))
                    }
            }
            .overlay {
                // Unselected chips still get a hairline so they read as targets
                // rather than free-floating logos.
                RoundedRectangle(cornerRadius: Radius.card)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.primary.opacity(0.07),
                        lineWidth: isSelected ? 2 : 1
                    )
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
        .buttonStyle(.pressable)
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
