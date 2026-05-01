import SwiftUI

// MARK: - LLLB Design System — Color tokens
// Source of truth: LLLB_Design_System.md

extension Color {
    /// Accent: #9B6B2F (light) / #CC9B6D (dark)
    static let lllbAccent = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 204/255, green: 155/255, blue: 109/255, alpha: 1)
            : UIColor(red: 155/255, green: 107/255, blue:  47/255, alpha: 1)
    })
    /// Main background: #F0EFF4 (light) / #0E0D12 (dark)
    static let lllbBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red:  14/255, green:  13/255, blue:  18/255, alpha: 1)
            : UIColor(red: 240/255, green: 239/255, blue: 244/255, alpha: 1)
    })
    /// Cell / control stroke: rgba(60,60,67,0.10) light / rgba(255,255,255,0.08) dark
    static let lllbCellStroke = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.08)
            : UIColor(red: 60/255, green: 60/255, blue: 67/255, alpha: 0.10)
    })
    /// Token chip default background: rgba(255,255,255,0.75) light / rgba(255,255,255,0.06) dark
    static let lllbChipBg = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.06)
            : UIColor(white: 1, alpha: 0.75)
    })
    /// Token chip stroke: rgba(60,60,67,0.10) light / rgba(255,255,255,0.09) dark
    static let lllbChipStroke = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.09)
            : UIColor(red: 60/255, green: 60/255, blue: 67/255, alpha: 0.10)
    })
    /// Secondary text: IPA, translation, labels — rgba(60,60,67,0.65) light / rgba(255,255,255,0.50) dark
    static let lllbSecondaryText = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.50)
            : UIColor(red: 60/255, green: 60/255, blue: 67/255, alpha: 0.65)
    })
    /// Tag chip background: rgba(60,60,67,0.06) light / rgba(255,255,255,0.07) dark
    static let lllbTagBg = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.07)
            : UIColor(red: 60/255, green: 60/255, blue: 67/255, alpha: 0.06)
    })
    /// Tag chip stroke: rgba(60,60,67,0.10) light / rgba(255,255,255,0.09) dark
    static let lllbTagStroke = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.09)
            : UIColor(red: 60/255, green: 60/255, blue: 67/255, alpha: 0.10)
    })
    /// Top-bar / separator line: rgba(0,0,0,0.06) light / rgba(255,255,255,0.06) dark
    static let lllbSeparator = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.06)
            : UIColor(white: 0, alpha: 0.06)
    })
    /// Selected icon foreground: rgba(44,44,46,0.82) light / rgba(255,255,255,0.85) dark
    static let lllbSelectedFg = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.85)
            : UIColor(red: 44/255, green: 44/255, blue: 46/255, alpha: 0.82)
    })
    /// Selected icon background tint: rgba(44,44,46,0.07) light / rgba(255,255,255,0.08) dark
    static let lllbSelectedBg = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.08)
            : UIColor(white: 0, alpha: 0.07)
    })
    /// Selected icon stroke: rgba(44,44,46,0.18) light / rgba(255,255,255,0.20) dark
    static let lllbSelectedStroke = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.20)
            : UIColor(white: 0, alpha: 0.18)
    })
    /// Streak orange: #FF9500
    static let lllbStreak = Color(red: 1, green: 149/255, blue: 0)

    /// Progress ring colors: [今天, 本周, 本月, 全部]
    static let lllbRingColors: [Color] = [
        Color(red: 240/255, green: 120/255, blue:  64/255),  // 今天 #F07840
        Color(red:  46/255, green: 170/255, blue:  96/255),  // 本周 #2EAA60
        Color(red:  40/255, green: 104/255, blue: 208/255),  // 本月 #2868D0
        Color(red: 240/255, green: 192/255, blue:   0/255),  // 全部 #F0C000
    ]
}
