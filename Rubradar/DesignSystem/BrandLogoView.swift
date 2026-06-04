//
//  BrandLogoView.swift
//  Rubradar
//

import SwiftUI

/// A square brand chip. Prefers, in order: a bundled logo asset, a real logo
/// fetched from logo.dev by domain, then an SF Symbol on a tinted rounded
/// square. Real logos sit on a white chip so multi-coloured marks read cleanly;
/// the SF Symbol fallback keeps the brand-tinted gradient. No glass here — glass
/// can't sample glass cleanly inside lists.
struct BrandLogoView: View {
    var symbolName: String?
    var logoAssetName: String?
    var brandDomain: String?
    var tint: Color
    var category: SubscriptionCategory = .other
    var size: CGFloat = 44

    @State private var remoteLogo: Image?

    private var resolvedSymbol: String { symbolName ?? category.defaultSymbol }

    /// The bundled asset name, but only if it actually resolves to an image.
    private var bundledAsset: String? {
        guard let name = logoAssetName, !name.isEmpty else { return nil }
        #if canImport(UIKit)
        return UIImage(named: name) != nil ? name : nil
        #else
        return nil
        #endif
    }

    private var showsRealLogo: Bool { bundledAsset != nil || remoteLogo != nil }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        shape
            .fill(showsRealLogo ? AnyShapeStyle(.white) : AnyShapeStyle(tint.gradient.opacity(0.9)))
            .frame(width: size, height: size)
            .overlay { content }
            .overlay {
                // Hairline edge so a white logo chip seats on light backgrounds.
                if showsRealLogo {
                    shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
            }
            .task(id: brandDomain) { await loadRemoteLogo() }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        if let name = bundledAsset {
            Image(name)
                .resizable()
                .scaledToFit()
                .padding(size * 0.18)
        } else if let remoteLogo {
            remoteLogo
                .resizable()
                .scaledToFit()
                .padding(size * 0.16)
        } else {
            Image(systemName: resolvedSymbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func loadRemoteLogo() async {
        guard bundledAsset == nil, let domain = brandDomain, !domain.isEmpty else {
            remoteLogo = nil
            return
        }
        #if canImport(UIKit)
        let uiImage = await BrandLogoStore.shared.image(for: domain)
        guard !Task.isCancelled else { return }
        remoteLogo = uiImage.map { Image(uiImage: $0) }
        #endif
    }
}

extension BrandLogoView {
    /// Convenience initialiser from a stored subscription.
    init(subscription: Subscription, size: CGFloat = 44) {
        self.init(
            symbolName: subscription.symbolName,
            logoAssetName: subscription.logoAssetName,
            brandDomain: subscription.brandDomain,
            tint: subscription.displayTint,
            category: subscription.category,
            size: size
        )
    }
}

#Preview {
    HStack(spacing: Spacing.md) {
        BrandLogoView(symbolName: "play.tv.fill", logoAssetName: nil, brandDomain: nil, tint: .red)
        BrandLogoView(symbolName: "music.note", logoAssetName: nil, brandDomain: nil, tint: .green)
        BrandLogoView(symbolName: nil, logoAssetName: nil, brandDomain: nil, tint: .secondary, category: .other)
    }
    .padding()
}
