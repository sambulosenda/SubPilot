//
//  RecurraMarkView.swift
//  Rubradar
//

import SwiftUI

/// The Recurra app mark, drawn natively and animated: a near-closed teal ring
/// (the recurring loop) draws itself on, then the dot pops into the opening.
/// Settles to the exact app-icon mark. Geometry is taken 1:1 from the shipped
/// `AppIcon` (measured in 512-space): ring midline radius 135, stroke 47, dot at
/// (348, 145) r51, opening centred on the dot at ~1 o'clock.
///
/// Vector-native (no Lottie dependency): crisp at any size, and `reduceMotion`
/// simply renders the settled mark with no motion.
struct RecurraMarkView: View {
    enum Style {
        /// Dark gradient app-icon tile (splash / launch).
        case tile
        /// No tile — the mark alone in `tint`, for use on app surfaces such as
        /// empty states and loaders.
        case plain
    }

    /// Tile / mark side length in points. All geometry scales from this.
    var size: CGFloat = 132
    var style: Style = .tile
    /// Mark colour for `.plain` style (ignored for `.tile`, which uses the icon teal).
    var tint: Color = .brand
    /// When false, the mark renders in its final settled state immediately.
    var animated: Bool = true
    /// When true (`.plain` only), a soft radar "ping" emanates on a loop after
    /// the mark draws on — a calm "watching for subscriptions" idle.
    var looping: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var ringProgress: CGFloat = 0
    @State private var dotShown = false
    @State private var pinging = false

    // Tile + on-tile mark colours, matched to AppIcon-1024.
    private let tileMark = Color(hex: "1FC3AE") ?? .teal
    private let tileTop = Color(hex: "0B544D") ?? .teal
    private let tileBottom = Color(hex: "04211D") ?? .black

    private var markColor: Color { style == .tile ? tileMark : tint }
    private var corner: CGFloat { size * 0.2237 } // iOS continuous-squircle ratio
    private var unit: CGFloat { size / 512 }      // 512-space → points
    private var settled: Bool { !animated || reduceMotion }

    var body: some View {
        ZStack {
            if style == .tile {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tileTop, tileBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            if style == .plain && looping && !settled {
                // Sonar ping: a faint ring expanding past the mark and fading,
                // restarting each cycle. Sized to the ring midline.
                Circle()
                    .stroke(tint.opacity(0.4), lineWidth: 18 * unit)
                    .frame(width: 270 * unit, height: 270 * unit)
                    .scaleEffect(pinging ? 1.7 : 1.0)
                    .opacity(pinging ? 0 : 0.4)
            }

            RecurraRingArc(progress: settled ? 1 : ringProgress)
                .stroke(markColor, style: StrokeStyle(lineWidth: 47 * unit, lineCap: .round))
                .frame(width: size, height: size)

            Circle()
                .fill(markColor)
                .frame(width: 102 * unit, height: 102 * unit)
                // Dot centre (348,145) relative to tile centre (256,256).
                .offset(x: 92 * unit, y: -111 * unit)
                .scaleEffect(settled || dotShown ? 1 : 0)
                .opacity(settled || dotShown ? 1 : 0)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: style == .tile ? corner : 0, style: .continuous))
        .onAppear(perform: play)
    }

    private func play() {
        guard !settled else { return }
        // Ring draws on with a deep ease-out (no bounce) — the loop completing.
        withAnimation(.timingCurve(0.0, 0.65, 0.51, 0.99, duration: 0.78)) {
            ringProgress = 1
        }
        // Dot lands into the opening once the loop is nearly closed, with a
        // small spring overshoot for life.
        withAnimation(.spring(response: 0.36, dampingFraction: 0.6).delay(0.62)) {
            dotShown = true
        }
        if style == .plain && looping {
            // Calm, slow ping that begins once the mark has settled.
            withAnimation(.easeOut(duration: 2.4).delay(0.9).repeatForever(autoreverses: false)) {
                pinging = true
            }
        }
    }
}

/// The open ring as an animatable arc. `progress` 0→1 sweeps the drawn portion
/// (80% of the circle) clockwise from one terminal, leaving a 72° opening
/// centred on the dot.
private struct RecurraRingArc: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    // Opening centred at screen-310°; drawn arc is the complementary 288° (80%).
    private static let drawnSweep: Double = 288
    private static let startAngle: Double = 346 // gap spans 274°…346°

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * (135.0 / 512.0)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(Self.startAngle),
            endAngle: .degrees(Self.startAngle + Self.drawnSweep * Double(progress)),
            clockwise: false
        )
        return path
    }
}

#Preview("Tile — splash") {
    RecurraMarkView(size: 160)
        .padding(40)
}

#Preview("Plain — empty state") {
    RecurraMarkView(size: 112, style: .plain, looping: true)
        .padding(60)
}
