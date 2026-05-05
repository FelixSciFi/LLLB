import SwiftUI

// MARK: - Root

struct RootView: View {
    @StateObject private var appModel = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var darwinRouter: LLLBDarwinLiveActivityRouter?
    @State private var showProfile = false
    @State private var sessionPausedByProfile = false
    @State private var showRestoreToast = false
    @State private var showPaywall = false
    @State private var showWelcomeGift = false
    @AppStorage("onboardingCompleted_v1") private var onboardingCompleted = false
    /// One-shot flag so the "🎁 7 days unlimited" card only ever appears once
    /// — at the very first run after onboarding. Persisted (not KVS-synced
    /// because cross-device replay isn't a concern: the gift itself is
    /// already KVS-protected via PromoStore).
    @AppStorage("welcome_gift_shown_v1") private var welcomeGiftShown = false

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
            if showWelcomeGift {
                WelcomeGiftCard(
                    nativeLanguage: appModel.candyStore.nativeLanguage,
                    days:           appModel.promoStore.daysRemaining ?? PromoStore.onboardingPromoDays,
                    onDismiss: {
                        Haptics.success()
                        welcomeGiftShown = true
                        withAnimation(.easeOut(duration: 0.25)) { showWelcomeGift = false }
                    }
                )
                .zIndex(900)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .onAppear {
            if iCloudSync.shared.didRestoreFromCloud && !showRestoreToast {
                withAnimation(.easeOut(duration: 0.3)) { showRestoreToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeIn(duration: 0.4)) { showRestoreToast = false }
                }
            }
            checkWelcomeGift()
        }
        .onChange(of: onboardingCompleted) { done in
            // Onboarding just completed → promo was just granted, but the
            // placement test may run next. Defer the check; it'll fire again
            // when wasPlacementShown flips below.
            if done { checkWelcomeGift() }
        }
        // Wait for the placement test to finish (or be skipped) before
        // popping the welcome card — otherwise both modals overlap on a
        // brand-new user.
        .onReceive(appModel.activeSession.$wasPlacementShown) { _ in
            checkWelcomeGift()
        }
    }

    /// Show the welcome gift card iff: onboarding finished, the placement
    /// test is settled, the promo is active (genuine new user), and we
    /// haven't shown the card yet. The placement gate prevents the card
    /// from clobbering the placement modal on a fresh install.
    private func checkWelcomeGift() {
        guard onboardingCompleted,
              !welcomeGiftShown,
              appModel.activeSession.wasPlacementShown,
              appModel.promoStore.isActive
        else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.3)) { showWelcomeGift = true }
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
            entitlementStore:    appModel.entitlementStore,
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
                showPaywall = true
            }
        )
        .sheet(isPresented: $showProfile) {
            ProfileView(
                appModel:                   appModel,
                selectedLearningLanguageID: $appModel.selectedLearningLanguageID,
                onOpenSubscribe: {
                    // Dismiss profile first so the paywall presents from the
                    // base view (cleaner than stacking a fullScreenCover on
                    // top of a sheet). 0.4s lets the sheet drop before the
                    // paywall slides up.
                    showProfile = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showPaywall = true
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(
                subscriptionManager: appModel.subscriptionManager,
                nativeLanguage:      appModel.candyStore.nativeLanguage,
                onDismiss:           { showPaywall = false }
            )
        }
        .onReceive(appModel.entitlementStore.objectWillChange) { _ in
            checkPromoExpiryPaywall()
        }
        .onChange(of: showProfile) { isShown in
            if isShown {
                if appModel.activeSession.isAutoPlaying {
                    appModel.activeSession.pause()
                    sessionPausedByProfile = true
                }
            } else if sessionPausedByProfile {
                appModel.activeSession.resume()
                sessionPausedByProfile = false
            }
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

    /// Show the paywall once when the onboarding 7-day promo has expired and
    /// the user hasn't subscribed. The flag is iCloud-synced so a reinstall
    /// after expiry doesn't re-trigger.
    private func checkPromoExpiryPaywall() {
        guard onboardingCompleted else { return }
        guard let expiry = appModel.promoStore.expiresAt, expiry <= Date() else { return }
        guard !appModel.subscriptionManager.isSubscribed else { return }
        let key = "promo_expiry_paywall_shown_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        // Tiny delay so SwiftUI doesn't try to present during a state-change
        // pass — the paywall is a fullScreenCover and likes a clean turn.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showPaywall = true
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

// MARK: - Welcome gift card

/// One-shot welcome card shown right after onboarding when the 7-day promo
/// has just been granted. Modal, non-tap-to-dismiss — the user must tap the
/// CTA so the gift "lands" before the home screen takes focus.
private struct WelcomeGiftCard: View {
    let nativeLanguage: String
    let days: Int
    let onDismiss: () -> Void

    private var gold: Color { Color.lllbRingColors[3] }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(gold.opacity(0.18))
                        .frame(width: 92, height: 92)
                    Image(systemName: "gift.fill")
                        .font(.system(size: 44, weight: .heavy))
                        .foregroundStyle(gold)
                }
                .padding(.top, 30)

                VStack(spacing: 8) {
                    Text(L("欢迎礼包", "Welcome gift", nativeLanguage: nativeLanguage))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.primary)
                    Text(L("送你 \(days) 天无限学习时间",
                           "\(days) days of unlimited learning, on us",
                           nativeLanguage: nativeLanguage))
                        .font(.system(size: 15))
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Button(action: onDismiss) {
                    Text(L("立刻开始", "Let's go", nativeLanguage: nativeLanguage))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 38)
                        .padding(.vertical, 13)
                        .background(Color.lllbAccent, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 32)
        }
    }
}
