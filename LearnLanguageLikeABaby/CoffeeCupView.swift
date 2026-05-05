import SwiftUI

/// Tall tapered "to-go cup" with a flat lid and small tick marks inside.
/// Liquid level shows remaining minutes. Premium users see a full cup with
/// an ♾️ overlay.
struct CoffeeCupView: View {
    /// 0…1 fill level (0 = empty, 1 = full).
    let progress: Double
    /// True for subscribers — cup is locked full and infinity glyph appears.
    let isPremium: Bool
    /// Total height of the cup glyph (lid + body) in points.
    var size: CGFloat = 24

    /// Visible fill ratio — premium overrides the real cup level so the cup
    /// reads as full whenever the user has unlimited time.
    private var displayProgress: Double { isPremium ? 1 : progress }

    /// Color tier for the coffee — shifts amber → red as it drains.
    private var fillColor: Color {
        if isPremium { return Self.coffeeBrown }
        switch progress {
        case ..<0.10: return Self.warningRed
        case ..<0.25: return Self.amber
        default:      return Self.coffeeBrown
        }
    }

    private var emptyColor: Color { Color.secondary.opacity(0.10) }
    private var outline:   Color { Color.primary.opacity(0.75) }
    private var lidFill:   Color { Color(white: 0.92) }

    private var bodyHeight: CGFloat { size * 0.84 }
    private var lidHeight:  CGFloat { size * 0.14 }
    private var cupWidth:   CGFloat { size * 0.62 }
    private var lidWidth:   CGFloat { cupWidth * 1.10 }

    var body: some View {
        VStack(spacing: 0) {
            // Lid — slightly wider than cup top to overhang a bit.
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 3, bottomLeading: 1, bottomTrailing: 1, topTrailing: 3),
                style: .continuous
            )
            .fill(lidFill)
            .overlay(
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 3, bottomLeading: 1, bottomTrailing: 1, topTrailing: 3),
                    style: .continuous
                )
                .stroke(outline, lineWidth: 0.9)
            )
            .frame(width: lidWidth, height: lidHeight)

            // Cup body
            ZStack {
                // Empty tint
                CupBodyShape().fill(emptyColor)

                // Coffee fill (clipped to bottom-up portion)
                CupBodyShape()
                    .fill(fillColor)
                    .mask(alignment: .bottom) {
                        Rectangle().frame(height: bodyHeight * displayProgress)
                    }

                // Tick marks at 1/3 and 2/3 — visible "measuring cup" feel
                if !isPremium {
                    tickMarks
                }

                // Outline
                CupBodyShape().stroke(outline, lineWidth: 0.9)

                if isPremium {
                    Image(systemName: "infinity")
                        .font(.system(size: bodyHeight * 0.40, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: cupWidth, height: bodyHeight)
        }
        .frame(width: lidWidth, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPremium ? "Unlimited playback time" : "Playback time remaining")
    }

    @ViewBuilder
    private var tickMarks: some View {
        // Two short interior tick marks (1/3, 2/3 from top) on the right side.
        // Subtle: short width, low opacity — reads as cup measurement notches.
        let tickColor = outline.opacity(0.55)
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let tickW = w * 0.22
            Path { p in
                for frac in [1.0/3.0, 2.0/3.0] {
                    let y = h * frac
                    p.move(to: CGPoint(x: w - tickW - w * 0.10, y: y))
                    p.addLine(to: CGPoint(x: w - w * 0.10, y: y))
                }
            }
            .stroke(tickColor, style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
        }
    }

    // MARK: - Palette (intentionally NOT brand color — must read as coffee)
    private static let coffeeBrown = Color(red: 0x7B/255.0, green: 0x4F/255.0, blue: 0x32/255.0)
    private static let amber       = Color(red: 0xD4/255.0, green: 0xA0/255.0, blue: 0x4A/255.0)
    private static let warningRed  = Color(red: 0xD9/255.0, green: 0x4A/255.0, blue: 0x35/255.0)
}

