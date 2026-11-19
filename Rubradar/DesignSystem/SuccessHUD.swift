//
//  SuccessHUD.swift
//  Rubradar
//

import SwiftUI

/// A brief, non-blocking success confirmation: a teal badge whose checkmark
/// draws on with a spring + success haptic, over a material card. Shown after a
/// subscription is added. Present via `.successHUD(_:)`; it auto-dismisses.
struct SuccessHUD: View {
    var message: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var checkProgress: CGFloat = 0

    private let badge: CGFloat = 64
    private let teal = Color.brand

    var body: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle().fill(teal)
                Checkmark(progress: reduceMotion ? 1 : checkProgress)
                    .stroke(.white, style: StrokeStyle(lineWidth: badge * 0.1, lineCap: .round, lineJoin: .round))
                    .frame(width: badge * 0.5, height: badge * 0.42)
            }
            .frame(width: badge, height: badge)

            Text(message)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .scaleEffect(appeared || reduceMotion ? 1 : 0.82)
        .opacity(appeared ? 1 : 0)
        .sensoryFeedback(.success, trigger: appeared)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
        .onAppear(perform: animateIn)
    }

    private func animateIn() {
        guard !reduceMotion else { appeared = true; return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            appeared = true
        }
        withAnimation(.easeOut(duration: 0.35).delay(0.12)) {
            checkProgress = 1
        }
    }
}

/// A checkmark stroke, trimmable for a draw-on reveal.
private struct Checkmark: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path.trimmedPath(from: 0, to: progress)
    }
}

extension View {
    /// Overlays a brief success HUD while `message` is non-nil, then clears it.
    func successHUD(_ message: Binding<String?>) -> some View {
        overlay {
            if let text = message.wrappedValue {
                SuccessHUD(message: text)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .task {
                        // Long enough to read a figure ("Saved £182.52 a
                        // year"), not just register a tick: at 1.4s it was
                        // already fading as the sheet above it finished
                        // closing.
                        try? await Task.sleep(for: .seconds(2.2))
                        withAnimation(.easeOut(duration: 0.25)) { message.wrappedValue = nil }
                    }
            }
        }
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        SuccessHUD(message: "Subscription added")
    }
}
