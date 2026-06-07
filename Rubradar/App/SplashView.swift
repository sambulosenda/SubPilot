//
//  SplashView.swift
//  Rubradar
//

import SwiftUI

/// Brief branded launch screen shown over a cold start while the app warms up.
/// Presents the SubPilot app-icon tile — so the splash matches the icon the user
/// just tapped — which scales/fades in, then hands off to the main UI via a
/// cross-fade owned by `AppRootView`.
///
/// The background matches the system-generated launch screen (`systemBackground`)
/// so there's no flash between the static launch image and this view; only the
/// mark and wordmark animate in.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    /// iOS masks app icons with a continuous "squircle"; matching its corner
    /// ratio (~0.2237 of the side) makes the tile read as the real app icon.
    private static let markSize: CGFloat = 132
    private var cornerRadius: CGFloat { Self.markSize * 0.2237 }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.markSize, height: Self.markSize)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.86)
                    .opacity(appeared ? 1 : 0)

                Text("SubPilot")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: (appeared || reduceMotion) ? 0 : 8)
            }
        }
        // Transient, decorative chrome — collapse to a single label so VoiceOver
        // simply announces the app name during launch.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("SubPilot")
        .accessibilityAddTraits(.isImage)
        .onAppear {
            withAnimation(reduceMotion ? .easeIn(duration: 0.3) : .smooth(duration: 0.55)) {
                appeared = true
            }
        }
    }
}

#Preview("Splash") {
    SplashView()
}
