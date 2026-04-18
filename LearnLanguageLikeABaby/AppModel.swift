import Foundation
import Combine
import SwiftUI
import AVFoundation
import MediaPlayer

/// Single source of truth for the app.
/// RootView holds one @StateObject of this; all views get what they need from here.
/// Adding a new language = one entry in LanguageConfig.learningLanguages + JSON files.
@MainActor
final class AppModel: ObservableObject {

    // MARK: - Owned objects

    let candyStore:        CandyStore
    let sessions:          [LessonSessionModel]   // all learning languages, fixed order
    let usageTimeTracker = UsageTimeTracker()

    // MARK: - Published state

    /// Bottom tab: "learn" or "profile".
    @Published var selectedTabID: String = "learn"

    /// Currently selected learning language (language code, e.g. "fr").
    @Published var selectedLearningLanguageID: String = ""

    /// Inter-sentence pause in seconds (1–5), shared across all languages.
    @Published var interSentencePause: Int {
        didSet {
            UserDefaults.standard.set(interSentencePause, forKey: "interSentencePause")
            for s in sessions { s.narration.interSentenceDelay = Double(interSentencePause) }
        }
    }

    /// Non-nil while the sleep timer is running; holds the scheduled fire date.
    @Published var sleepTimerFireDate: Date? = nil

    /// Word tables keyed by language code; loaded asynchronously on first appear.
    @Published var wordTables: [String: [WordEntry]] = [:]

    // MARK: - Computed

    /// Sessions eligible for learning (excludes current UI language).
    var availableSessions: [LessonSessionModel] {
        sessions.filter { $0.config.id != candyStore.nativeLanguage }
    }

    var activeSession: LessonSessionModel {
        availableSessions.first { $0.config.id == selectedLearningLanguageID }
            ?? availableSessions.first
            ?? sessions[0]
    }

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()
    private var sleepTimerTask: DispatchWorkItem?
    private var sleepTimerDisplayTick: AnyCancellable?

    /// Updated by RootView on every scenePhase change so Combine sinks can consult it.
    var currentScenePhase: ScenePhase = .inactive

    // MARK: - Init

    init() {
        // 0. Configure shared AVAudioSession once for the whole app lifetime
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)

        // 1. Bootstrap: load top-100 lemmas per language for first-run seeding
        var initialLemmas: [String: [String]] = [:]
        for lang in LanguageConfig.learningLanguages {
            if let table = try? SentenceLibrary.loadWordTable(language: lang.id) {
                initialLemmas[lang.id] = table
                    .filter { (1...100).contains($0.rank) }
                    .map(\.lemma)
            }
        }

        let store = CandyStore(initialLemmasByLanguage: initialLemmas)
        self.candyStore = store

        // 2. Create one session per learning language
        let allSessions = LanguageConfig.learningLanguages.map { config -> LessonSessionModel in
            let s = LessonSessionModel(config: config)
            s.candyStore    = store
            s.nativeLanguage = store.nativeLanguage
            return s
        }
        self.sessions = allSessions

        // 3. Global playback settings
        let savedPause = UserDefaults.standard.object(forKey: "interSentencePause") as? Int ?? 4
        _interSentencePause = Published(initialValue: savedPause)
        for s in allSessions { s.narration.interSentenceDelay = Double(savedPause) }

        // 4. Restore or default learning language
        let savedID = UserDefaults.standard.string(forKey: "selectedLearningLanguage") ?? ""
        let available = allSessions.filter { $0.config.id != store.nativeLanguage }
        let restored = available.first { $0.config.id == savedID } ?? available.first
        let defaultID = restored?.config.id ?? ""
        _selectedLearningLanguageID = Published(initialValue: defaultID)

        // 5. Load all libraries first (isActive still false — no autoplay triggered)
        for s in allSessions { s.loadLibrary() }
        // Then set isActive: didSet fires startFresh() for the active session only
        for s in allSessions { s.isActive = (s.config.id == defaultID) }

        // 5. Forward candyStore + usageTracker changes so views re-render
        store.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        usageTimeTracker.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // 6. When UI language changes: sync all sessions + fix selected learning language
        store.$nativeLanguage
            .dropFirst()
            .sink { [weak self] newLang in
                guard let self else { return }
                for s in self.sessions { s.nativeLanguage = newLang }
                let avail = self.availableSessions
                if !avail.contains(where: { $0.config.id == self.selectedLearningLanguageID }) {
                    self.selectedLearningLanguageID = avail.first?.config.id ?? ""
                }
            }
            .store(in: &cancellables)

        // 7. Persist selectedLearningLanguageID on every change
        self.$selectedLearningLanguageID
            .dropFirst()
            .sink { id in
                UserDefaults.standard.set(id, forKey: "selectedLearningLanguage")
            }
            .store(in: &cancellables)

        // 8. Live Activity updates — fire directly from Combine, not from SwiftUI onChange
        //    $liveActivityRevision handles sentence changes and play/pause state.
        //    $highlightedTokenIndex (debounced) drives emoji updates during playback.
        for session in allSessions {
            session.$liveActivityRevision
                .dropFirst()
                .sink { [weak self] _ in
                    guard let self,
                          self.activeSession.config.id == session.config.id else { return }
                    if #available(iOS 16.2, *) {
                        let active = self.activeSession
                        if active.isAutoPlaying {
                            LiveActivityManager.shared.start(state: active.liveActivityState())
                        } else {
                            LiveActivityManager.shared.end()
                        }
                    }
                }
                .store(in: &cancellables)

