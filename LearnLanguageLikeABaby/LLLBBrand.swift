import SwiftUI

// MARK: - LLLB Brand Colors
//
// These four colors form the LLLB logo system.
// Free user → orange background + cream text
// Premium user → heraldic blue background + lemon gold text
//
// Hex values:
//   #F27640 — orange (free logo background)
//   #FDF6E8 — cream (free logo text)
//   #1A4187 — heraldic blue (premium logo background)
//   #F0BF00 — lemon gold (premium logo text)

extension Color {

    /// Free user brand color · Logo background
    /// Hex: #F27640
    static let lllbBrandOrange = Color(red: 0.949, green: 0.463, blue: 0.251)

    /// Free user logo text · Cream
    /// Hex: #FDF6E8
    static let lllbBrandCream = Color(red: 0.992, green: 0.965, blue: 0.910)

    /// Premium user brand color · Logo background
    /// Hex: #1A4187
    static let lllbBrandBlue = Color(red: 0.102, green: 0.255, blue: 0.529)

    /// Premium accent · Logo text on blue
    /// Hex: #F0BF00
    static let lllbBrandGold = Color(red: 0.941, green: 0.749, blue: 0.000)
}

// MARK: - Convenience Logo View
//
// Drop-in SwiftUI view that renders the appropriate logo based on
// the user's subscription state. Uses asset catalog references —
// place LLLBLogoFree.svg and LLLBLogoPremium.svg in Assets.xcassets.

struct LLLBLogo: View {
    enum Variant {
        case free
        case premium
    }

    let variant: Variant
    var size: CGFloat = 60

    var body: some View {
        Image(variant == .premium ? "LLLBLogoPremium" : "LLLBLogoFree")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

// MARK: - Pure-code fallback (no asset needed)
//
// If you'd rather render the logo entirely in SwiftUI without
// adding the SVG to the asset catalog, this works:

struct LLLBLogoCoded: View {
    enum Variant {
        case free
        case premium

        var background: Color {
            self == .premium ? .lllbBrandBlue : .lllbBrandOrange
        }
        var foreground: Color {
            self == .premium ? .lllbBrandGold : .lllbBrandCream
        }
    }

    let variant: Variant
    var size: CGFloat = 60

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(variant.background)
            Text("LLLB")
                .font(.system(size: size * 0.31, weight: .heavy))
                .tracking(-size * 0.014)
                .foregroundStyle(variant.foreground)
        }
        .frame(width: size, height: size)
    }
}
