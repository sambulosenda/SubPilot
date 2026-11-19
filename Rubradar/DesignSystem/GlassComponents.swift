//
//  GlassComponents.swift
//  Rubradar
//

import SwiftUI

// MARK: - Card styling

private struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground, in: .rect(cornerRadius: Radius.card))
    }
}

extension View {
    /// Wraps content in an opaque grouped-style card. Content sits on a solid,
    /// legible surface — Liquid Glass is reserved for chrome (tab bar, controls).
    func cardStyle() -> some View { modifier(CardModifier()) }
}

// MARK: - Badges

struct TrialBadge: View {
    var body: some View {
        Text("Trial")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 2)
            .background(.orange.opacity(0.2), in: .capsule)
            .foregroundStyle(Color.attention)
            .accessibilityLabel("Free trial")
            // Scale+fade in so a status change reads as a change, not a redraw,
            // when toggled inside an animated transaction.
            .transition(.scale.combined(with: .opacity))
    }
}

struct CancelledBadge: View {
    var body: some View {
        Text("Cancelled")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.2), in: .capsule)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Cancelled")
            .transition(.scale.combined(with: .opacity))
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        HStack { TrialBadge(); CancelledBadge() }
        Text("A glass card")
            .cardStyle()
    }
    .padding()
}