            if #available(iOS 16.2, *) {
                session.narration.$highlightedTokenIndex
                    .dropFirst()
                    .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)
                    .sink { [weak self] _ in
                        guard let self,
                              self.activeSession.config.id == session.config.id,
                              self.activeSession.isAutoPlaying else { return }
                        LiveActivityManager.shared.update(state: self.activeSession.liveActivityState())
                    }
                    .store(in: &cancellables)
            }
        }

        // 9. isAutoPlaying changes → update time tracking
        for session in allSessions {
            session.$isAutoPlaying
                .dropFirst()
                .sink { [weak self] playing in
                    guard let self,
                          self.activeSession.config.id == session.config.id else { return }
                    self.syncTimeTracking(playing: playing)
                }
                .store(in: &cancellables)
        }

        // 10. Media remote commands (earphone prev/next/play/pause)
        setupRemoteCommands()

        // 10. Lock-screen Now Playing info
        setupNowPlayingUpdates()

        // 11. Forward session trash changes so ProfileView (observing AppModel) re-renders
        for session in allSessions {
            session.$trashedIDs
                .dropFirst()
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
    }

    // MARK: - Remote commands

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.activeSession.goPreviousSentence() }
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.activeSession.goNextSentence() }
            return .success
        }

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.activeSession.resume() }
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.activeSession.pause() }
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let s = self?.activeSession else { return }
                if s.isAutoPlaying { s.pause() } else { s.resume() }
            }
            return .success
        }

        center.likeCommand.isEnabled = true
        center.likeCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let session = self.activeSession
                session.toggleFavorite(for: session.currentSentence.id)
                center.likeCommand.isActive = session.favoritedIDs.contains(session.currentSentence.id)
            }
            return .success
        }
    }

    // MARK: - Now Playing info

    private func setupNowPlayingUpdates() {
        for session in sessions {
            session.$liveActivityRevision
                .dropFirst()
                .sink { [weak self] _ in
                    guard let self,
                          self.activeSession.config.id == session.config.id else { return }
                    self.updateNowPlayingInfo()
                }
                .store(in: &cancellables)
        }

        self.$selectedLearningLanguageID
            .dropFirst()
            .sink { [weak self] _ in self?.updateNowPlayingInfo() }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                guard let self, !self.activeSession.isAutoPlaying else { return }
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            }
            .store(in: &cancellables)
    }

    private func updateNowPlayingInfo() {
        let session     = activeSession
        let sentence    = session.currentSentence
        let translation = sentence.translation
            .resolvedTranslation(nativeLanguage: session.nativeLanguage)

        var info: [String: Any] = [
            MPMediaItemPropertyTitle:                    sentence.text,
            MPMediaItemPropertyArtist:                   translation,
            MPMediaItemPropertyAlbumTitle:               "LLLB",
            MPNowPlayingInfoPropertyPlaybackRate:         session.isAutoPlaying ? 1.0 : 0.0,
        ]

        if let icon = appIconImage() {
            info[MPMediaItemPropertyArtwork] =
                MPMediaItemArtwork(boundsSize: icon.size) { _ in icon }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Keep the lock-screen like button in sync with the current sentence's favourite state
        MPRemoteCommandCenter.shared().likeCommand.isActive =
            session.favoritedIDs.contains(sentence.id)
    }

    private func appIconImage() -> UIImage? {
        guard
            let icons   = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files   = primary["CFBundleIconFiles"] as? [String],
            let name    = files.last
        else { return UIImage(named: "AppIcon") }
        return UIImage(named: name) ?? UIImage(named: "AppIcon")
    }

    // MARK: - Time tracking sync

    /// Single source of truth for starting/stopping usage timers.
    /// Call whenever isAutoPlaying or scenePhase changes.
    func syncTimeTracking(playing: Bool) {
        let t = usageTimeTracker
        if playing {
            switch currentScenePhase {
            case .active:
                t.endBgSession()
                t.beginSession()
            case .background:
                t.endSession()
                t.beginBgSession()
            default:
                t.endSession()
                t.endBgSession()
            }
        } else {
            t.endSession()
            t.endBgSession()
        }
    }

    // MARK: - Sleep timer

    /// Remaining whole seconds, or nil when the timer is off.
    var sleepTimerRemainingSeconds: Int? {
        guard let date = sleepTimerFireDate else { return nil }
        let secs = date.timeIntervalSinceNow
        guard secs > 0 else { return nil }
        return max(1, Int(ceil(secs)))
    }

    func setSleepTimer(minutes: Int) {
        cancelSleepTimer()
        guard minutes > 0 else { return }

        let fireDate = Date().addingTimeInterval(Double(minutes) * 60)
        sleepTimerFireDate = fireDate

        let task = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.activeSession.pause()
                self.sleepTimerFireDate = nil
            }
        }
        sleepTimerTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(minutes) * 60, execute: task)

        // Refresh displayed countdown every second
        sleepTimerDisplayTick = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }

    func cancelSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimerDisplayTick?.cancel()
        sleepTimerDisplayTick = nil
        sleepTimerFireDate = nil
    }

    // MARK: - Word table loading (called once from RootView.task)

    func loadWordTables() async {
        var result: [String: [WordEntry]] = [:]
        for lang in LanguageConfig.learningLanguages {
            if let table = try? SentenceLibrary.loadWordTable(language: lang.id) {
                result[lang.id] = table
            }
        }
        wordTables = result
    }
}
