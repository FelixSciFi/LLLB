import Foundation
import CoreFoundation
import AVFoundation
import Combine
import SwiftUI

struct LibraryOption: Identifiable, Hashable {
    let id: String
    let name: String
}

enum TranslationPlaybackMode: String {
    case off    = "off"
    case before = "before"
    case after  = "after"
}

enum ArchiveKind {
    case mastered   // 学会了
    case later      // 稍后学
}

enum PlayMode: String {
    case shuffle    = "shuffle"
    case sequential = "sequential"
    case singleLoop = "singleLoop"
    case favorites  = "favorites"
}

@MainActor
final class LessonSessionModel: ObservableObject, Identifiable {
    let narration        = NarrationEngine()
    let chineseNarration = NarrationEngine()

    // MARK: - Configuration

    let config: LanguageConfig
    var id: String { config.id }

    var isActive: Bool = false {
        didSet {
            guard oldValue != isActive else { return }
            if isActive {
                if currentMainSentence == nil {
                    startFresh()
                } else if !isAutoPlaying {
                    resume()
                }
                // already autoPlaying: do nothing
            } else {
                if isAutoPlaying { pause() }
            }
        }
    }

    // MARK: - CandyStore wiring

    var candyStore: CandyStore? {
        didSet {
            candyObservation?.cancel()
            candyObservation = nil
            guard let store = candyStore else { return }
            candyObservation = store.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        }
    }
    private var candyObservation: AnyCancellable?

    // MARK: - Library

    /// Derived from whatever CEFR values exist in the loaded sentences.
    /// Adding new levels to the JSON automatically makes them appear here.
    var availableLibraries: [LibraryOption] {
        let present = mainSentences.map(\.cefr)
        return LevelSystem.sorted(present, using: config.levelOrder)
            .map { LibraryOption(id: $0, name: $0) }
    }

    @Published var mainSentences:   [LessonSentence] = [] {
        didSet { recomputeMyAssetsCache() }
    }
    @Published var wordTable:       [WordEntry]       = []
    @Published var selectedLibraries: Set<String> {
        didSet { recomputeMyAssetsCache() }
    }

    /// Cached results for `MyAssetsView` (Profile → 我的词句).
    /// Recomputed only when one of the dependencies (mainSentences, pool,
    /// masteredIDs, laterIDs, selectedLibraries) actually changes — not on
    /// every body render. Call sites in core playback still use the
    /// `filteredSentences()` function form, since they're outside the hot
    /// SwiftUI body path.
    @Published private(set) var filteredPool:   [LessonSentence] = []
    @Published private(set) var masteredList:   [LessonSentence] = []
    @Published private(set) var laterList:      [LessonSentence] = []

    private func recomputeMyAssetsCache() {
        let poolSet = Set(pool)
        var filtered: [LessonSentence] = []
        var mastered: [LessonSentence] = []
        var later:    [LessonSentence] = []
        for s in mainSentences {
            let isMastered = masteredIDs.contains(s.id)
            let isLater    = laterIDs.contains(s.id)
            if isMastered { mastered.append(s) }
            if isLater    { later.append(s) }
            if poolSet.contains(s.id)
                && selectedLibraries.contains(s.cefr)
                && !isMastered && !isLater {
                filtered.append(s)
            }
        }
        filteredPool = filtered
        masteredList = mastered
        laterList    = later
    }

    /// Current sentence on the main track (not example / favorite playlist).
    @Published var currentMainSentence: LessonSentence? = nil {
        didSet { bumpLiveActivity() }
    }

    /// Monotonically incremented whenever Live Activity state is worth refreshing.
    /// Observed by AppModel — this class knows nothing about LiveActivityManager.
    @Published private(set) var liveActivityRevision: Int = 0

    @Published var examplePlaylist: [LessonSentence]?
    @Published var exampleIndex:    Int = 0

    @Published var playMode: PlayMode {
        didSet { UserDefaults.standard.set(playMode.rawValue, forKey: "playMode_\(config.id)") }
    }

    @Published var speedMultiplier: Double {
        didSet { UserDefaults.standard.set(speedMultiplier, forKey: "speed_\(config.id)") }
    }

    @Published var repeatsBeforeAdvance: Int {
        didSet { UserDefaults.standard.set(repeatsBeforeAdvance, forKey: "repeats_\(config.id)") }
    }

    /// User-configurable upper bound on pool size; archive deficit-unlock refills toward this.
    @Published var poolCapacity: Int {
        didSet { UserDefaults.standard.set(poolCapacity, forKey: "poolCapacity_\(config.id)") }
    }


    @Published var showImage: Bool {
        didSet { UserDefaults.standard.set(showImage,       forKey: "showImage_\(config.id)") }
    }
    @Published var showSpelling: Bool {
        didSet { UserDefaults.standard.set(showSpelling,    forKey: "showSpelling_\(config.id)") }
    }
    @Published var showIPA: Bool {
        didSet { UserDefaults.standard.set(showIPA,         forKey: "showIPA_\(config.id)") }
    }
    @Published var showTranslation: Bool {
        didSet { UserDefaults.standard.set(showTranslation, forKey: "showTranslation_\(config.id)") }
    }
    @Published var translationPlaybackMode: TranslationPlaybackMode {
        didSet { UserDefaults.standard.set(translationPlaybackMode.rawValue, forKey: "translationPlayback_\(config.id)") }
    }
    @Published var spellMode: Bool {
        didSet {
            UserDefaults.standard.set(spellMode, forKey: "spellMode_\(config.id)")
            narration.spellEnabled = spellMode
        }
    }

    /// Stroke-writer toggle (zh learning mode only). Persisted globally per
    /// learning language; the rendering decision still gates per-sentence
    /// via StrokeWriterFeature.canRender.
    @Published var writeMode: Bool {
        didSet { UserDefaults.standard.set(writeMode, forKey: "writeMode_\(config.id)") }
    }

    /// Lifetime play count per sentence ID (persisted).
    @Published var lifetimePlayCounts: [String: Int] = [:]

    /// Play count for the currently displayed sentence — snapshotted when the sentence
    /// first arrives, then incremented smoothly each time an utterance finishes.
    /// Never jumps when a new sentence loads (snapshot happens before playback starts).
    @Published var currentSentencePlayCount: Int = 0

    /// Sentence IDs sold from archive — back in the store but excluded from lesson loop until re-purchased.
    @Published var soldIDs: Set<String> = []

    /// Synced from CandyStore via AppModel. Drives translation readback language.
    @Published var nativeLanguage: String = "zh" {
        didSet {
            let locale = LanguageConfig.uiLanguages.first { $0.id == nativeLanguage }?.ttsLocale ?? "zh-CN"
            chineseNarration.language = locale
        }
    }

    @Published var isAutoPlaying: Bool = false {
        didSet {
            guard isAutoPlaying != oldValue else { return }
            isAutoPlaying ? startSilencePlayer() : stopSilencePlayer()
        }
    }

    @Published var focusedLemma:    String? = nil
    @Published var focusedTokenText: String = ""

