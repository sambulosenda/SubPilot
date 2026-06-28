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

    var body: some View {
        VStack(spacing: Spacing.xl) {
            header
            actions
        }
        .padding(.horizontal, Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(appeared ? 1 : 0)
        .offset(y: (appeared || reduceMotion) ? 0 : 12)
        .onAppear {
            withAnimation(reduceMotion ? .easeIn(duration: 0.3) : .smooth(duration: 0.5)) {
                appeared = true
            }
        }
    }

    private var header: some View {
        VStack(spacing: Spacing.lg) {
            RecurraMarkView(size: 112, style: .plain, tint: .brand, looping: true)
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.sm) {
                Text("No subscriptions yet")
                    .font(.title2.bold())
                Text("Track everything you pay for in one place. Scan a receipt, pick from the catalogue, or add one yourself.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        GlassEffectContainer(spacing: Spacing.md) {
            VStack(spacing: Spacing.md) {
                Button(action: onScan) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "doc.viewfinder")
                            .accessibilityHidden(true)
                        Text("Scan a receipt")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)

                Button(action: onBrowseCatalogue) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "magnifyingglass")
                            .accessibilityHidden(true)
                        Text("Browse catalogue")
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
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.extraLarge)

                Button("Add manually", systemImage: "square.and.pencil", action: onAddManually)
                    .padding(.top, Spacing.xs)
            }
            .frame(maxWidth: 320)
        }
    }
}

#Preview {
    SubscriptionsEmptyState(onScan: {}, onBrowseCatalogue: {}, onImportStatement: {}, onAddManually: {})
}
