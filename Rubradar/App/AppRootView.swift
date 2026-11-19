//
//  AppRootView.swift
//  Rubradar
//

import SwiftUI
import SwiftData

/// Top-level container that shows the branded `SplashView` on cold start, just
/// long enough for the mark to finish drawing, then cross-fades into the main
/// `RootView`. Kept short on purpose: every extra beat here is time the user
/// spends waiting on the app they just opened.
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
        // Widget deep links land here — the only view mounted from the very
        // first frame. During the splash hold `RootView` doesn't exist yet, so
        // handling URLs there would drop cold-launch taps; buffering through
        // `AppRouter.pendingAction` (like App Intents) is launch-order-proof.
        .onOpenURL { url in
            if let action = AppRouter.action(for: url) {
                AppRouter.shared.pendingAction = action
            }
        }
        .task {
            // The mark's own entrance takes 0.55s; hand off right after it.
            try? await Task.sleep(for: .seconds(0.7))
            withAnimation(.easeInOut(duration: 0.3)) { phase = .ready }
        }
    }
}

#Preview {
    AppRootView()
        .modelContainer(.preview)
        .environment(CurrencyService())
        .environment(PurchaseManager.preview(isPro: true))
}
