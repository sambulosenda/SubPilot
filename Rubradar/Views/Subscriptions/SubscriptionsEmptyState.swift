//
//  SubscriptionsEmptyState.swift
//  Rubradar
//

import SwiftUI

/// Shown when no subscriptions exist. Surfaces the catalogue and manual add as CTAs.
struct SubscriptionsEmptyState: View {
    var onScan: () -> Void
    var onBrowseCatalogue: () -> Void
    var onAddManually: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No subscriptions yet", systemImage: "rectangle.stack.badge.plus")
        } description: {
            Text("Track everything you pay for in one place. Scan a receipt, pick from the catalogue, or add one yourself.")
        } actions: {
            GlassEffectContainer(spacing: Spacing.md) {
                VStack(spacing: Spacing.md) {
                    Button {
                        onScan()
                    } label: {
                        Label("Scan a receipt", systemImage: "doc.viewfinder")
                            .frame(maxWidth: 280)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.extraLarge)

                    Button {
                        onBrowseCatalogue()
                    } label: {
                        Label("Browse catalogue", systemImage: "magnifyingglass")
                            .frame(maxWidth: 280)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)

                    Button("Add manually", systemImage: "square.and.pencil") {
                        onAddManually()
                    }
                    .padding(.top, Spacing.xs)
                }
            }
        }
    }
}

#Preview {
    SubscriptionsEmptyState(onScan: {}, onBrowseCatalogue: {}, onAddManually: {})
}
