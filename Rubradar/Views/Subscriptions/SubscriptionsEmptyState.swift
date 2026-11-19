//
//  SubscriptionsEmptyState.swift
//  Rubradar
//

import SwiftUI

/// Shown when no subscriptions exist. Surfaces the catalogue, receipt scan, and
/// manual add as a clear primary/secondary/tertiary CTA stack. Owns the screen
/// (the host uses an inline nav title when empty) so this block is the single
/// focal point rather than competing with a large "Home" title.
struct SubscriptionsEmptyState: View {
    var onScan: () -> Void
    var onBrowseCatalogue: () -> Void
    var onImportStatement: () -> Void
    var onAddManually: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Drives a one-shot fade+rise entrance (and the icon bounce) on first show,
    /// so a blank screen settles in rather than snapping into place.
    @State private var appeared = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Centred when it fits. At accessibility text sizes it doesn't: the
        // description was cut off mid-sentence and the last button sat on the
        // tab bar, so there the block scrolls instead.
        ViewThatFits(in: .vertical) {
            stack
            ScrollView { stack.padding(.vertical, Spacing.lg) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(appeared ? 1 : 0)
        .offset(y: (appeared || reduceMotion) ? 0 : 12)
        .onAppear {
            withAnimation(reduceMotion ? .easeIn(duration: 0.3) : .smooth(duration: 0.5)) {
                appeared = true
            }
        }
    }

    private var stack: some View {
        VStack(spacing: Spacing.xl) {
            header
            actions
        }
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? Spacing.lg : Spacing.xl)
    }

    private var header: some View {
        VStack(spacing: Spacing.lg) {
            RecurraMarkView(size: 112, style: .plain, tint: .brand, looping: true)
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.sm) {
                Text("No subscriptions yet")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("Track everything you pay for in one place. Scan a receipt, pick from the catalogue, or add one yourself.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        GlassEffectContainer(spacing: Spacing.md) {
            VStack(spacing: Spacing.md) {
                // The catalogue leads: it is free, and the fastest way to a
                // first subscription. Scanning and importing are Pro, so as the
                // prominent button they sent a brand-new user's first tap
                // straight to the paywall. Same order as `AddOptionsSheet`.
                Button(action: onBrowseCatalogue) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "magnifyingglass")
                            .accessibilityHidden(true)
                        Text("Browse catalogue")
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)

                Button(action: onScan) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "doc.viewfinder")
                            .accessibilityHidden(true)
                        Text("Scan a receipt")
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.extraLarge)

                Button(action: onImportStatement) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "doc.badge.arrow.up")
                            .accessibilityHidden(true)
                        Text("Import bank statement")
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.extraLarge)

                Button("Add manually", systemImage: "square.and.pencil", action: onAddManually)
                    // A bare text button is ~21pt tall; give it a full 44pt
                    // target across the column.
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(.rect)
            }
            // Full width at accessibility sizes: at 320pt "Import bank
            // statement" truncated.
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 320)
        }
    }
}

#Preview {
    SubscriptionsEmptyState(onScan: {}, onBrowseCatalogue: {}, onImportStatement: {}, onAddManually: {})
}
