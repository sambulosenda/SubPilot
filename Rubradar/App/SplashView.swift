//
//  SplashView.swift
//  Rubradar
//

import SwiftUI

/// Brief branded launch screen shown over a cold start while the app warms up.
/// Draws a radar-sweep mark — a nod to the app's name — that animates in, then
/// hands off to the main UI via a cross-fade owned by `AppRootView`.
///
/// The background matches the system-generated launch screen (`systemBackground`)
/// so there's no flash between the static launch image and this view; only the
/// mark and wordmark animate in.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                RadarMark(tint: .accentColor, sweeping: appeared && !reduceMotion)
                    .frame(width: 132, height: 132)
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

// MARK: - Radar mark

/// Concentric rings with a rotating sweep, evoking a radar display. The sweep
/// only spins while `sweeping` is true so Reduce Motion can hold it static.
private struct RadarMark: View {
    var tint: Color
    var sweeping: Bool

    @State private var angle: Angle = .degrees(0)

    var body: some View {
        ZStack {
            // Three concentric rings, evenly inset from the outer frame.
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .strokeBorder(tint.opacity(0.28), lineWidth: 1.5)
                    .padding(CGFloat(ring) * 22)
            }

            // The sweep: an angular gradient that's clear for most of the turn
            // and ramps to the tint at its leading edge, leaving a trailing fade.
            Circle()
                .fill(
                    AngularGradient(
                        stops: [
                            .init(color: tint.opacity(0), location: 0.0),
                            .init(color: tint.opacity(0), location: 0.72),
                            .init(color: tint.opacity(0.45), location: 1.0),
                        ],
                        center: .center
                    )
                )
                .rotationEffect(angle)

            // Center pip with a soft halo so it reads as the radar origin.
            Circle()
                .fill(tint)
                .frame(width: 11, height: 11)
                .shadow(color: tint.opacity(0.6), radius: 5)
        }
        .onChange(of: sweeping, initial: true) { _, isOn in
            guard isOn else { return }
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                angle = .degrees(360)
            }
        }
    }
}

#Preview("Splash") {
    SplashView()
}
