//
//  AppRootView.swift
//  Rubradar
//

import SwiftUI
import SwiftData

/// Top-level container that shows the branded `SplashView` on cold start, holds
/// it briefly so the mark reads, then cross-fades into the main `RootView`.
///
/// `RootView` is mounted only once the splash is dismissed. That keeps its
/// first-run onboarding cover from racing the splash — the cover presents
/// cleanly above a fully faded-in app instead of animating up behind it.
struct AppRootView: View {
    private enum LaunchPhase { case splash, ready }

    @State private var phase: LaunchPhase = .splash

    var body: some View {
        ZStack {
            if phase == .ready {
                RootView()
                    .transition(.opacity)
            }
            if phase == .splash {
                SplashView()
                    .transition(.opacity)
            }
        }
        // App-wide typography: SF Rounded. Set once at the root so every text
        // style (.headline/.body/.caption…) and presented sheet inherits it,
        // matching the rounded splash + brand mark.
        .fontDesign(.rounded)
        .task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeInOut(duration: 0.45)) { phase = .ready }
        }
    }
}

#Preview {
    AppRootView()
        .modelContainer(.preview)
        .environment(CurrencyService())
        .environment(PurchaseManager.preview(isPro: true))
}
