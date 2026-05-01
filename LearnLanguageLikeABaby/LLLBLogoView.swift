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

    var body: some View {
        let diameter = ringDiameter(for: size)
        let radius = diameter / 2
        let stroke = radius * 0.17
        let spacing = diameter * 0.945

        ZStack {
            background

            // Rings
            ZStack {
                ring(color: orange, offset: .init(width: -spacing / 2, height: -spacing / 2), diameter: diameter, stroke: stroke)
                ring(color: green,  offset: .init(width:  spacing / 2, height: -spacing / 2), diameter: diameter, stroke: stroke)
                ring(color: blue,   offset: .init(width: -spacing / 2, height:  spacing / 2), diameter: diameter, stroke: stroke)
                ring(color: gold,   offset: .init(width:  spacing / 2, height:  spacing / 2), diameter: diameter, stroke: stroke)
            }

            // Centered LLLB on a translucent bg block
            text
                .padding(.vertical, size * 0.012)
                .padding(.horizontal, size * 0.020)
                .background(background.opacity(0.9))
        }
        .frame(width: size, height: size)
        .clipped()
    }

    // MARK: - Pieces

    private func ring(color: Color, offset: CGSize, diameter: CGFloat, stroke: CGFloat) -> some View {
        Circle()
            .strokeBorder(color, lineWidth: stroke)
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
