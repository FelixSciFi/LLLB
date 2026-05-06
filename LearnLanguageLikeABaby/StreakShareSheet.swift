import SwiftUI
import UIKit

/// Pops when ShareTriggerStore.pending fires (e.g. streakDays hits a milestone).
/// Shows a preview of the share card; tapping "Share" renders to PNG and
/// presents the system share sheet. A successful share grants 2 🍬 (subject
/// to daily/monthly caps in ShareTriggerStore).
struct StreakShareSheet: View {
    /// nil = manual share entry point (Profile / streak hub). Non-nil =
    /// auto-prompted by a milestone fire; we mark the trigger seen on
    /// completion or dismiss so we don't re-prompt for the same number.
    let trigger:           ShareTrigger?
    @ObservedObject var triggerStore: ShareTriggerStore
    var candyStore:        CandyStore
    let streakDays:        Int
    let learningLanguage:  LanguageConfig
    let totalHours:        Int
    let nativeLanguage:    String

    @Environment(\.dismiss) private var dismiss
    @State private var presentingSystemShare = false
    @State private var renderedImage: UIImage? = nil
    @State private var rewardJustGranted: Int? = nil

    private var displayStreakDays: Int {
        if case .streakMilestone(let n) = trigger { return n }
        return streakDays
    }

    private var isMilestoneCelebration: Bool {
        if case .streakMilestone = trigger { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 20) {
            handle
            heading
            cardPreview
            if let granted = rewardJustGranted {
                rewardBanner(granted: granted)
            }
            actionButtons
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $presentingSystemShare) {
            if let img = renderedImage {
                SystemShareSheet(items: [img]) { completed in
                    if completed { handleShareCompleted() }
                    presentingSystemShare = false
                }
            }
        }
    }

    private var handle: some View {
        Capsule().fill(Color.lllbSeparator)
            .frame(width: 36, height: 5)
    }

    private var heading: some View {
        VStack(spacing: 6) {
            Text(headingTitle)
                .font(.title2.weight(.heavy))
                .multilineTextAlignment(.center)
            Text(L("分享给朋友,完成分享可得 \(ShareTriggerStore.rewardPerShare) 🍬",
                   "Share with friends — earn \(ShareTriggerStore.rewardPerShare) 🍬 on a successful share"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var headingTitle: String {
        if isMilestoneCelebration {
            return L("🎉 \(displayStreakDays) 天连胜达成!",
                     "🎉 \(displayStreakDays)-Day Streak!")
        }
        return L("分享我的 \(displayStreakDays) 天连胜",
                 "Share my \(displayStreakDays)-day streak")
    }

    private var cardPreview: some View {
        StreakShareCard(
            streakDays:           displayStreakDays,
            learningLanguageFlag: learningLanguage.flag,
            learningLanguageName: learningLanguage.displayName(for: nativeLanguage),
            totalHours:           totalHours,
            nativeLanguage:       nativeLanguage
        )
        .scaleEffect(0.28)
        .frame(width: 1080 * 0.28, height: 1080 * 0.28)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }

    private func rewardBanner(granted: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text(L("已奖励 \(granted) 🍬", "Earned \(granted) 🍬"))
                .font(.subheadline.weight(.semibold))
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button {
                Haptics.light()
                renderAndShare()
            } label: {
                Label(L("分享", "Share"), systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.lllbAccent, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            Button(L("以后再说", "Maybe later")) {
                if let trigger { triggerStore.dismiss(trigger) }
                dismiss()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func renderAndShare() {
        let img = StreakShareCard.renderImage(
            streakDays:           displayStreakDays,
            learningLanguageFlag: learningLanguage.flag,
            learningLanguageName: learningLanguage.displayName(for: nativeLanguage),
            totalHours:           totalHours,
            nativeLanguage:       nativeLanguage
        )
        guard let img else { return }
        renderedImage = img
        presentingSystemShare = true
    }

    private func handleShareCompleted() {
        let granted = triggerStore.grantRewardForSuccessfulShare()
        if granted > 0 {
            candyStore.addCandy(granted)
            withAnimation { rewardJustGranted = granted }
            Haptics.medium()
        }
        // Manual entry has no milestone to mark seen.
        if let trigger { triggerStore.dismiss(trigger) }
        // Brief pause so the user sees the reward banner, then auto-close.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            dismiss()
        }
    }

    // MARK: - i18n

    private func L(_ zh: String, _ en: String) -> String {
        nativeLanguage == "en" ? en : zh
    }
}

// MARK: - System share sheet wrapper

/// UIActivityViewController bridge. We need this (rather than SwiftUI's
/// ShareLink) because the reward flow depends on the `completed` flag from
/// `completionWithItemsHandler` — ShareLink doesn't expose it.
private struct SystemShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, completed, _, _ in
            onComplete(completed)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