/// Trapezoidal cup body — slightly narrower at the bottom (Starbucks-tall feel).
private struct CupBodyShape: Shape {
    /// Bottom width as fraction of top width.
    var taper: CGFloat = 0.82

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let bottomInset = rect.width * (1 - taper) / 2
        let topLeft     = CGPoint(x: rect.minX,                y: rect.minY)
        let topRight    = CGPoint(x: rect.maxX,                y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX - bottomInset,  y: rect.maxY)
        let bottomLeft  = CGPoint(x: rect.minX + bottomInset,  y: rect.maxY)
        p.move(to: topLeft)
        p.addLine(to: topRight)
        p.addLine(to: bottomRight)
        // Subtle curve at bottom for "rounded base" feel
        p.addQuadCurve(to: bottomLeft,
                       control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.04))
        p.closeSubpath()
        return p
    }
}

// MARK: - Refill menu

/// Center-screen refill card — replaces the old long-press menu. Single tap
/// on the coffee cup opens this. Shows current usage + three refill paths:
/// candy single shot, candy top-up to full, or watch-ad. Tap-outside dismisses.
struct CoffeeRefillMenu: View {
    let nativeLanguage:  String
    let candyBalance:    Int
    /// Minutes currently in the cup (0…45).
    let cupMinutes:      Int
    /// True when the cup has at least one full refill unit (10 min) of free space.
    /// Drives whether single-refill buttons are clickable.
    let canRefillSingle: Bool
    /// True when the cup is below capacity.
    let canTopUp:        Bool
    /// Candy needed to top the cup back to capacity (0 when already full).
    let topUpCost:       Int
    let isPremium:       Bool
    /// When non-nil, the unlimited card shows a "X days left" countdown — the
    /// onboarding promo is the source. Nil for subscriptions or DEBUG override.
    var promoDaysRemaining: Int? = nil
    let onUseCandy:  () -> Void
    let onTopUp:     () -> Void
    let onWatchAd:   () -> Void
    let onSubscribe: () -> Void
    let onClose:     () -> Void

