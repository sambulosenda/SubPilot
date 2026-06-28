//
//  Motion.swift
//  Rubradar
//

import SwiftUI

/// The app's shared motion vocabulary. Centralising the curves + entrance/press
/// behaviour keeps the whole app moving with one personality and puts
/// reduce-motion handling in a single place (see `appearEntrance` / `.pressable`).
enum AppMotion {
    /// Fade + rise entrance for first-show content. Matches the splash and
    /// empty-state feel already in the app.
    static let entrance: Animation = .smooth(duration: 0.5)
    /// Reduce-motion entrance: a quick cross-fade with no travel.
    static let entranceReduced: Animation = .easeIn(duration: 0.25)
    /// Snappy state changes — selection, toggles, plan picks.
    static let select: Animation = .snappy(duration: 0.28)
    /// Interactive press feedback for tappable cards.
    static let press: Animation = .spring(response: 0.3, dampingFraction: 0.6)

    /// Delay between adjacent siblings entering, so a screen settles top-down
    /// rather than snapping in as one block.
    static let staggerStep: Double = 0.06
    /// How far content rises into place during an entrance.
    static let entranceRise: CGFloat = 14
}

// MARK: - Entrance

/// One-shot fade + rise that staggers by `index`. Plays once: the internal
/// `appeared` flag persists with the view, so a re-`onAppear` (e.g. switching
/// back to a tab) is a no-op. Reduce-motion degrades to an in-place cross-fade.
private struct AppearEntrance: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: (appeared || reduceMotion) ? 0 : AppMotion.entranceRise)
            .onAppear {
                guard !appeared else { return }
                let base = reduceMotion ? AppMotion.entranceReduced : AppMotion.entrance
                let delay = reduceMotion ? 0 : Double(index) * AppMotion.staggerStep
                withAnimation(base.delay(delay)) { appeared = true }
            }
    }
}

extension View {
    /// Fades + rises content into place on first appearance, staggered by
    /// `index` (0 = first). Use on the handful of siblings that make up a
    /// screen's hero so it settles in rather than snapping. Avoid inside `List`
    /// rows — `List` owns row appearance.
    func appearEntrance(_ index: Int = 0) -> some View {
        modifier(AppearEntrance(index: index))
    }
}

// MARK: - Press feedback

/// A button style that gently scales on press, for tappable cards that aren't
/// system controls (e.g. a custom plan row). Reduce-motion holds it steady.
struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .animation(AppMotion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    /// Plain button that scales slightly on press. Use for tappable cards.
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

// MARK: - Navigation zoom

extension View {
    /// Applies a zoom navigation transition when an `id` + `namespace` are
    /// supplied, and is a no-op otherwise — so a destination can be built with
    /// or without a matched source (e.g. previews) from one call site.
    @ViewBuilder
    func zoomNavigationTransition<ID: Hashable>(id: ID?, in namespace: Namespace.ID?) -> some View {
        #if os(iOS)
        if let id, let namespace {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
        #else
        self
        #endif
    }
}
