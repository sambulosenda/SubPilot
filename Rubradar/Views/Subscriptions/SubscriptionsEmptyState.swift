//
//  SubscriptionsEmptyState.swift
//  Rubradar
//

import SwiftUI

/// Shown when no subscriptions exist. Surfaces the catalogue and manual add as CTAs.
struct SubscriptionsEmptyState: View {
    var onBrowseCatalogue: () -> Void
    var onAddManually: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No subscriptions yet", systemImage: "rectangle.stack.badge.plus")
        } description: {
            Text("Track everything you pay for in one place. Add your first subscription to get started.")
        } actions: {
            GlassEffectContainer(spacing: Spacing.md) {
                VStack(spacing: Spacing.md) {
                    Button {
                        onBrowseCatalogue()
                    } label: {
                        Label("Browse catalogue", systemImage: "magnifyingglass")
                            .frame(maxWidth: 280)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.extraLarge)

                    Button {
                        onAddManually()
                    } label: {
                        Label("Add manually", systemImage: "square.and.pencil")
                            .frame(maxWidth: 280)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                }
            }
        }
    }
}

#Preview {
    SubscriptionsEmptyState(onBrowseCatalogue: {}, onAddManually: {})
}
