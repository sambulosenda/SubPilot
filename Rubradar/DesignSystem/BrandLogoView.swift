//
//  BrandLogoView.swift
//  Rubradar
//

import SwiftUI

/// A square brand chip. Shows a bundled logo asset when one is available,
/// otherwise an SF Symbol on a tinted rounded square. No glass here — glass
/// can't sample glass cleanly inside lists.
struct BrandLogoView: View {
    var symbolName: String?
    var logoAssetName: String?
    var tint: Color
    var category: SubscriptionCategory = .other
    var size: CGFloat = 44

    private var resolvedSymbol: String { symbolName ?? category.defaultSymbol }

    private var hasAsset: Bool {
        guard let name = logoAssetName, !name.isEmpty else { return false }
        #if canImport(UIKit)
        return UIImage(named: name) != nil
        #else
        return false
        #endif
    }

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(tint.gradient.opacity(0.9))
            .frame(width: size, height: size)
            .overlay {
                if hasAsset, let name = logoAssetName {
                    Image(name)
                        .resizable()
                        .scaledToFit()
                        .padding(size * 0.18)
                } else {
                    Image(systemName: resolvedSymbol)
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .accessibilityHidden(true)
    }
}

extension BrandLogoView {
    /// Convenience initialiser from a stored subscription.
    init(subscription: Subscription, size: CGFloat = 44) {
        self.init(
            symbolName: subscription.symbolName,
            logoAssetName: subscription.logoAssetName,
            tint: subscription.displayTint,
            category: subscription.category,
            size: size
        )
    }
}

#Preview {
    HStack(spacing: Spacing.md) {
        BrandLogoView(symbolName: "play.tv.fill", logoAssetName: nil, tint: .red)
        BrandLogoView(symbolName: "music.note", logoAssetName: nil, tint: .green)
        BrandLogoView(symbolName: nil, logoAssetName: nil, tint: .secondary, category: .other)
    }
    .padding()
}
