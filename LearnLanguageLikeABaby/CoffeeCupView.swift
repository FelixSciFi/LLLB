import SwiftUI

/// Coffee-cup playback budget indicator. Liquid level represents remaining
/// minutes for the day. Color shifts as it drains. Subscribers see a full
/// cup with an ♾️ overlay.
struct CoffeeCupView: View {
    /// 0…1 fill level (0 = empty, 1 = full).
    let progress: Double
    /// True for subscribers — cup is locked full and infinity glyph appears.
    let isPremium: Bool
    /// Total height of the cup glyph in points.
    var size: CGFloat = 22

    /// Coffee fill color tier, by remaining fraction.
    private var fillColor: Color {
        if isPremium { return Self.coffeeBrown }
        switch progress {
        case ..<0.10: return Self.warningRed
        case ..<0.25: return Self.amber
        default:      return Self.coffeeBrown
        }
    }

    /// "Empty" portion of the cup — uses background tint so the cup outline
    /// stays visible but the inside reads as drained.
    private var emptyColor: Color {
        Color.secondary.opacity(0.18)
    }

    var body: some View {
        ZStack {
            // Cup outline, filled with a vertical gradient that creates a
            // hard fill line. Top portion = empty tint; bottom portion =
            // coffee. The hard stops at (1 - progress) make the boundary crisp.
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(
                    LinearGradient(
                        stops: gradientStops(),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            if isPremium {
                Image(systemName: "infinity")
                    .font(.system(size: size * 0.42, weight: .heavy))
                    .foregroundStyle(.white)
                    .offset(y: -size * 0.04)
            }
        }
        .frame(width: size * 1.15, height: size, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPremium ? "Unlimited playback time" : "Playback time remaining")
    }

    private func gradientStops() -> [Gradient.Stop] {
        if isPremium {
            return [.init(color: fillColor, location: 0), .init(color: fillColor, location: 1)]
        }
        // Empty portion at top, fill portion at bottom, hard cutover.
        let cut = 1 - progress
        return [
            .init(color: emptyColor, location: 0),
            .init(color: emptyColor, location: cut),
            .init(color: fillColor,  location: cut),
            .init(color: fillColor,  location: 1),
        ]
    }

    // MARK: - Coffee palette (intentionally not brand color — the cup
    // should read as a real coffee cup at a glance, not a UI accent.)
    private static let coffeeBrown = Color(red: 0x7B/255.0, green: 0x4F/255.0, blue: 0x32/255.0)
    private static let amber       = Color(red: 0xD4/255.0, green: 0xA0/255.0, blue: 0x4A/255.0)
    private static let warningRed  = Color(red: 0xD9/255.0, green: 0x4A/255.0, blue: 0x35/255.0)
}

// MARK: - Refill menu

/// Compact popup anchored to the coffee cup. Adds 10 minutes via candy
/// or routes the user to the subscription paywall for unlimited time.
/// (Watch-ad button is intentionally absent until AdMob is wired in.)
struct CoffeeRefillMenu: View {
    let nativeLanguage: String
    let candyBalance: Int
    let canAffordCandy: Bool
    let onUseCandy:  () -> Void
    let onSubscribe: () -> Void
    let onClose:     () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(L("再来一杯", "Top up", nativeLanguage: nativeLanguage))
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button {
                guard canAffordCandy else { return }
                onUseCandy()
            } label: {
                refillRow(
                    title:   "+\(PlaybackBudget.refillMinutes) min",
                    detail:  "\(PlaybackBudget.refillCandyCost) 🍬",
                    enabled: canAffordCandy,
                    accent:  Color.lllbAccent
                )
            }
            .buttonStyle(.plain)
            .disabled(!canAffordCandy)

            Button(action: onSubscribe) {
                refillRow(
                    title:   L("无限时间", "Unlimited", nativeLanguage: nativeLanguage),
                    detail:  "∞",
                    enabled: true,
                    icon:    "infinity",
                    accent:  Color.lllbRingColors[3]    // gold — premium tier
                )
            }
            .buttonStyle(.plain)

            if !canAffordCandy {
                Text(L("Candy 不够 — 可以订阅解锁无限时间",
                       "Not enough candy — subscribe for unlimited time",
                       nativeLanguage: nativeLanguage))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.lllbCellStroke, lineWidth: 0.5)
        )
        .frame(width: 240)
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
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(enabled ? accent.opacity(0.08) : Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(enabled ? accent.opacity(0.25) : Color.clear, lineWidth: 0.5)
        )
    }
}
