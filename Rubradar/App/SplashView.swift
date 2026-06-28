//
//  SplashView.swift
//  Rubradar
//

import SwiftUI

/// Brief branded launch screen shown over a cold start while the app warms up.
/// Presents the Recurra app-icon mark — so the splash matches the icon the user
/// just tapped — drawn natively (`RecurraMarkView`): the tile scales/fades in
/// while the ring draws itself closed and the dot lands, then hands off to the
/// main UI via a cross-fade owned by `AppRootView`.
///
/// The background matches the system-generated launch screen (`systemBackground`)
/// so there's no flash between the static launch image and this view; only the
/// mark and wordmark animate in.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private static let markSize: CGFloat = 132
    private var cornerRadius: CGFloat { Self.markSize * 0.2237 }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                RecurraMarkView(size: Self.markSize)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.86)
                    .opacity(appeared ? 1 : 0)

                Text("Recurra")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: (appeared || reduceMotion) ? 0 : 8)
            }
        }
        // Transient, decorative chrome — collapse to a single label so VoiceOver
        // simply announces the app name during launch.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recurra")
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