    /// Ordered list of favorited sentence IDs. Append on favorite, remove preserving
    /// order on un-favorite. Persisted as `[String]`. Order is "by favorite time"
    /// (oldest first) and drives playback order in `.favorites` play mode.
    @Published var favoritedIDs: [String] = []
    var isFavoriteMode: Bool { playMode == .favorites }
    @Published var activatedTag: String? = nil
    private var isRandomTagMode: Bool = false

    @Published var masteredIDs:          Set<String> = [] {
        didSet { recomputeMyAssetsCache() }
    }
    @Published var laterIDs:             Set<String> = [] {
        didSet { recomputeMyAssetsCache() }
    }
    var archivedIDs: Set<String> { masteredIDs.union(laterIDs) }
    @Published var familiarIDs:         Set<String> = []

    /// Sentence IDs in the user's active pool, ordered by entry time (oldest first).
    /// Acts like a music playlist: archive removes, restore appends, deficit-unlock appends.
    @Published var pool: [String] = [] {
        didSet { recomputeMyAssetsCache() }
    }

    /// Candidate groups offered to the user after archive: each inner `[String]`
    /// is one selectable card (single sentence = 1 ID; tag group = N IDs that
    /// all enter the pool together if the user picks that card).
    /// Persisted so a half-completed selection survives app kill.
    @Published var pendingCandidateGroups: [[String]] = []

    /// How many more cards the user still needs to tap before this batch closes.
    /// Decrements with every tap; hits 0 (or candidates run out) → batch clears.
    @Published var pendingPicksRemaining: Int = 0

    /// Pool sentences as full objects, preserving entry order. Convenience for UI.
    var poolSentences: [LessonSentence] {
        let byID = Dictionary(uniqueKeysWithValues: mainSentences.map { ($0.id, $0) })
        return pool.compactMap { byID[$0] }
    }

    @Published var loadError: String?

    // MARK: - Private state

    private var playsOnCurrent:    Int    = 0
    private var mainPlaylist:     [String] = []   // sentence IDs; index-1=history, index=current, index+1=future
    private var mainPlaylistIndex: Int    = -1
    private var wasAutoPlaying:    Bool   = false   // saved across audio interruptions
    private var cancellables = Set<AnyCancellable>()

    /// Sequential-mode "resume hint" — the pool ID we should jump to next time
    /// pickNextMainSentence falls through, regardless of what's currently playing.
    /// Set when state changes that would otherwise reset position to pool[0]
    /// (archiving current, splicing in user-picked sentences). Consumed on use.
    private var sequentialResumeID: String? = nil

    /// Algorithm for picking which sentence to unlock when the pool refills.
    /// Swap with a different `PoolUnlockSelector` to experiment with strategies.
    private var unlockSelector: PoolUnlockSelector = ProportionalUnlockSelector.default

    // MARK: - Storage keys

    private var familiarStorageKey:         String { "familiarIDs_\(config.id)" }
    private var masteredStorageKey:          String { "masteredIDs_\(config.id)" }
    private var laterStorageKey:             String { "laterIDs_\(config.id)" }
    private var soldStorageKey:             String { "soldIDs_\(config.id)" }
    private var favoritesStorageKey:        String { "favoritedIDs_\(config.id)" }
    private var librarySelectionStorageKey: String { "selectedLibraries_\(config.id)" }
    /// Stores which CEFR levels were known last time; new levels detected by diffing against this.
    private var knownLibrariesStorageKey:   String { "knownLibraries_\(config.id)" }
    private var playCountsStorageKey: String { "lifetimePlayCounts_\(config.id)" }
    private var poolStorageKey:             String { "pool_\(config.id)" }
    private var placementShownKey:          String { "placementShown_\(config.id)" }
    /// Legacy key — superseded by `placementShownKey`. Read once at init for migration only.
    private var legacyPoolInitializedKey:   String { "poolInitialized_\(config.id)" }
    private var pendingCandidatesKey:       String { "pendingCandidates_\(config.id)" }
    private var pendingRemainingKey:        String { "pendingRemaining_\(config.id)" }

    // MARK: - Init helpers

    private static func loadDouble(d: UserDefaults, key: String, default def: Double) -> Double {
        guard d.object(forKey: key) != nil else { return def }
        return d.double(forKey: key)
    }
    private static func loadInt(d: UserDefaults, key: String, default def: Int) -> Int {
        guard d.object(forKey: key) != nil else { return def }
        return d.integer(forKey: key)
    }
    private static func loadBool(d: UserDefaults, key: String, default def: Bool) -> Bool {
        guard d.object(forKey: key) != nil else { return def }
        return d.bool(forKey: key)
    }

    // MARK: - Init

