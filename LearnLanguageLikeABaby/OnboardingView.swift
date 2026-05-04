import SwiftUI

/// First-launch onboarding: pick native language, then learning language.
/// Shown as a full-screen overlay above ContentView. Marks itself complete
/// via `onboardingCompleted_v1` UserDefaults key when the second step is picked.
struct OnboardingView: View {
    @ObservedObject var appModel: AppModel
    var onComplete: () -> Void

    private enum Step { case native, learning }
    @State private var step: Step = .native

    var body: some View {
        ZStack {
            Color.lllbBackground.ignoresSafeArea()

            switch step {
            case .native:   nativeStep
            case .learning: learningStep
            }
        }
        .transition(.opacity)
    }

    // MARK: - Step 1: native language
    //
    // No localization helper here — user hasn't picked a native language yet,
    // so we present both scripts side-by-side.

    private var nativeStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 32)

            // Brand block
            VStack(spacing: 18) {
                LLLBLogoCoded(variant: .free, size: 120)

                VStack(spacing: 4) {
                    Text("LLLB")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(Color.primary)
                    Text("Learn Language Like a Baby")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.lllbSecondaryText)
                }
            }

            Spacer(minLength: 36)

            VStack(spacing: 6) {
                Text("选择母语")
                    .font(.system(size: 22, weight: .semibold))
                Text("Choose your native language")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.lllbSecondaryText)
            }
            .padding(.bottom, 18)

            VStack(spacing: 12) {
                ForEach(LanguageConfig.uiLanguages) { lang in
                    Button {
                        Haptics.medium()
                        appModel.candyStore.nativeLanguage = lang.id
                        withAnimation(.easeInOut(duration: 0.25)) { step = .learning }
                    } label: {
                        languageCard(title: lang.displayNames[lang.id] ?? lang.id.uppercased())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 32)
        }
    }

    // MARK: - Step 2: learning language

    private var learningStep: some View {
        let nl       = appModel.candyStore.nativeLanguage
        let choices  = LanguageConfig.releasedLearningLanguages.filter { $0.id != nl }
        return VStack(spacing: 24) {
            Spacer().frame(height: 24)

            VStack(spacing: 8) {
                Text(L("想学什么语言？", "What do you want to learn?", nativeLanguage: nl))
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(L("之后可以在「我的」里随时切换",
                       "You can switch anytime from Profile",
                       nativeLanguage: nl))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.lllbSecondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(choices) { lang in
                        Button {
                            Haptics.success()
                            appModel.selectedLearningLanguageID = lang.id
                            UserDefaults.standard.set(true, forKey: "onboardingCompleted_v1")
                            onComplete()
                        } label: {
                            languageCard(title: lang.displayName(for: nl))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Shared card

    @ViewBuilder
    private func languageCard(title: String) -> some View {
        Text(title)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(Color.lllbChipBg, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.lllbChipStroke, lineWidth: 0.5)
            )
    }
}
