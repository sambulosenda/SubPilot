//
//  OnboardingChrome.swift
//  Rubradar
//

import SwiftUI

// MARK: - Backdrop

/// The ambient brand field behind every onboarding page. Two very soft colour
/// blobs drift to new positions as the page changes, so the four pages read as
/// one continuous surface rather than four separate white screens — the same
/// device the paywall uses, keeping one voice across the app's first two moments.
///
/// It also does load-bearing work: onboarding previously inherited the plain
/// white window background, which made `cardStyle()` (a *white*
/// `secondarySystemGroupedBackground`) invisible on the starter step. Basing the
/// backdrop on `Color.appBackground` restores the grouped-background contract
/// every card in the app is drawn against.
struct OnboardingBackdrop: View {
    /// The current page's accent, which drives the lower blob.
    let tint: Color
    /// Page index — the blobs reposition when it changes.
    let phase: Int

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.appBackground

            // Reduce Transparency users get the flat grouped background: the
            // wash is decorative, and cards must stay maximally legible.
            if !reduceTransparency {
                blob(Color.brand, diameter: 560)
                    .offset(brandOffset)
                blob(tint, diameter: 460)
                    .offset(tintOffset)
            }
        }
        .ignoresSafeArea()
        // Slow enough to read as atmosphere rather than a transition effect.
        .animation(reduceMotion ? .easeInOut(duration: 0.3) : .smooth(duration: 0.9), value: phase)
        .accessibilityHidden(true)
    }

    private func blob(_ color: Color, diameter: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.26), color.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter / 2
                )
            )
            .frame(width: diameter, height: diameter)
            .blur(radius: 30)
    }

    /// Blob placements per page. Hand-picked rather than generated so each page
    /// gets a deliberate composition (and the travel between them stays gentle).
    private var brandOffset: CGSize {
        switch phase {
        case 0: return CGSize(width: 130, height: -250)
        case 1: return CGSize(width: -150, height: -200)
        case 2: return CGSize(width: 160, height: -330)
        default: return CGSize(width: -120, height: -260)
        }
    }

    private var tintOffset: CGSize {
        switch phase {
        case 0: return CGSize(width: -140, height: 280)
        case 1: return CGSize(width: 150, height: 240)
        case 2: return CGSize(width: -170, height: 360)
        default: return CGSize(width: 140, height: 270)
        }
    }
}

// MARK: - Hero

/// The page's visual, in a **fixed 168pt footprint** so it never shifts position
/// between pages — the pages change content around a stationary anchor, which is
/// what makes a sequence feel composed rather than assembled.
///
/// Symbols sit in a tinted well with a slowly breathing halo; the brand mark
/// brings its own sonar idle and gets the bare slot (a ring inside a ring would
/// fight itself).
struct OnboardingHero: View {
    enum Kind: Equatable {
        case brandMark
        case symbol(String)
    }

    let kind: Kind
    let tint: Color

    @State private var symbolPlayed = false
    @State private var breathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// At accessibility text sizes the copy needs the room far more than the
    /// decoration does, so the whole hero steps down proportionally.
    private var scale: CGFloat { dynamicTypeSize.isAccessibilitySize ? 0.68 : 1 }
    private var slot: CGFloat { 220 * scale }
    private var well: CGFloat { 156 * scale }

    var body: some View {
        ZStack {
            switch kind {
            case .brandMark:
                // The shipped app mark, so the very first screen is
                // unmistakably SubHelm.
                RecurraMarkView(size: well + 12 * scale, style: .plain, tint: tint, looping: true)
            case .symbol(let name):
                symbolWell(name)
            }
        }
        .frame(width: slot, height: slot)
        .accessibilityHidden(true)
    }

    private func symbolWell(_ name: String) -> some View {
        ZStack {
            // Halo — the same calm "watching" pulse as the brand mark's sonar.
            // Blurred so it reads as light rather than a second hard-edged disc.
            Circle()
                .fill(tint.opacity(0.10))
                .frame(width: slot, height: slot)
                .blur(radius: 10)
                .scaleEffect(breathing ? 1.0 : 0.88)
                .opacity(breathing ? 0.7 : 1)

            // A card-white well, not a tinted one: a hierarchical symbol's
            // secondary layer is a pale wash of `tint`, which disappeared
            // against a tinted disc. White also echoes the app's card language.
            Circle()
                .fill(Color.cardBackground)
                .frame(width: well, height: well)
                .overlay {
                    Circle().strokeBorder(tint.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: tint.opacity(0.18), radius: 18, y: 8)

            // Sized to fill the well the way the brand mark fills its slot —
            // at 56pt the glyph read as a detail floating in a big empty disc.
            Image(systemName: name)
                .font(.system(size: 84 * scale, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .symbolEffect(.bounce, options: .nonRepeating, value: symbolPlayed)
        }
        .task {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                breathing = true
            }
            try? await Task.sleep(for: .milliseconds(280))
            symbolPlayed = true
        }
    }
}

// MARK: - Page transition

/// Pages travel a short distance along the reading axis while fading and
/// defocusing, so advancing reads as *progress* instead of a cross-dissolve.
/// The travel is deliberately small (36pt) — a full-width carousel slide reads
/// as a photo gallery, not a setup flow.
struct PageSlide: Transition {
    /// The edge content enters from (insertion) or leaves toward (removal).
    var edge: HorizontalEdge

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .offset(x: phase.isIdentity ? 0 : (edge == .trailing ? 36 : -36))
            .blur(radius: phase.isIdentity ? 0 : 6)
    }
}

// MARK: - Progress

/// Step indicator. The current step stretches into a capsule rather than just
/// changing colour, so progress is legible at a glance and in peripheral vision.
struct PageProgress: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: i == index ? 24 : 7, height: 7)
            }
        }
        .animation(.snappy(duration: 0.32), value: index)
        // Surface progress to VoiceOver instead of hiding the dots outright.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(index + 1) of \(count)")
    }
}

#Preview("Hero — symbol") {
    OnboardingHero(kind: .symbol("bell.badge.fill"), tint: .orange)
        .padding(60)
        .background { OnboardingBackdrop(tint: .orange, phase: 3) }
}

#Preview("Hero — mark") {
    OnboardingHero(kind: .brandMark, tint: .accentColor)
        .padding(60)
        .background { OnboardingBackdrop(tint: .accentColor, phase: 0) }
}
