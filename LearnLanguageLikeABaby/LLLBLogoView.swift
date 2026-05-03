import SwiftUI

/// Brand logo: four overlapping rings (TL orange, TR green, BL blue, BR gold)
/// with "LLLB" in Raleway Bold at the center, on a translucent background block.
///
/// Geometry derives entirely from `size`:
/// - ring center spacing = ring diameter × 0.945
/// - stroke width = ring radius × 0.17
/// Text adapts to color scheme: dark text on light bg, white text on dark bg.
struct LLLBLogoView: View {
    /// Total side length of the square logo, in points.
    let size: CGFloat

    /// Background color — used both as the canvas color and as the
    /// (alpha 0.9) text-block color so the logo blends with its host.
    /// Defaults to the system background (light/dark aware).
    var background: Color = Color(UIColor.systemBackground)

    /// When true, on first appearance the four rings draw themselves
    /// (each starting from its own offset angle, slightly staggered) and
    /// the centred text fades in once the rings close.
    var animated: Bool = false

    @State private var drawProgress: CGFloat = 0     // 0…1, drives all rings
    @State private var textShown:    Bool    = false

    /// Per-ring (delay, startAngleDegrees). Stagger + irregular start points
    /// so the four rings don't feel like a 4-piece pinwheel.
    private static let ringTimings: [(delay: Double, angle: Double)] = [
        (0.00,  -90),    // orange (TL): starts at top, draws clockwise
        (0.10,   40),    // green  (TR): starts lower-right, sweeps round
        (0.20,  170),    // blue   (BL): starts lower-left
        (0.30,  -30),    // gold   (BR): starts upper-right
    ]

    var body: some View {
        let diameter = ringDiameter(for: size)
        let radius = diameter / 2
        let stroke = radius * 0.17
        let spacing = diameter * 0.945
        let colors  = [orange, green, blue, gold]
        let offsets: [CGSize] = [
            .init(width: -spacing / 2, height: -spacing / 2),
            .init(width:  spacing / 2, height: -spacing / 2),
            .init(width: -spacing / 2, height:  spacing / 2),
            .init(width:  spacing / 2, height:  spacing / 2),
        ]

        ZStack {
            background

            // Rings
            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    ring(
                        color:    colors[i],
                        offset:   offsets[i],
                        diameter: diameter,
                        stroke:   stroke,
                        delay:    Self.ringTimings[i].delay,
                        startAngle: Self.ringTimings[i].angle
                    )
                }
            }

            // Centered LLLB on a translucent bg block
            text
                .padding(.vertical, size * 0.012)
                .padding(.horizontal, size * 0.020)
                .background(background.opacity(0.9))
                .opacity(animated ? (textShown ? 1 : 0) : 1)
                .scaleEffect(animated ? (textShown ? 1 : 0.86) : 1)
        }
        .frame(width: size, height: size)
        .clipped()
        .onAppear { runIntroIfNeeded() }
    }

    private func runIntroIfNeeded() {
        guard animated else {
            drawProgress = 1
            textShown    = true
            return
        }
        guard drawProgress == 0 else { return }   // run once

        // Rings draw over ~1.4s. Each ring's local progress is computed in
        // ringTrimEnd() using its own delay; a single global animation keeps
        // them in sync.
        withAnimation(.timingCurve(0.22, 0.9, 0.32, 1.0, duration: 1.4)) {
            drawProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                textShown = true
            }
        }
    }

    /// Local 0…1 progress for one ring, given the global drawProgress.
    /// Each ring takes 70% of the total timeline (after its delay) to close.
    private func ringTrimEnd(delay: Double) -> CGFloat {
        guard animated else { return 1 }
        let localDuration = 0.70
        let g = Double(drawProgress)
        let p = (g - delay) / localDuration
        return CGFloat(min(1, max(0, p)))
    }

    // MARK: - Pieces

    private func ring(color: Color, offset: CGSize, diameter: CGFloat, stroke: CGFloat,
                      delay: Double, startAngle: Double) -> some View {
        // .inset(by: stroke/2) keeps the stroked path visually identical to the
        // original .strokeBorder rendering (both axes contained within frame).
        Circle()
            .inset(by: stroke / 2)
            .trim(from: 0, to: ringTrimEnd(delay: delay))
            .stroke(color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
            .rotationEffect(.degrees(startAngle))
            .frame(width: diameter, height: diameter)
            .offset(offset)
    }

    private var text: some View {
        Text("LLLB")
            .font(.custom("RalewayRoman-Bold", size: ringDiameter(for: size) / 2 * 0.78))
            .tracking(size * 0.045)
            .foregroundStyle(textColor)
            .scaleEffect(x: 1.2, y: 1.0, anchor: .center)
            .fixedSize()
    }

    /// Diameter chosen so two rings span ~91% of `size` after accounting for the
    /// 0.945 overlap factor. Matches the reference rendering.
    private func ringDiameter(for size: CGFloat) -> CGFloat {
        let usable = size * 0.91
        return usable / 1.945
    }

    // MARK: - Colors (per spec)

    private let orange = Color(red: 0xF0/255.0, green: 0x78/255.0, blue: 0x40/255.0)
    private let green  = Color(red: 0x2E/255.0, green: 0xAA/255.0, blue: 0x60/255.0)
    private let blue   = Color(red: 0x28/255.0, green: 0x68/255.0, blue: 0xD0/255.0)
    private let gold   = Color(red: 0xF0/255.0, green: 0xC0/255.0, blue: 0x00/255.0)

    private var textColor: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? .white : UIColor(white: 0.2, alpha: 1)
        })
    }
}

#Preview("Light") {
    LLLBLogoView(size: 240)
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    LLLBLogoView(size: 240)
        .preferredColorScheme(.dark)
}