    private var hasCandyForSingle: Bool { candyBalance >= PlaybackBudget.refillCandyCost }
    private var hasCandyForTopUp:  Bool { candyBalance >= topUpCost }
    private var singleEnabled:     Bool { canRefillSingle && hasCandyForSingle }
    private var topUpEnabled:      Bool { canTopUp && hasCandyForTopUp }
    private var adEnabled:         Bool { canRefillSingle }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            if isPremium {
                premiumCard
            } else {
                refillCard
            }
        }
    }

    // MARK: - Premium variant

    private var premiumCard: some View {
        VStack(spacing: 14) {
            Image(systemName: promoDaysRemaining != nil ? "gift.fill" : "infinity")
                .font(.system(size: 38, weight: .heavy))
                .foregroundStyle(Color.lllbRingColors[3])
            Text(L("无限时间", "Unlimited time", nativeLanguage: nativeLanguage))
                .font(.system(size: 17, weight: .semibold))
            Text(premiumSubtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            // 在 promo 期间也允许直接订阅——避免用户错过 7 天后再来时
            // 才发现入口；同时不在真实订阅状态下出现，避免错位 UX。
            if promoDaysRemaining != nil {
                Button {
                    Haptics.medium()
                    onClose()
                    onSubscribe()
                } label: {
                    Text(L("订阅 LLLB Pro",
                           "Subscribe to LLLB Pro",
                           nativeLanguage: nativeLanguage))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.lllbAccent)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Color.lllbAccent.opacity(0.10), in: Capsule())
                        .overlay(
                            Capsule().stroke(Color.lllbAccent.opacity(0.30), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.lllbCellStroke, lineWidth: 0.5)
        )
        .onTapGesture {}    // swallow taps inside
    }

    /// Subtitle copy depends on what's granting the unlimited time.
    /// Promo gets a countdown; subscription / DEBUG gets a thanks message.
    private var premiumSubtitle: String {
        if let days = promoDaysRemaining {
            if days == 1 {
                return L("新人礼包还剩最后 1 天 🎁",
                         "Welcome gift — 1 day left 🎁",
                         nativeLanguage: nativeLanguage)
            }
            return L("新人礼包还剩 \(days) 天 🎁",
                     "Welcome gift — \(days) days left 🎁",
                     nativeLanguage: nativeLanguage)
        }
        return L("感谢订阅 ☕️", "Thanks for subscribing ☕️", nativeLanguage: nativeLanguage)
    }

    // MARK: - Refill variant

    private var refillCard: some View {
        let minLabel = L("分", "min", nativeLanguage: nativeLanguage)

        return VStack(spacing: 18) {
            Text(L("☕ 咖啡时间", "☕ Coffee time", nativeLanguage: nativeLanguage))
                .font(.system(size: 16, weight: .semibold))

            // Battery-style "remaining / total". Big number = what's in the cup.
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(cupMinutes)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(cupMinutes > 0 ? Color.primary : Color.lllbRingColors[0])
                Text("/ \(PlaybackBudget.freeBudgetMinutes) \(minLabel)")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

            VStack(spacing: 10) {
                // Single candy refill — disabled when cup too full to absorb
                // a full unit (strict no-waste mode).
                Button {
                    guard singleEnabled else { return }
                    onUseCandy()
                } label: {
                    refillRow(
                        title:   "+\(PlaybackBudget.refillMinutes) \(minLabel)",
                        detail:  "\(PlaybackBudget.refillCandyCost) 🍬",
                        enabled: singleEnabled,
                        accent:  Color.lllbAccent
                    )
                }
                .buttonStyle(.plain)
                .disabled(!singleEnabled)

                // Bulk refill (floor units — always 1 candy = 10 min, no partials)
                Button {
                    guard topUpEnabled else { return }
                    onTopUp()
                } label: {
                    let topUpMins = topUpCost * PlaybackBudget.refillMinutes
                    refillRow(
                        title:   "+\(topUpMins) \(minLabel)",
                        detail:  canTopUp ? "\(topUpCost) 🍬" : "—",
                        enabled: topUpEnabled,
                        accent:  Color.lllbAccent
                    )
                }
                .buttonStyle(.plain)
                .disabled(!topUpEnabled)

                // Ad refill (placeholder until AdMob) — same strict rule as single
                Button {
                    guard adEnabled else { return }
                    onWatchAd()
                } label: {
                    refillRow(
                        title:   "+\(PlaybackBudget.refillMinutes) \(minLabel)",
                        detail:  L("看广告", "Watch ad", nativeLanguage: nativeLanguage),
                        enabled: adEnabled,
                        icon:    "play.rectangle.fill",
                        accent:  Color.lllbRingColors[1]
                    )
                }
                .buttonStyle(.plain)
                .disabled(!adEnabled)

                // Subscribe — always available
                Button(action: onSubscribe) {
                    refillRow(
                        title:   L("订阅无限", "Unlimited", nativeLanguage: nativeLanguage),
                        detail:  "∞",
                        enabled: true,
                        icon:    "infinity",
                        accent:  Color.lllbRingColors[3]
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 280)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.lllbCellStroke, lineWidth: 0.5)
        )
        .onTapGesture {}
    }

    @ViewBuilder
    private func refillRow(title: String, detail: String, enabled: Bool,
                           icon: String? = nil, accent: Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(enabled ? Color.primary : Color.secondary)
            Spacer()
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(enabled ? accent : Color.secondary)
            }
            Text(detail)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(enabled ? accent : Color.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(enabled ? accent.opacity(0.10) : Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(enabled ? accent.opacity(0.28) : Color.clear, lineWidth: 0.5)
        )
    }
}