    init(config: LanguageConfig) {
        self.config = config
        let d   = UserDefaults.standard
        let lid = config.id
        _wasPlacementShown      = Published(initialValue: d.bool(forKey: "placementShown_\(lid)"))
        _selectedLibraries      = Published(initialValue: Set(["A1", "A2"]))
        _speedMultiplier        = Published(initialValue: Self.loadDouble(d: d, key: "speed_\(lid)", default: 1.0))
        _repeatsBeforeAdvance   = Published(initialValue: Self.loadInt(d: d, key: "repeats_\(lid)", default: 3))
        _poolCapacity           = Published(initialValue: Self.loadInt(d: d, key: "poolCapacity_\(lid)", default: 100))
        let rawPlayMode = d.string(forKey: "playMode_\(lid)") ?? "shuffle"
        _playMode               = Published(initialValue: PlayMode(rawValue: rawPlayMode) ?? .shuffle)
        _showImage              = Published(initialValue: Self.loadBool(d: d, key: "showImage_\(lid)", default: true))
        _showSpelling           = Published(initialValue: Self.loadBool(d: d, key: "showSpelling_\(lid)", default: true))
        _showIPA                = Published(initialValue: Self.loadBool(d: d, key: "showIPA_\(lid)", default: true))
        _showTranslation        = Published(initialValue: Self.loadBool(d: d, key: "showTranslation_\(lid)", default: true))
        _spellMode              = Published(initialValue: Self.loadBool(d: d, key: "spellMode_\(lid)", default: true))
        _writeMode              = Published(initialValue: Self.loadBool(d: d, key: "writeMode_\(lid)", default: true))
        let rawMode = d.string(forKey: "translationPlayback_\(lid)")
            ?? (d.bool(forKey: "chineseReading_\(lid)") ? "after" : "after")
        _translationPlaybackMode = Published(initialValue: TranslationPlaybackMode(rawValue: rawMode) ?? .after)

        narration.onUtteranceFinished = { [weak self] in
            Task { @MainActor in self?.handleUtteranceFinished() }
        }
        narration.onInterrupted = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.wasAutoPlaying = self.isAutoPlaying
                self.isAutoPlaying = false
                self.chineseNarration.stop()
                self.bumpLiveActivity()
            }
        }
        narration.onInterruptionEnded = { [weak self] in
            Task { @MainActor in
                guard let self, self.wasAutoPlaying else { return }
                self.wasAutoPlaying = false
                self.resume()
            }
        }
        narration.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        narration.spellEnabled = spellMode

        // Translation narration language matches nativeLanguage TTS locale
        chineseNarration.language = LanguageConfig.uiLanguages.first { $0.id == "zh" }?.ttsLocale ?? "zh-CN"
        chineseNarration.rateMultiplier = speedMultiplier

        loadFamiliar()
        loadTrashed()
        loadSold()
        loadPlayCounts()
        loadPool()
        loadPendingCandidates()
        migrateLegacyInitFlag()
        // Discard any pending notice from the old single-tap flow — schema changed.
        UserDefaults.standard.removeObject(forKey: "pendingUnlock_\(lid)")

    }

    /// One-shot migration: previously we used `poolInitialized_<lang>` both as a
    /// sticky pool-state flag AND a placement-shown flag, conflating two concerns.
    /// Now `placementShown_<lang>` is the only UI-state flag; pool size is purely
    /// state-driven. Promote the old flag to the new one if applicable.
    private func migrateLegacyInitFlag() {
        let d = UserDefaults.standard
        guard d.object(forKey: placementShownKey) == nil else { return }
        if d.bool(forKey: legacyPoolInitializedKey) {
            d.set(true, forKey: placementShownKey)
        }
    }

    // MARK: - Live Activity signal

    private func bumpLiveActivity() { liveActivityRevision += 1 }

    // MARK: - Live Activity state (pure data; AppModel decides when to push)

    @available(iOS 16.2, *)
    func liveActivityState() -> LLLBActivityAttributes.ContentState {
        let s   = currentSentence
        let idx = narration.highlightedTokenIndex
        let rawEmoji = s.tokens.indices.contains(idx) ? s.tokens[idx].emoji : ""
        let emoji = rawEmoji.isEmpty ? (s.tokens.first(where: { !$0.emoji.isEmpty })?.emoji ?? "") : rawEmoji
        return .init(
            emoji: emoji,
            text: s.text,
            ipa: s.ipa,
            translation: s.translation[nativeLanguage] ?? "",
            isPlaying: isAutoPlaying,
            showImage: showImage,
            showSpelling: showSpelling,
            showIPA: showIPA,
            showTranslation: showTranslation
        )
    }

    // MARK: - Sentence accessors

    var currentSentence: LessonSentence {
        if let ex = examplePlaylist, exampleIndex < ex.count { return ex[exampleIndex] }
        return currentMainSentence
            ?? LessonSentence(id: "0", text: "", ipa: "", translation: [:], cefr: "A1", rank: 9999, tokens: [])
    }

    var isVoiceExampleMode: Bool { examplePlaylist != nil }

    var isCurrentlyPlaying: Bool { narration.isSpeaking || chineseNarration.isSpeaking }

    /// When the current sentence is marked familiar, spelling/IPA/translation/readback are suppressed
    /// regardless of the individual toggle settings.
    var isFamiliarSuppressed: Bool { familiarIDs.contains(currentSentence.id) }

    // MARK: - Filtering

    func filteredSentences() -> [LessonSentence] {
        let poolSet = Set(pool)
        return mainSentences.filter { sentence in
            guard poolSet.contains(sentence.id)             else { return false }
            guard selectedLibraries.contains(sentence.cefr) else { return false }
            guard !archivedIDs.contains(sentence.id)        else { return false }
            return true
        }
    }

    // MARK: - Library loading

    func loadLibrary() {
        narration.language = config.ttsLocale
        loadFavorites()
        do {
            mainSentences = try SentenceLibrary.loadMainSentences(language: config.id)
            wordTable     = (try? SentenceLibrary.loadWordTable(language: config.id)) ?? []
            loadError     = nil
            loadLibrarySelection()
            pruneOrphanedIDs()
        } catch {
            if let de = error as? DecodingError {
                switch de {
                case .keyNotFound(let k, let ctx):
                    loadError = "Missing key: \(k.stringValue) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
                case .valueNotFound(let t, let ctx):
                    loadError = "Missing value: \(t) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
                case .typeMismatch(let t, let ctx):
                    loadError = "Type mismatch: \(t) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
                case .dataCorrupted(let ctx):
                    loadError = "Corrupted: \(ctx.debugDescription)"
                @unknown default:
                    loadError = error.localizedDescription
                }
            } else {
                loadError = error.localizedDescription
            }
            mainSentences = []
            wordTable     = []
        }
    }

    // MARK: - Playback control

    /// Speaks the current main-track sentence using chunked or connected mode
    /// depending on whether this is the final repeat.
    /// playsOnCurrent == 0 means no finishes yet, so next play is play #1.
    private func speakCurrentSentence() {
        let total = max(1, repeatsBeforeAdvance)
        if playsOnCurrent >= total - 1 {
            narration.speakConnected(currentSentence)
        } else {
            let shouldSpell = spellMode && playsOnCurrent == 0 && !familiarIDs.contains(currentSentence.id) && config.id != "zh"
            narration.speak(currentSentence, spellFirst: shouldSpell)
        }
    }

    private func startFresh() {
        let filtered = filteredSentences()
        guard loadError == nil, !filtered.isEmpty else { return }
        isAutoPlaying = true
        playsOnCurrent = 0
        narration.rateMultiplier = speedMultiplier
        chineseNarration.rateMultiplier = speedMultiplier
        guard let pick = filtered.randomElement() else { return }
        mainPlaylist = [pick.id]
        mainPlaylistIndex = 0
        currentMainSentence = pick
        beginCurrentSentence()
        bumpLiveActivity()
    }

    func pause() {
        isAutoPlaying = false
        narration.stop()
        chineseNarration.stop()
        playsOnCurrent = 0
        bumpLiveActivity()
    }

    func resume() {
        isAutoPlaying = true
        narration.rateMultiplier = speedMultiplier
        chineseNarration.rateMultiplier = speedMultiplier
        try? AVAudioSession.sharedInstance().setActive(true)
        speakCurrentSentence()
        bumpLiveActivity()
    }

    // MARK: - Silence background player

    /// Keeps AVAudioSession continuously active during auto-play so iOS does not
    /// detect silence during inter-sentence gaps and flip the lock-screen play/pause state.
    private var silencePlayer: AVAudioPlayer?

    private func startSilencePlayer() {
        guard silencePlayer == nil else { return }
        guard let player = try? AVAudioPlayer(data: Self.silenceWAV, fileTypeHint: "wav") else { return }
        player.volume = 0
        player.numberOfLoops = -1   // loop forever
        player.prepareToPlay()
        player.play()
        silencePlayer = player
    }

    private func stopSilencePlayer() {
        silencePlayer?.stop()
        silencePlayer = nil
    }

    /// Minimal 0.5-second silent 16-bit mono PCM WAV at 44 100 Hz.
    /// Generated once at class load; ~44 KB.
    private static let silenceWAV: Data = {
        let sampleRate: UInt32 = 44100
        let channels:   UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let frameCount   = sampleRate / 2          // 0.5 s
        let dataSize     = UInt32(frameCount) * UInt32(channels) * UInt32(bitsPerSample / 8)

        var d = Data()
        func le<T: FixedWidthInteger>(_ v: T) {
            withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) }
        }
        d.append(contentsOf: "RIFF".utf8); le(UInt32(36) + dataSize)
        d.append(contentsOf: "WAVE".utf8)
        d.append(contentsOf: "fmt ".utf8); le(UInt32(16))
        le(UInt16(1))                                                    // PCM
        le(channels)
        le(sampleRate)
        le(sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8))   // byte rate
        le(channels * (bitsPerSample / 8))                               // block align
        le(bitsPerSample)
        d.append(contentsOf: "data".utf8); le(dataSize)
        d.append(Data(count: Int(dataSize)))                             // silence
        return d
    }()

    func applySpeed(_ value: Double) {
        speedMultiplier = value
        narration.rateMultiplier = value
        chineseNarration.rateMultiplier = value
        if narration.isSpeaking {
            narration.stop()
            chineseNarration.stop()
            speakCurrentSentence()
        }
    }

    /// Cycle: sequential → singleLoop → shuffle → favorites → sequential.
    /// Skips `.favorites` when there are no favorites to play.
    func cyclePlayMode() {
        let next: PlayMode
        switch playMode {
        case .sequential: next = .singleLoop
        case .singleLoop: next = .shuffle
        case .shuffle:    next = favoritedIDs.isEmpty ? .sequential : .favorites
        case .favorites:  next = .sequential
        }
        setPlayMode(next)
    }

    /// Set play mode and run entry/exit side-effects for `.favorites` transitions.
    func setPlayMode(_ newMode: PlayMode) {
        let oldMode = playMode
        guard oldMode != newMode else { return }
        playMode = newMode
        if newMode == .favorites {
            enterFavoritesPlayback()
        } else if oldMode == .favorites {
            exitFavoritesPlayback()
        }
    }

    private func enterFavoritesPlayback() {
        let byID = Dictionary(uniqueKeysWithValues: mainSentences.map { ($0.id, $0) })
        let favs = favoritedIDs.compactMap { byID[$0] }
            .filter { !archivedIDs.contains($0.id) }
        guard !favs.isEmpty else {
            playMode = .sequential
            return
        }
        activatedTag = nil; isRandomTagMode = false
        focusedLemma = nil; focusedTokenText = ""
        narration.stop(); chineseNarration.stop(); playsOnCurrent = 0
        examplePlaylist = favs; exampleIndex = 0
        isAutoPlaying = true
        narration.rateMultiplier = speedMultiplier
        chineseNarration.rateMultiplier = speedMultiplier
        snapshotPlayCount()
        narration.speak(favs[0])
    }

    private func exitFavoritesPlayback() {
        examplePlaylist = nil; exampleIndex = 0; playsOnCurrent = 0
        narration.stop(); chineseNarration.stop()
        let filtered = filteredSentences()
        guard !filtered.isEmpty, let pick = filtered.randomElement() else { return }
        currentMainSentence = pick
        mainPlaylist.append(pick.id)
        mainPlaylistIndex = mainPlaylist.count - 1
        if mainPlaylist.count > 21 {
            mainPlaylist.removeFirst()
            mainPlaylistIndex -= 1
        }
        if isAutoPlaying { beginCurrentSentence() }
    }

    /// Snapshots the lifetime play count for the currently displayed sentence into
    /// `currentSentencePlayCount`. Call this whenever the displayed sentence changes.
    private func snapshotPlayCount() {
        currentSentencePlayCount = lifetimePlayCounts[currentSentence.id] ?? 0
    }

    /// Starts playback of the current sentence. If mode is `.before`, plays translation first (once per new sentence).
    private func beginCurrentSentence() {
        snapshotPlayCount()
        let resolvedTr = currentSentence.translation.resolvedTranslation(nativeLanguage: nativeLanguage)
        if translationPlaybackMode == .before, !isFamiliarSuppressed, !resolvedTr.isEmpty {
            chineseNarration.rateMultiplier = speedMultiplier
            chineseNarration.onUtteranceFinished = { [weak self] in
                Task { @MainActor in self?.speakCurrentSentence() }
            }
            chineseNarration.speakText(resolvedTr)
        } else {
            speakCurrentSentence()
        }
    }

    // MARK: - Utterance finished

    /// Optional gate consulted before advancing to the next sentence. Return
    /// false to soft-brake — the current sentence finishes, then playback
    /// pauses. AppModel wires this to the playback budget for free users.
    var shouldContinueAfterSentence: (() -> Bool)?

    /// Set by `shouldContinueAfterSentence` returning false; ContentView /
    /// AppModel can observe and surface the refill UI.
    @Published var didHitBudgetLimit: Bool = false

    private func handleUtteranceFinished() {
        guard isAutoPlaying else { return }
        if playMode == .singleLoop { narration.speak(currentSentence); return }
        guard !filteredSentences().isEmpty || examplePlaylist != nil else { return }

        // Soft brake: budget gate runs only at sentence boundaries so the
        // currently-playing sentence always completes naturally.
        if let gate = shouldContinueAfterSentence, !gate() {
            didHitBudgetLimit = true
            pause()
            return
        }

        // Increment lifetime play count and current-sentence display counter
        lifetimePlayCounts[currentSentence.id, default: 0] += 1
        currentSentencePlayCount += 1
        savePlayCounts()

        playsOnCurrent += 1
        if playsOnCurrent < max(1, repeatsBeforeAdvance) {
            speakCurrentSentence()
            return
        }
        playsOnCurrent = 0

        let resolvedTr = currentSentence.translation.resolvedTranslation(nativeLanguage: nativeLanguage)
        if translationPlaybackMode == .after, !isFamiliarSuppressed, !resolvedTr.isEmpty {
            chineseNarration.rateMultiplier = speedMultiplier
            chineseNarration.onUtteranceFinished = { [weak self] in
                Task { @MainActor in self?.advanceAfterTranslation() }
            }
            chineseNarration.speakText(resolvedTr)
            return
        }
        advanceAfterTranslation()
    }

    private func advanceAfterTranslation() {
        if let ex = examplePlaylist {
            let nextIndex = exampleIndex + 1
            if nextIndex >= ex.count, isRandomTagMode {
                let reshuffled = ex.shuffled()
                examplePlaylist = reshuffled
                exampleIndex = 0
                snapshotPlayCount()
                narration.speak(reshuffled[0])
            } else {
                exampleIndex = nextIndex < ex.count ? nextIndex : 0
                guard !ex.isEmpty else { return }
                snapshotPlayCount()
                narration.speak(ex[exampleIndex])
            }
        } else {
            pickNextMainSentence()
        }
    }

    // MARK: - Sentence navigation

    private func pickNextMainSentence() {
        // Walk forward through any pre-existing future entries, skipping any
        // that have since become invalid (archived, removed from library).
        // Without this skip, a sentence the user just archived can resurface
        // when they swipe to the next one.
        while mainPlaylistIndex < mainPlaylist.count - 1 {
            mainPlaylistIndex += 1
            let id = mainPlaylist[mainPlaylistIndex]
            if !archivedIDs.contains(id),
               let s = mainSentences.first(where: { $0.id == id }) {
                currentMainSentence = s
                beginCurrentSentence()
                return
            }
            // Skip — drop this stale entry from the future portion of the playlist
            mainPlaylist.remove(at: mainPlaylistIndex)
            mainPlaylistIndex -= 1
        }

        let filtered = filteredSentences()
        guard !filtered.isEmpty else { return }

        let chosen: LessonSentence
        switch playMode {
        case .favorites:
            // .favorites drives playback through examplePlaylist; this entry point
            // is a defensive no-op if reached without an active playlist.
            return

        case .sequential, .singleLoop:
            // Pool-order walk. Priority:
            // 1. Resume hint (post-splice / post-archive) — overrides current's position
            // 2. Otherwise advance from currentMainSentence's pool index
            // 3. If neither yields a filtered candidate, walk forward from start of pool
            // (singleLoop here only triggers on swipe-next; finishedUtterance keeps
            // the current sentence repeating.)
            let filteredIDs = Set(filtered.map(\.id))
            let n = pool.count
            guard n > 0 else { return }

            if let resumeID = sequentialResumeID,
               filteredIDs.contains(resumeID),
               let idx = pool.firstIndex(of: resumeID),
               let s = filtered.first(where: { $0.id == resumeID }) {
                sequentialResumeID = nil
                chosen = s
                _ = idx  // silence warning
            } else {
                let startIdx: Int
                if let cid = currentMainSentence?.id, let cidx = pool.firstIndex(of: cid) {
                    startIdx = (cidx + 1) % n
                } else {
                    startIdx = 0
                }
                var picked: LessonSentence?
                for i in 0..<n {
                    let idx = (startIdx + i) % n
                    let id  = pool[idx]
                    if filteredIDs.contains(id), let s = filtered.first(where: { $0.id == id }) {
                        picked = s
                        break
                    }
                }
                guard let s = picked else { return }
                chosen = s
            }

        case .shuffle:
            let currentID = currentMainSentence?.id
            let candidates = filtered.filter { $0.id != currentID }
            guard !candidates.isEmpty else {
                if currentMainSentence != nil { speakCurrentSentence() }
                return
            }
            let weights: [Double] = candidates.map { s in
                favoritedIDs.contains(s.id) ? 2.0 : (familiarIDs.contains(s.id) ? 0.2 : 1.0)
            }
            let total = weights.reduce(0, +)
            var pick   = Double.random(in: 0..<total)
            var c = candidates.last!
            for (i, w) in weights.enumerated() {
                pick -= w
                if pick <= 0 { c = candidates[i]; break }
            }
            chosen = c
        }

        // Append to playlist and trim old history beyond 20 entries
        mainPlaylist.append(chosen.id)
        mainPlaylistIndex = mainPlaylist.count - 1
        if mainPlaylist.count > 21 {
            mainPlaylist.removeFirst()
            mainPlaylistIndex -= 1
        }

        currentMainSentence = chosen
        beginCurrentSentence()
    }

    func goPreviousSentence() {
        narration.stop(); chineseNarration.stop(); playsOnCurrent = 0
        if let ex = examplePlaylist {
            if exampleIndex > 0 { exampleIndex -= 1 }
            snapshotPlayCount()
            narration.speak(ex[exampleIndex])
        } else {
            // Walk back through history skipping any archived/invalid entries,
            // and prune them from the playlist so they don't resurface again.
            while mainPlaylistIndex > 0 {
                let prevIdx = mainPlaylistIndex - 1
                let id = mainPlaylist[prevIdx]
                if !archivedIDs.contains(id),
                   let s = mainSentences.first(where: { $0.id == id }) {
                    mainPlaylistIndex = prevIdx
                    currentMainSentence = s
                    snapshotPlayCount()
                    speakCurrentSentence()
                    return
                }
                mainPlaylist.remove(at: prevIdx)
                mainPlaylistIndex -= 1
            }
        }
    }

    func goNextSentence() {
        narration.stop(); chineseNarration.stop(); playsOnCurrent = 0
        if let ex = examplePlaylist {
            exampleIndex = exampleIndex + 1 < ex.count ? exampleIndex + 1 : 0
            snapshotPlayCount()
            narration.speak(ex[exampleIndex])
        } else {
            pickNextMainSentence()
        }
    }

    // MARK: - Branch / focus / favorite

    func dismissVoiceBranch() {
        // Favorites is now a play mode — exiting routes through setPlayMode so the
        // entry/exit transitions stay coherent (random pool resume, etc.).
        if playMode == .favorites {
            setPlayMode(.sequential)
            return
        }
        activatedTag = nil; isRandomTagMode = false
        narration.stop(); chineseNarration.stop()
        examplePlaylist = nil; exampleIndex = 0; playsOnCurrent = 0
        focusedLemma    = nil; focusedTokenText = ""
        let mains = filteredSentences()
        guard !mains.isEmpty else { return }
        if let cms = currentMainSentence, mains.contains(where: { $0.id == cms.id }) {
            snapshotPlayCount()
            speakCurrentSentence()
        } else if let r = mains.randomElement() {
            currentMainSentence = r
            snapshotPlayCount()
            speakCurrentSentence()
        }
    }

    func focusOnToken(_ token: TokenChunk) {
        let lemma = token.lemma ?? token.text.trimmingCharacters(in: .whitespaces)
        guard !lemma.isEmpty else { return }
        focusedLemma = lemma
        focusedTokenText = token.text.trimmingCharacters(in: .whitespaces)
        activatedTag = nil; isRandomTagMode = false
        narration.stop(); chineseNarration.stop(); playsOnCurrent = 0
        let examples = mainSentences.filter { $0.tokens.contains { $0.lemma == lemma } }
        examplePlaylist = examples.isEmpty ? [currentSentence] : examples.shuffled()
        exampleIndex = 0
        if let pl = examplePlaylist, !pl.isEmpty { snapshotPlayCount(); narration.speak(pl[0]) }
    }

    func enterFavoriteMode() {
        setPlayMode(.favorites)
    }

    func activateTag(_ name: String) {
        // Tag playlists show all tagged sentences that are CEFR-eligible and not archived.
        let tagSentences = mainSentences.filter { s in
            guard selectedLibraries.contains(s.cefr) else { return false }
            guard !archivedIDs.contains(s.id) else { return false }
            return s.tags.contains { $0.name == name }
        }
        guard !tagSentences.isEmpty else { return }
        let isOrdered = tagSentences.contains { s in
            s.tags.contains { $0.name == name && $0.index != nil }
        }
        activatedTag = name
        isRandomTagMode = !isOrdered
        narration.stop(); chineseNarration.stop(); playsOnCurrent = 0
        if playMode == .favorites { playMode = .sequential }
        focusedLemma = nil; focusedTokenText = ""
        if isOrdered {
            examplePlaylist = tagSentences.sorted {
                let ia = $0.tags.first { $0.name == name }?.index ?? Int.max
                let ib = $1.tags.first { $0.name == name }?.index ?? Int.max
                return ia < ib
            }
        } else {
            examplePlaylist = tagSentences.shuffled()
        }
        exampleIndex = 0
        isAutoPlaying = true
        narration.rateMultiplier = speedMultiplier
        chineseNarration.rateMultiplier = speedMultiplier
        if let pl = examplePlaylist, !pl.isEmpty {
            snapshotPlayCount()
            narration.speak(pl[0])
        }
    }

    func toggleFavorite(for id: String) {
        if let idx = favoritedIDs.firstIndex(of: id) {
            favoritedIDs.remove(at: idx)
            // If this drained the favorites list while the user is in favorites
            // mode, fall back to sequential so the UI doesn't strand on an empty
            // playlist.
            if playMode == .favorites && favoritedIDs.isEmpty {
                setPlayMode(.sequential)
            }
        } else {
            favoritedIDs.append(id)
        }
        saveFavorites()
    }

    func toggleFamiliar() {
        let id = currentSentence.id
        if familiarIDs.contains(id) { familiarIDs.remove(id) } else { familiarIDs.insert(id) }
        saveFamiliar()
    }

    // MARK: - Archive

    func archiveCurrentSentence(as kind: ArchiveKind) {
        let id = currentSentence.id
        switch kind {
        case .mastered: masteredIDs.insert(id)
        case .later:    laterIDs.insert(id)
        }
        if let fIdx = favoritedIDs.firstIndex(of: id) { favoritedIDs.remove(at: fIdx) }
        familiarIDs.remove(id)
        // Capture sequential resume target before mutating pool: the ID that was
        // right after the archived sentence in pool order.
        if playMode == .sequential, sequentialResumeID == nil,
           let cidx = pool.firstIndex(of: id), pool.count > 1 {
            let nextIdx = (cidx + 1) % pool.count
            sequentialResumeID = pool[nextIdx]
        }
        if let idx = pool.firstIndex(of: id) {
            pool.remove(at: idx)
            savePool()
        }
        saveArchived(); saveFavorites(); saveFamiliar()
        tryUnlockAfterArchive()
        narration.stop(); chineseNarration.stop(); playsOnCurrent = 0
        if let ex = examplePlaylist {
            let remaining = ex.filter { $0.id != id }
            if remaining.isEmpty {
                dismissVoiceBranch()
            } else {
                let idx = min(exampleIndex, remaining.count - 1)
                examplePlaylist = remaining; exampleIndex = idx
                narration.speak(remaining[idx])
            }
        } else {
            pickNextMainSentence()
        }
    }

    func restoreSentence(id: String) {
        masteredIDs.remove(id)
        laterIDs.remove(id)
        saveArchived()
        if !pool.contains(id) {
            pool.append(id)
            savePool()
        }
    }

    func sellArchivedSentence(id: String) {
        masteredIDs.remove(id)
        laterIDs.remove(id)
        soldIDs.insert(id)
        saveArchived()
        saveSold()
        candyStore?.addCandy(8)
        candyStore?.removeSentence(id, language: config.id)
    }

    func masteredSentences() -> [LessonSentence] {
        mainSentences.filter { masteredIDs.contains($0.id) }
    }

    func laterSentences() -> [LessonSentence] {
        mainSentences.filter { laterIDs.contains($0.id) }
    }

    /// Legacy alias for external compatibility.
    func trashedSentences() -> [LessonSentence] {
        mainSentences.filter { archivedIDs.contains($0.id) }
    }

    // MARK: - Library selection

    func saveLibrarySelection() {
        UserDefaults.standard.set(Array(selectedLibraries), forKey: librarySelectionStorageKey)
    }

    private func loadLibrarySelection() {
        let allAvailable = Set(availableLibraries.map(\.id))
        guard !allAvailable.isEmpty else { return }

        // Which levels are genuinely new since the last run?
        let previouslyKnown = Set(UserDefaults.standard.stringArray(forKey: knownLibrariesStorageKey) ?? [])
        let newLevels = allAvailable.subtracting(previouslyKnown)

        if let saved = UserDefaults.standard.stringArray(forKey: librarySelectionStorageKey) {
            // Honour the user's explicit choices; auto-enable any brand-new CEFR levels
            let validSaved = Set(saved).intersection(allAvailable)
            let merged     = validSaved.union(newLevels)
            selectedLibraries = merged.isEmpty ? allAvailable : merged
        } else {
            // First launch for this language: select everything available
            selectedLibraries = allAvailable
        }

        // Remember all currently available levels so new ones can be detected next run
        UserDefaults.standard.set(Array(allAvailable), forKey: knownLibrariesStorageKey)
    }

    func reloadWithCurrentLibrary() {
        let filtered = filteredSentences()
        guard !filtered.isEmpty else { return }
        narration.stop(); chineseNarration.stop()
        playsOnCurrent = 0; mainPlaylist = []; mainPlaylistIndex = -1
        examplePlaylist = nil; exampleIndex = 0
        if playMode == .favorites { playMode = .sequential }
        focusedLemma = nil; focusedTokenText = ""
        let pick = filtered.randomElement()!
        mainPlaylist = [pick.id]; mainPlaylistIndex = 0
        currentMainSentence = pick
        snapshotPlayCount()
        speakCurrentSentence()
    }

    // MARK: - Persistence helpers

    private func saveFavorites() {
        UserDefaults.standard.set(favoritedIDs, forKey: favoritesStorageKey)
    }
    private func loadFavorites() {
        if let arr = UserDefaults.standard.stringArray(forKey: favoritesStorageKey) {
            // Dedup defensively in case an older Set-roundtripped store has duplicates;
            // preserve first-seen order to match "by favorite time" semantics.
            var seen: Set<String> = []
            favoritedIDs = arr.filter { seen.insert($0).inserted }
            return
        }
        // One-time migration from old flat key (French only)
        if config.id == "fr",
           let legacy = UserDefaults.standard.stringArray(forKey: "favoritedIDs") {
            var seen: Set<String> = []
            favoritedIDs = legacy.filter { seen.insert($0).inserted }
            saveFavorites()
        } else {
            favoritedIDs = []
        }
    }
    private func saveFamiliar() {
        UserDefaults.standard.set(Array(familiarIDs), forKey: familiarStorageKey)
    }
    private func loadFamiliar() {
        if let arr = UserDefaults.standard.stringArray(forKey: familiarStorageKey) {
            familiarIDs = Set(arr)
        }
    }
    private func saveArchived() {
        UserDefaults.standard.set(Array(masteredIDs), forKey: masteredStorageKey)
        UserDefaults.standard.set(Array(laterIDs),    forKey: laterStorageKey)
    }
    private func savePool() {
        UserDefaults.standard.set(pool, forKey: poolStorageKey)
    }
    private func loadPool() {
        if let arr = UserDefaults.standard.stringArray(forKey: poolStorageKey) {
            pool = arr
        }
    }

    /// Drop sentence IDs that no longer exist in the loaded library. Called after
    /// `loadLibrary()` populates `mainSentences` so that any persisted ID cluster
    /// (pool, pending candidate cards, currentMainSentence) reflects only sentences
    /// that can actually be played. Without this, `pool.count` is artificially
    /// inflated by deleted IDs, breaking the deficit-driven refill in
    /// `tryUnlockAfterArchive` and `ensurePoolFilled`.
    private func pruneOrphanedIDs() {
        let valid = Set(mainSentences.map(\.id))

        let prunedPool = pool.filter { valid.contains($0) }
        if prunedPool.count != pool.count {
            pool = prunedPool
            savePool()
        }

        let prunedGroups: [[String]] = pendingCandidateGroups
            .map { $0.filter { valid.contains($0) } }
            .filter { !$0.isEmpty }
        if prunedGroups != pendingCandidateGroups {
            pendingCandidateGroups = prunedGroups
            pendingPicksRemaining  = min(pendingPicksRemaining, prunedGroups.count)
            savePendingCandidates()
        }

        if let cms = currentMainSentence, !valid.contains(cms.id) {
            currentMainSentence = nil
        }
    }
    private func savePendingCandidates() {
        if let data = try? JSONEncoder().encode(pendingCandidateGroups) {
            UserDefaults.standard.set(data, forKey: pendingCandidatesKey)
        }
        UserDefaults.standard.set(pendingPicksRemaining, forKey: pendingRemainingKey)
    }
    private func loadPendingCandidates() {
        if let data = UserDefaults.standard.data(forKey: pendingCandidatesKey),
           let groups = try? JSONDecoder().decode([[String]].self, from: data) {
            pendingCandidateGroups = groups
        }
        pendingPicksRemaining = UserDefaults.standard.integer(forKey: pendingRemainingKey)
    }
    /// Refill pool toward `poolCapacity` after an archive event by *offering* 2× the
    /// deficit as user-pickable candidates (so user steers what enters their pool).
    /// Deficit 0 → nothing. 1 → 2 candidates, user picks 1. ≥2 → 4 candidates, user picks 2.
    /// Tag-group sentences become a single card that pulls the whole group when picked.
    /// While a batch is in progress, further archive triggers are skipped to avoid pile-up.
    private func tryUnlockAfterArchive() {
        guard pendingCandidateGroups.isEmpty else { return }

        let deficit = poolCapacity - pool.count
        guard deficit > 0 else { return }
        let target  = (deficit == 1) ? 1 : 2
        let toShow  = target * 2

        let snapshot = poolSentences + mainSentences.filter { archivedIDs.contains($0.id) }

        var staged: Set<String> = Set(pool)
        var groups: [[String]] = []

        // Slot 1 (always): a sentence at the user's current lowest pool level.
        // Acts as a "stay-safe / review" option so they can always anchor lower
        // and prevent unwanted upward drift.
        let presentLevels = Set(poolSentences.map(\.cefr))
        let lowestPresent = LevelSystem.sorted(Array(presentLevels), using: config.levelOrder).first
        if let lowest = lowestPresent {
            let lowestCands = mainSentences.filter {
                $0.cefr == lowest
                && !staged.contains($0.id)
                && !archivedIDs.contains($0.id)
                && !soldIDs.contains($0.id)
            }
            if let picked = lowestCands.randomElement() {
                let group = expandTagGroup(for: picked).filter { !staged.contains($0) }
                if !group.isEmpty {
                    for id in group { staged.insert(id) }
                    groups.append(group)
                }
            }
        }

        // Remaining slots: selector-driven (distribution-aware, hard-capped to max+1)
        while groups.count < toShow {
            let candidates = mainSentences.filter {
                !staged.contains($0.id)
                && !archivedIDs.contains($0.id)
                && !soldIDs.contains($0.id)
            }
            guard let picked = unlockSelector.pickNext(
                pool: snapshot,
                candidates: candidates,
                levelOrder: config.levelOrder
            ) else { break }
            let group = expandTagGroup(for: picked).filter { !staged.contains($0) }
            guard !group.isEmpty else { continue }
            for id in group { staged.insert(id) }
            groups.append(group)
        }

        guard !groups.isEmpty else { return }
        pendingCandidateGroups = groups
        pendingPicksRemaining  = min(target, groups.count)
        savePendingCandidates()
    }

    /// User tapped a card — commit its sentences to the pool and decrement the picker.
    /// When `pendingPicksRemaining` hits 0 (or candidates run out), the batch clears
    /// and the picker view dismisses. Picked sentences also splice into the main
    /// playlist for immediate sequential playback (unless in example/voice-branch mode).
    func pickCandidate(at index: Int) {
        guard pendingCandidateGroups.indices.contains(index) else { return }
        // Capture sequential resume target BEFORE mutating: ID after current in
        // pool order. After splice plays out, sequence resumes from this ID.
        if playMode == .sequential, sequentialResumeID == nil,
           let cid = currentMainSentence?.id,
           let cidx = pool.firstIndex(of: cid), pool.count > 1 {
            let nextIdx = (cidx + 1) % pool.count
            sequentialResumeID = pool[nextIdx]
        }
        let chosen = pendingCandidateGroups.remove(at: index)
        pool.append(contentsOf: chosen)
        savePool()
        pendingPicksRemaining = max(0, pendingPicksRemaining - 1)

        // Auto-clear if quota met or no candidates left
        if pendingPicksRemaining == 0 || pendingCandidateGroups.isEmpty {
            pendingCandidateGroups.removeAll()
            pendingPicksRemaining = 0
        }
        savePendingCandidates()

        // Queue picked sentences as next on the main track (skip if in voice-branch).
        guard examplePlaylist == nil else { return }
        let insertAt = max(0, min(mainPlaylistIndex + 1, mainPlaylist.count))
        let head = Array(mainPlaylist[..<insertAt])
        let tail = Array(mainPlaylist[insertAt...])
        mainPlaylist = head + chosen + tail
        narration.stop(); chineseNarration.stop(); playsOnCurrent = 0
        pickNextMainSentence()
    }

    /// Resolved sentence objects per candidate group, in display order.
    var pendingCandidateSentences: [[LessonSentence]] {
        let byID = Dictionary(uniqueKeysWithValues: mainSentences.map { ($0.id, $0) })
        return pendingCandidateGroups.map { group in
            group.compactMap { byID[$0] }
        }
    }

    /// If `sentence` carries an indexed (ordered content) tag, return all sentences
    /// in that tag group sorted by `tag.index`, excluding archived ones.
    /// Otherwise returns just the input sentence's ID.
    private func expandTagGroup(for sentence: LessonSentence) -> [String] {
        guard let indexedTag = sentence.tags.first(where: { $0.index != nil }) else {
            return [sentence.id]
        }
        return mainSentences
            .filter { s in
                s.tags.contains { $0.name == indexedTag.name && $0.index != nil }
                && !archivedIDs.contains(s.id)
            }
            .sorted { a, b in
                let ai = a.tags.first(where: { $0.name == indexedTag.name })?.index ?? Int.max
                let bi = b.tags.first(where: { $0.name == indexedTag.name })?.index ?? Int.max
                return ai < bi
            }
            .map(\.id)
    }

    /// Whether the placement-test UI has already been offered to the user (whether
    /// completed or skipped) for this language. Pure UI-state flag — does NOT gate
    /// pool content. Pool growth is handled by `ensurePoolFilled()` regardless.
    /// Backed by `placementShownKey` in UserDefaults; the @Published mirror lets
    /// downstream views (e.g. RootView's welcome-gift gate) react to completion.
    @Published private(set) var wasPlacementShown: Bool = false

    func markPlacementShown() {
        UserDefaults.standard.set(true, forKey: placementShownKey)
        wasPlacementShown = true
    }

    /// Fallback pool allocation when no placement test is run (skip path or no
    /// placement bank for this language). Fills 100 slots starting from the
    /// lowest available level and cascading up; if the entire library is smaller
    /// than 100, returns whatever's available across all levels. Multi-language
    /// safe — uses `config.levelOrder`, never references specific level names.
    func defaultBeginnerAllocation() -> [String: Int] {
        let order = LevelSystem.sorted(mainSentences.map(\.cefr), using: config.levelOrder)
        var remaining = 100
        var alloc: [String: Int] = [:]
        for level in order {
            guard remaining > 0 else { break }
            let avail = mainSentences.filter {
                $0.cefr == level && !archivedIDs.contains($0.id)
            }.count
            let take = min(avail, remaining)
            if take > 0 {
                alloc[level] = take
                remaining -= take
            }
        }
        return alloc
    }

    /// Replaces the pool with sentences sampled per `allocation` (level → slot count).
    /// Used for **initial** seeding — placement-test outcome or skip default.
    /// Ordering follows `config.levelOrder` (easiest first), so sequential playback
    /// starts low. Already-archived sentences are excluded. Pure write — no flag
    /// gating, no auto-fill afterward (caller decides whether to also `ensurePoolFilled`).
    /// Works with any level system; reads names only via `config.levelOrder`.
    func seedPool(allocation: [String: Int]) {
        var seeded: [String] = []
        for level in LevelSystem.sorted(Array(allocation.keys), using: config.levelOrder) {
            let count = allocation[level] ?? 0
            guard count > 0 else { continue }
            // Exclude content-tagged sentences (story groups like fables, scene
            // dialogs) — these enter the pool only via deliberate archive-unlock,
            // never as part of the initial random seed.
            let candidates = mainSentences.filter {
                $0.cefr == level && !archivedIDs.contains($0.id) && $0.tags.isEmpty
            }
            let picked = Array(candidates.shuffled().prefix(count)).map(\.id)
            seeded.append(contentsOf: picked)
        }
        pool = seeded
        savePool()

        if isActive && currentMainSentence == nil { startFresh() }
    }

    /// Brings pool size up to `min(poolCapacity, viable library size)` using the
    /// unlock selector. Idempotent: no-op if pool is already at target. Used at
    /// app launch, after placement (to top off any allocation shortfall), and
    /// anywhere we want to ensure the pool is full. Self-heals legacy broken
    /// state (e.g., pool empty due to old hardcoded-A1 seed for HSK languages).
    func ensurePoolFilled() {
        // Same exclusion rule as seedPool: content-tagged sentences (story groups)
        // are reserved for deliberate archive-unlock and never auto-fill the pool.
        let viable = mainSentences.filter {
            !archivedIDs.contains($0.id) && !soldIDs.contains($0.id) && $0.tags.isEmpty
        }
        let target = min(poolCapacity, viable.count)
        let inPoolBefore = pool.count
        guard pool.count < target else { return }

        var inPool = Set(pool)
        var added: [String] = []

        while inPool.count + added.count < target {
            let stagedSentences = added.compactMap { id in
                mainSentences.first(where: { $0.id == id })
            }
            let candidates = viable.filter {
                !inPool.contains($0.id) && !added.contains($0.id)
            }
            guard let picked = unlockSelector.pickNext(
                pool: poolSentences + stagedSentences,
                candidates: candidates,
                levelOrder: config.levelOrder
            ) else { break }

            for id in expandTagGroup(for: picked) where !inPool.contains(id) && !added.contains(id) {
                added.append(id)
            }
        }

        guard !added.isEmpty else { return }
        pool.append(contentsOf: added)
        savePool()

        if isActive && currentMainSentence == nil { startFresh() }
    }
    private func loadTrashed() {
        // Migration: old trashedIDs → masteredIDs
        let oldKey = "trashedIDs_\(config.id)"
        if let arr = UserDefaults.standard.stringArray(forKey: oldKey), !arr.isEmpty {
            masteredIDs = masteredIDs.union(Set(arr))
            UserDefaults.standard.removeObject(forKey: oldKey)
            saveArchived()
        }
        if let arr = UserDefaults.standard.stringArray(forKey: masteredStorageKey) {
            masteredIDs = Set(arr)
        }
        if let arr = UserDefaults.standard.stringArray(forKey: laterStorageKey) {
            laterIDs = Set(arr)
        }
    }
    private func saveSold() {
        UserDefaults.standard.set(Array(soldIDs), forKey: soldStorageKey)
    }
    private func loadSold() {
        if let arr = UserDefaults.standard.stringArray(forKey: soldStorageKey) {
            soldIDs = Set(arr)
        }
    }
    private func savePlayCounts() {
        if let data = try? JSONEncoder().encode(lifetimePlayCounts) {
            UserDefaults.standard.set(data, forKey: playCountsStorageKey)
        }
    }
    private func loadPlayCounts() {
        if let data = UserDefaults.standard.data(forKey: playCountsStorageKey),
           let dict = try? JSONDecoder().decode([String: Int].self, from: data) {
            lifetimePlayCounts = dict
        }
    }
}

