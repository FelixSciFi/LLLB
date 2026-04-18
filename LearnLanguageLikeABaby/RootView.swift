import SwiftUI

// MARK: - Root

struct RootView: View {
    @StateObject private var appModel = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var darwinRouter: LLLBDarwinLiveActivityRouter?
    @State private var showProfile = false

    var body: some View {
        ContentView(
            session:      appModel.activeSession,
            showProfile:  $showProfile,
            streakDays:   appModel.usageTimeTracker.streakDays,
            candyBalance: appModel.candyStore.candyBalance
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
            setupActiveFlag()
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
        .onChange(of: appModel.selectedLearningLanguageID) { _ in
            setupActiveFlag()
        }
        // ── UI language change ──────────────────────────────────────────────
        .onChange(of: appModel.candyStore.nativeLanguage) { _ in
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
