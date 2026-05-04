import SwiftUI

// MARK: - Root

struct RootView: View {
    @StateObject private var appModel = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var darwinRouter: LLLBDarwinLiveActivityRouter?
    @State private var showProfile = false
    @State private var showRestoreToast = false
    @AppStorage("onboardingCompleted_v1") private var onboardingCompleted = false

    var body: some View {
        ZStack {
            mainContent
            if !onboardingCompleted {
                OnboardingView(appModel: appModel) {
                    // No setupActiveFlag here — that would startFresh() before
                    // ContentView.task gets to decide whether placement test runs.
                    // ContentView.task re-fires when onboardingCompleted flips
                    // (it's part of the task id) and handles activation itself.
                    withAnimation(.easeOut(duration: 0.25)) { onboardingCompleted = true }
                }
                .zIndex(500)
            }
            if showRestoreToast {
                restoreToast.zIndex(1000)
            }
        }
        .onAppear {
            if iCloudSync.shared.didRestoreFromCloud && !showRestoreToast {
                withAnimation(.easeOut(duration: 0.3)) { showRestoreToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeIn(duration: 0.4)) { showRestoreToast = false }
                }
            }
        }
    }

    private var restoreToast: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "icloud.and.arrow.down.fill")
                    .foregroundStyle(Color.lllbAccent)
                Text(L("已从 iCloud 恢复学习记录",
                       "Restored progress from iCloud",
                       nativeLanguage: appModel.candyStore.nativeLanguage))
                    .font(.subheadline)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            .padding(.top, 60)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var mainContent: some View {
        ContentView(
            session:             appModel.activeSession,
            showProfile:         $showProfile,
            candyBalance:        appModel.candyStore.candyBalance,
            usageTracker:        appModel.usageTimeTracker,
            achievementManager:  appModel.achievementManager,
            playbackBudget:      appModel.playbackBudget,
            onboardingCompleted: onboardingCompleted,
            onCollectMilestones: {
                appModel.achievementManager.collectPending(candyStore: appModel.candyStore)
            },
            onUseCandyForRefill: {
                guard appModel.playbackBudget.canRefillSingle,
                      appModel.candyStore.spendCandy(PlaybackBudget.refillCandyCost)
                else { return }
                appModel.playbackBudget.refillSingle()
                appModel.activeSession.resume()
            },
            onTopUpForRefill: { candyCost in
                guard candyCost > 0,
                      appModel.playbackBudget.canTopUp,
                      appModel.candyStore.spendCandy(candyCost)
                else { return }
                appModel.playbackBudget.topUpToFull()
                appModel.activeSession.resume()
            },
            onWatchAdForRefill: {
                // AdMob not wired yet — placeholder runs the same refill path
                // a real rewarded-ad callback would. Replace with the actual
                // ad-completion handler once SDK is integrated.
                guard appModel.playbackBudget.canRefillSingle else { return }
                appModel.playbackBudget.refillSingle()
                appModel.activeSession.resume()
            },
            onOpenSubscribe: {
                // Paywall + StoreKit not wired yet. For now, route to Profile
                // where the developer-only premium toggle lives so QA can flip
                // the cup state to ∞ end-to-end.
                showProfile = true
            }
        )
        .sheet(isPresented: $showProfile) {
            ProfileView(
                appModel:                   appModel,
                selectedLearningLanguageID: $appModel.selectedLearningLanguageID
            )
        }
        .task {
            await appModel.loadWordTables()
        }
        .onAppear {
            appModel.currentScenePhase = .active
            appModel.syncTimeTracking(playing: appModel.activeSession.isAutoPlaying)
            // Don't activate any session while onboarding is still up — otherwise
            // ContentView (mounted under the welcome overlay) starts TTS in the
            // background. The completion handler in body calls setupActiveFlag()
            // explicitly when the user finishes picking languages.
            if onboardingCompleted { setupActiveFlag() }
            if darwinRouter == nil {
                let model  = appModel
                let router = LLLBDarwinLiveActivityRouter { model.activeSession }
                router.registerDarwinObserversIfNeeded()
                darwinRouter = router
            }
        }
        // ── Lock screen widget deep link ────────────────────────────────────
        .onOpenURL { url in
            guard url.scheme == "lllb" else { return }
            if url.host == "play" {
                let s = appModel.activeSession
                if !s.isAutoPlaying { s.resume() }
            }
        }
        // ── Learning language switch ────────────────────────────────────────
        // Both gated on onboarding completion: while the user is still on the
        // welcome / language-picker screens, picking a native language must not
        // cascade-activate a session and start TTS in the background.
        .onChange(of: appModel.selectedLearningLanguageID) { _ in
            guard onboardingCompleted else { return }
            setupActiveFlag()
        }
        // ── UI language change ──────────────────────────────────────────────
        .onChange(of: appModel.candyStore.nativeLanguage) { _ in
            guard onboardingCompleted else { return }
            setupActiveFlag()
        }
        // ── Usage tracking + Live Activity on scene phase
        .onChange(of: scenePhase) { phase in
            appModel.currentScenePhase = phase
            appModel.syncTimeTracking(playing: appModel.activeSession.isAutoPlaying)
            switch phase {
            case .active:
                if #available(iOS 16.2, *) { LiveActivityManager.shared.end() }
            case .background:
                if #available(iOS 16.2, *), appModel.activeSession.isAutoPlaying {
                    LiveActivityManager.shared.start(state: appModel.activeSession.liveActivityState())
                }
            default:
                break
            }
        }
    }

    private func setupActiveFlag() {
        let activeID = appModel.selectedLearningLanguageID
        for s in appModel.availableSessions {
            s.isActive = (s.config.id == activeID)
        }
        if !appModel.availableSessions.contains(where: { $0.isActive }),
           let first = appModel.availableSessions.first {
            first.isActive = true
        }
    }
}

#Preview {
    RootView()
}