// MARK: - Darwin Live Activity Router

/// Registers Darwin notification observers for widget → app playback control.
/// Uses a closure to get the currently active session so it stays language-agnostic.
@MainActor
final class LLLBDarwinLiveActivityRouter {
    private let activeSessionProvider: () -> LessonSessionModel
    private var didRegister = false

    init(activeSessionProvider: @escaping () -> LessonSessionModel) {
        self.activeSessionProvider = activeSessionProvider
    }

    var activeSession: LessonSessionModel { activeSessionProvider() }

    func registerDarwinObserversIfNeeded() {
        guard !didRegister else { return }
        didRegister = true
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let opaque = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(center, opaque, lllbDarwinRouterPlaypause,
            "com.learn.LLLB.playpause" as CFString, nil, .deliverImmediately)
        CFNotificationCenterAddObserver(center, opaque, lllbDarwinRouterPrevious,
            "com.learn.LLLB.previous" as CFString, nil, .deliverImmediately)
        CFNotificationCenterAddObserver(center, opaque, lllbDarwinRouterNext,
            "com.learn.LLLB.next" as CFString, nil, .deliverImmediately)
    }

    deinit {
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
    }
}

private func lllbDarwinRouterPlaypause(
    _ center: CFNotificationCenter?, _ observer: UnsafeMutableRawPointer?,
    _ name: CFNotificationName?, _ object: UnsafeRawPointer?, _ userInfo: CFDictionary?
) {
    guard let observer else { return }
    let router = Unmanaged<LLLBDarwinLiveActivityRouter>.fromOpaque(observer).takeUnretainedValue()
    Task { @MainActor in
        let s = router.activeSession
        if s.isAutoPlaying { s.pause() } else { s.resume() }
    }
}

private func lllbDarwinRouterPrevious(
    _ center: CFNotificationCenter?, _ observer: UnsafeMutableRawPointer?,
    _ name: CFNotificationName?, _ object: UnsafeRawPointer?, _ userInfo: CFDictionary?
) {
    guard let observer else { return }
    let router = Unmanaged<LLLBDarwinLiveActivityRouter>.fromOpaque(observer).takeUnretainedValue()
    Task { @MainActor in router.activeSession.goPreviousSentence() }
}

private func lllbDarwinRouterNext(
    _ center: CFNotificationCenter?, _ observer: UnsafeMutableRawPointer?,
    _ name: CFNotificationName?, _ object: UnsafeRawPointer?, _ userInfo: CFDictionary?
) {
    guard let observer else { return }
    let router = Unmanaged<LLLBDarwinLiveActivityRouter>.fromOpaque(observer).takeUnretainedValue()
    Task { @MainActor in router.activeSession.goNextSentence() }
}
