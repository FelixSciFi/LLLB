import SwiftUI

/// To-go coffee cup with continuous fill animation. Cream cup body with
/// rounded base, accent lid on top, coffee fills bottom-up by `progress`.
/// Below 25% the lid + coffee shift to a warning orange; functionally
/// empty (< 5%) shows a "sad straw" indicator. Premium users see a full
/// brown cup with an infinity-wave overlay.
///
/// All sub-shapes are drawn in a 24×24 viewBox matching `design/coffee-*.svg`.
struct CoffeeCupView: View {
    /// 0…1 fill level (0 = empty, 1 = full).
    let progress: Double
    /// True for subscribers — cup is locked full and infinity wave appears.
    let isPremium: Bool
    /// Total height of the cup glyph (lid + body) in points.
    var size: CGFloat = 24

    /// Visible fill ratio — premium overrides the real cup level so the
    /// cup reads as full whenever the user has unlimited time.
    private var displayProgress: Double { isPremium ? 1 : progress }

    /// Below 25% of capacity → accent + coffee shift to orange. Premium
    /// always reads as full + brown.
    private var isLow:   Bool { !isPremium && progress < 0.25 }
    /// Functionally drained — show the empty-state straw instead of a
    /// hairline of coffee. Slightly above strict 0 to absorb fractional
    /// minute math hovering around zero.
    private var isEmpty: Bool { !isPremium && progress < 0.05 }

    private var accent: Color { isLow ? Self.warningOrange : Self.coffeeBrown }

    var body: some View {
        let s = size / 24.0
        ZStack {
            // 1. Cup body — cream fill
            CupBodyShape().fill(Self.cream)

            // 2. Coffee fill — accent color, masked to bottom progress portion
            CupBodyShape()
                .fill(accent)
                .mask(CupFillMaskShape(progress: displayProgress))

            // 3. Pro infinity wave (over coffee, only when premium)
            if isPremium {
                ProInfinityWaveShape()
                    .stroke(
                        Self.cream,
                        style: StrokeStyle(lineWidth: 1.3 * s,
                                           lineCap: .round, lineJoin: .round)
                    )
            }

            // 4. Empty-state sad straw — vertical stick + dot at bottom
            if isEmpty {
                EmptyStrawShape()
                    .stroke(
                        Self.warningOrange,
                        style: StrokeStyle(lineWidth: 1.4 * s, lineCap: .round)
                    )
                EmptyStrawDot().fill(Self.warningOrange)
            }

            // 5. Cup body outline (drawn after fills so stroke sits on top)
            CupBodyShape()
                .stroke(accent, style: StrokeStyle(lineWidth: 1.2 * s, lineJoin: .round))

            // 6. Lid (above cup) — accent rounded rect with cream slot
            LidShape().fill(accent)
            LidSlotShape().fill(Self.cream)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPremium ? "Unlimited playback time" : "Playback time remaining")
    }

    // MARK: - Palette (NOT brand color — must read as coffee)
    private static let coffeeBrown   = Color(red: 0x9B/255.0, green: 0x6B/255.0, blue: 0x2F/255.0)
    private static let warningOrange = Color(red: 0xF2/255.0, green: 0x76/255.0, blue: 0x40/255.0)
    private static let cream         = Color(red: 0xFD/255.0, green: 0xF6/255.0, blue: 0xE8/255.0)
}

// MARK: - Sub-shapes (24×24 viewBox coords matching design/coffee-*.svg)

private struct CupBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p  = Path()
        let s  = min(rect.width, rect.height) / 24.0
        let dx = (rect.width  - 24 * s) / 2
        let dy = (rect.height - 24 * s) / 2
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: dx + x * s, y: dy + y * s)
        }
        p.move(to: pt(6.4, 7.8))
        p.addLine(to: pt(17.6, 7.8))
        p.addLine(to: pt(16.4, 19.5))
        p.addQuadCurve(to: pt(14.7, 21), control: pt(16.2, 21))
        p.addLine(to: pt(9.3, 21))
        p.addQuadCurve(to: pt(7.6, 19.5), control: pt(7.8, 21))
        p.closeSubpath()
        return p
    }
}

/// Mask = a horizontal stripe from `fillTop` to the cup floor (y=21).
/// Intersected with `CupBodyShape()` it yields the bottom-up coffee
/// portion. `animatableData` lets SwiftUI interpolate fill height.
private struct CupFillMaskShape: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let s   = min(rect.width, rect.height) / 24.0
        let dy  = (rect.height - 24 * s) / 2
        // Cup interior y range in viewBox: top=7.8 → bottom=21 (height 13.2).
        let topY:    CGFloat = 7.8
        let bottomY: CGFloat = 21.0
        let fillTopY = bottomY - (bottomY - topY) * CGFloat(progress)
        let r = CGRect(
            x: 0,
            y: dy + fillTopY * s,
            width: rect.width,
            height: rect.height - (dy + fillTopY * s)
        )
        return Path(r)
    }
}

private struct LidShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s  = min(rect.width, rect.height) / 24.0
        let dx = (rect.width  - 24 * s) / 2
        let dy = (rect.height - 24 * s) / 2
        let r = CGRect(x: dx + 5.5 * s, y: dy + 5 * s, width: 13 * s, height: 2.8 * s)
        return Path(roundedRect: r, cornerRadius: 0.6 * s)
    }
}

private struct LidSlotShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s  = min(rect.width, rect.height) / 24.0
        let dx = (rect.width  - 24 * s) / 2
        let dy = (rect.height - 24 * s) / 2
        let r = CGRect(x: dx + 9 * s, y: dy + 5.4 * s, width: 6 * s, height: 0.6 * s)
        return Path(roundedRect: r, cornerRadius: 0.3 * s)
    }
}

private struct ProInfinityWaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p  = Path()
        let s  = min(rect.width, rect.height) / 24.0
        let dx = (rect.width  - 24 * s) / 2
        let dy = (rect.height - 24 * s) / 2
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: dx + x * s, y: dy + y * s)
        }
        p.move(to: pt(9, 14.5))
        p.addCurve(to: pt(12, 14.5), control1: pt(9, 13),    control2: pt(10.5, 13))
        p.addCurve(to: pt(15, 14.5), control1: pt(13.5, 16), control2: pt(15, 16))
        p.addCurve(to: pt(12, 14.5), control1: pt(15, 13),   control2: pt(13.5, 13))
        p.addCurve(to: pt(9, 14.5),  control1: pt(10.5, 16), control2: pt(9, 16))
        p.closeSubpath()
        return p
    }
}

private struct EmptyStrawShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p  = Path()
        let s  = min(rect.width, rect.height) / 24.0
        let dx = (rect.width  - 24 * s) / 2
        let dy = (rect.height - 24 * s) / 2
        p.move(to: CGPoint(x: dx + 12 * s, y: dy + 11 * s))
        p.addLine(to: CGPoint(x: dx + 12 * s, y: dy + 16 * s))
        return p
    }
}

private struct EmptyStrawDot: Shape {
    func path(in rect: CGRect) -> Path {
        let s  = min(rect.width, rect.height) / 24.0
        let dx = (rect.width  - 24 * s) / 2
        let dy = (rect.height - 24 * s) / 2
        // Circle r=0.7 centered at (12, 18)
        let r = CGRect(x: dx + 11.3 * s, y: dy + 17.3 * s, width: 1.4 * s, height: 1.4 * s)
        return Path(ellipseIn: r)
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
