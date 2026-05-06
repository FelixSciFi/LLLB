import SwiftUI
import UIKit

/// Square 1080×1080 share card showing the user's streak achievement.
/// Rendered offscreen via ImageRenderer to a UIImage for sharing on social
/// platforms (Instagram / Twitter / WeChat etc.).
///
/// Multilingual: copy switches between zh and en via `Localizer.L(_:_:_:)`.
/// `totalHours` is currently summed across ALL learning languages — per-
/// language hour bucketing requires a `UsageTimeTracker` refactor (see
/// project_backlog).
struct StreakShareCard: View {

    let streakDays:           Int
    let learningLanguageFlag: String
    let learningLanguageName: String
    let totalHours:           Int
    let nativeLanguage:       String   // "zh" or "en", controls copy

    var body: some View {
        ZStack {
            backgroundLayer
            VStack(spacing: 0) {
                logoBadge
                Spacer().frame(height: 60)
                streakHero
                Spacer().frame(height: 80)
                statsBlock
                Spacer()
                footer
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 90)
        }
        .frame(width: 1080, height: 1080)
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.20, blue: 0.45),
                    Color(red: 0.06, green: 0.13, blue: 0.32)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            // Soft warm glow behind the flame
            RadialGradient(
                colors: [
                    Color.orange.opacity(0.18),
                    Color.clear
                ],
                center: .center, startRadius: 0, endRadius: 600
            )
        }
    }

    // MARK: - Logo

    private var logoBadge: some View {
        HStack(spacing: 22) {
            LLLBLogoCoded(variant: .premium, size: 96)
            VStack(alignment: .leading, spacing: 4) {
                Text("LLLB")
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundStyle(Color.lllbBrandGold)
                Text("Learn Language Like a Baby")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color.lllbBrandCream.opacity(0.75))
            }
            Spacer()
        }
    }

    // MARK: - Hero (flame + number)

    private var streakHero: some View {
        VStack(spacing: 10) {
            ZStack {
                // Glow halo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.orange.opacity(0.45), Color.clear],
                            center: .center, startRadius: 20, endRadius: 280
                        )
                    )
                    .frame(width: 600, height: 600)
                Image(systemName: "flame.fill")
                    .font(.system(size: 230, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 1.00, green: 0.78, blue: 0.30),
                                Color(red: 0.96, green: 0.36, blue: 0.10)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
            .frame(height: 280)

            Text("\(streakDays)")
                .font(.system(size: 240, weight: .black))
                .foregroundStyle(Color.lllbBrandCream)
                .shadow(color: Color.black.opacity(0.25), radius: 8, y: 4)

            Text(L("天连续学习", "DAY STREAK"))
                .font(.system(size: 38, weight: .heavy))
                .tracking(nativeLanguage == "en" ? 8 : 4)
                .foregroundStyle(Color.lllbBrandGold)
        }
    }

    // MARK: - Stats panel

    private var statsBlock: some View {
        VStack(spacing: 24) {
            statsRow(
                emoji: learningLanguageFlag,
                text:  L("正在学 · \(learningLanguageName)",
                         "Learning · \(learningLanguageName)")
            )
            statsRow(
                emoji: "⏱",
                text:  L("已经听了 \(totalHours) 小时",
                         "\(totalHours) hours listened")
            )
        }
        .padding(.horizontal, 56)
        .padding(.vertical, 38)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 36)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 36)
                        .stroke(Color.lllbBrandCream.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private func statsRow(emoji: String, text: String) -> some View {
        HStack(spacing: 18) {
            Text(emoji).font(.system(size: 42))
            Text(text)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color.lllbBrandCream)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Text("LLLB.app")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.lllbBrandCream.opacity(0.45))
            Spacer()
        }
    }

    // MARK: - i18n helper (delegates to global `L()` from Localizer.swift)

    private func L(_ zh: String, _ en: String) -> String {
        nativeLanguage == "en" ? en : zh
    }
}

// MARK: - Render to UIImage

extension StreakShareCard {

    /// Render the card into a UIImage. Must be called on the main actor —
    /// ImageRenderer requires it.
    @MainActor
    static func renderImage(streakDays: Int,
                            learningLanguageFlag: String,
                            learningLanguageName: String,
                            totalHours: Int,
                            nativeLanguage: String) -> UIImage? {
        let card = StreakShareCard(
            streakDays:           streakDays,
            learningLanguageFlag: learningLanguageFlag,
            learningLanguageName: learningLanguageName,
            totalHours:           totalHours,
            nativeLanguage:       nativeLanguage
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2   // 2160×2160 final pixel size — sharp on retina
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1080)
        return renderer.uiImage
    }
}

// MARK: - Preview

#Preview("ZH · 50 days") {
    StreakShareCard(
        streakDays: 50,
        learningLanguageFlag: "🇫🇷",
        learningLanguageName: "法语",
        totalHours: 87,
        nativeLanguage: "zh"
    )
    .scaleEffect(0.3)
}

#Preview("EN · 100 days") {
    StreakShareCard(
        streakDays: 100,
        learningLanguageFlag: "🇫🇷",
        learningLanguageName: "French",
        totalHours: 156,
        nativeLanguage: "en"
    )
    .scaleEffect(0.3)
}
