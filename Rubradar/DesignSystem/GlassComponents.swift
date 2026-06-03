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
            .glassEffect(.regular, in: .rect(cornerRadius: Radius.card))
    }
}

extension View {
    /// Wraps content in a Liquid Glass card.
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
            .foregroundStyle(.orange)
            .accessibilityLabel("Free trial")
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
