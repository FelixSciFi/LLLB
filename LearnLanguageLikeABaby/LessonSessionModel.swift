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
        let knownOrder = ["A1", "A2", "B1", "B2", "C1", "C2",
                          "HSK1", "HSK2", "HSK3", "HSK4", "HSK5", "HSK6"]
        let present = Set(mainSentences.map(\.cefr))
        let known   = knownOrder.filter { present.contains($0) }
        let unknown = present.subtracting(knownOrder).sorted()
        return (known + unknown).map { LibraryOption(id: $0, name: $0) }
    }

    @Published var mainSentences:   [LessonSentence] = []
    @Published var wordTable:       [WordEntry]       = []
    @Published var selectedLibraries: Set<String>

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

    @Published var favoritedIDs: Set<String> = []
    @Published var isFavoriteMode: Bool = false
    @Published var activatedTag: String? = nil
    private var isRandomTagMode: Bool = false

    @Published var masteredIDs:          Set<String> = []
    @Published var laterIDs:             Set<String> = []
    var archivedIDs: Set<String> { masteredIDs.union(laterIDs) }
    @Published var feedbackMarkedIDs:   Set<String> = []
    @Published var feedbackDeletedIDs:  Set<String> = []
    @Published var familiarIDs:         Set<String> = []

    /// Sentence IDs in the user's active pool, ordered by entry time (oldest first).
    /// Acts like a music playlist: archive removes, restore appends, deficit-unlock appends.
    @Published var pool: [String] = []

    /// IDs unlocked by the most recent archive but awaiting user confirmation.
    /// Persisted across launches so the popup survives app kill.
    @Published var pendingUnlockIDs: [String] = []

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

    // MARK: - Storage keys

    private var familiarStorageKey:         String { "familiarIDs_\(config.id)" }
    private var masteredStorageKey:          String { "masteredIDs_\(config.id)" }
    private var laterStorageKey:             String { "laterIDs_\(config.id)" }
    private var soldStorageKey:             String { "soldIDs_\(config.id)" }
    private var feedbackMarkedStorageKey:   String { "feedbackMarkedIDs_\(config.id)" }
    private var feedbackDeletedStorageKey:  String { "feedbackDeletedIDs_\(config.id)" }
    private var favoritesStorageKey:        String { "favoritedIDs_\(config.id)" }
    private var librarySelectionStorageKey: String { "selectedLibraries_\(config.id)" }
    /// Stores which CEFR levels were known last time; new levels detected by diffing against this.
    private var knownLibrariesStorageKey:   String { "knownLibraries_\(config.id)" }
    private var playCountsStorageKey: String { "lifetimePlayCounts_\(config.id)" }
    private var poolStorageKey:             String { "pool_\(config.id)" }
    private var poolInitializedKey:         String { "poolInitialized_\(config.id)" }
    private var pendingUnlockStorageKey:    String { "pendingUnlock_\(config.id)" }

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
        _selectedLibraries      = Published(initialValue: Set(["A1", "A2"]))
        _speedMultiplier        = Published(initialValue: Self.loadDouble(d: d, key: "speed_\(lid)", default: 0.75))
        _repeatsBeforeAdvance   = Published(initialValue: Self.loadInt(d: d, key: "repeats_\(lid)", default: 3))
        _poolCapacity           = Published(initialValue: Self.loadInt(d: d, key: "poolCapacity_\(lid)", default: 100))
        let rawPlayMode = d.string(forKey: "playMode_\(lid)") ?? "shuffle"
        _playMode               = Published(initialValue: PlayMode(rawValue: rawPlayMode) ?? .shuffle)
        _showImage              = Published(initialValue: Self.loadBool(d: d, key: "showImage_\(lid)", default: true))
        _showSpelling           = Published(initialValue: Self.loadBool(d: d, key: "showSpelling_\(lid)", default: false))
        _showIPA                = Published(initialValue: Self.loadBool(d: d, key: "showIPA_\(lid)", default: false))
        _showTranslation        = Published(initialValue: Self.loadBool(d: d, key: "showTranslation_\(lid)", default: false))
        _spellMode              = Published(initialValue: Self.loadBool(d: d, key: "spellMode_\(lid)", default: false))
        let rawMode = d.string(forKey: "translationPlayback_\(lid)")
            ?? (d.bool(forKey: "chineseReading_\(lid)") ? "after" : "off")
        _translationPlaybackMode = Published(initialValue: TranslationPlaybackMode(rawValue: rawMode) ?? .off)

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
        loadFeedbackMarked()
        loadFeedbackDeleted()
        loadPlayCounts()
        loadPool()
        loadPendingUnlock()

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
            guard !feedbackMarkedIDs.contains(sentence.id)  else { return false }
            guard !feedbackDeletedIDs.contains(sentence.id) else { return false }
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
            seedPoolIfNeeded()
            let f = filteredSentences().count
            print("[\(config.id)] filteredSentences: \(f) / mainSentences: \(mainSentences.count) pool: \(pool.count) ownedLemmas: \(candyStore?.ownedLemmas(for: config.id).count ?? 0)")
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
            let shouldSpell = spellMode && playsOnCurrent == 0 && !familiarIDs.contains(currentSentence.id)
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

    /// Cycle: shuffle → sequential → singleLoop → shuffle.
    func cyclePlayMode() {
        switch playMode {
        case .shuffle:    playMode = .sequential
        case .sequential: playMode = .singleLoop
        case .singleLoop: playMode = .shuffle
        }
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

    private func handleUtteranceFinished() {
        guard isAutoPlaying else { return }
        if playMode == .singleLoop { narration.speak(currentSentence); return }
        guard !filteredSentences().isEmpty || examplePlaylist != nil else { return }

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
        // If there's already a future entry in the playlist, just advance to it
        if mainPlaylistIndex < mainPlaylist.count - 1 {
            mainPlaylistIndex += 1
            if let s = mainSentences.first(where: { $0.id == mainPlaylist[mainPlaylistIndex] }) {
                currentMainSentence = s
                beginCurrentSentence()
                return
            }
            // ID no longer valid (trashed etc.) — fall through to generate a new one
            mainPlaylist.removeLast(mainPlaylist.count - mainPlaylistIndex)
            mainPlaylistIndex = mainPlaylist.count - 1
        }

        let filtered = filteredSentences()
        guard !filtered.isEmpty else { return }

        let chosen: LessonSentence
        switch playMode {
        case .sequential, .singleLoop:
            // Pool-order next, wrap around at end. (singleLoop here only triggers
            // on swipe-next; finishedUtterance keeps the current sentence repeating.)
            let filteredIDs = Set(filtered.map(\.id))
            let ordered = pool.filter { filteredIDs.contains($0) }
            guard !ordered.isEmpty else { return }
            let nextID: String
            if let cid = currentMainSentence?.id, let idx = ordered.firstIndex(of: cid) {
                nextID = ordered[(idx + 1) % ordered.count]
            } else {
                nextID = ordered[0]
            }
            guard let s = mainSentences.first(where: { $0.id == nextID }) else { return }
            chosen = s

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
        } else if mainPlaylistIndex > 0 {
            mainPlaylistIndex -= 1
            if let s = mainSentences.first(where: { $0.id == mainPlaylist[mainPlaylistIndex] }) {
                currentMainSentence = s
                snapshotPlayCount()
                speakCurrentSentence()
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
        activatedTag = nil; isRandomTagMode = false
        narration.stop(); chineseNarration.stop()
        examplePlaylist = nil; exampleIndex = 0; playsOnCurrent = 0
        isFavoriteMode  = false
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
        let favSentences = filteredSentences().filter { favoritedIDs.contains($0.id) }
        guard !favSentences.isEmpty else { return }
        isFavoriteMode = true
        activatedTag = nil; isRandomTagMode = false
        narration.stop(); chineseNarration.stop(); playsOnCurrent = 0
        examplePlaylist = favSentences.shuffled(); exampleIndex = 0
        if let ex = examplePlaylist, !ex.isEmpty { snapshotPlayCount(); narration.speak(ex[0]) }
    }

    func activateTag(_ name: String) {
        // Tag playlists bypass lemma-ownership filtering — show all tagged sentences
        // that are CEFR-eligible and not trashed/deleted.
        let tagSentences = mainSentences.filter { s in
            guard selectedLibraries.contains(s.cefr) else { return false }
            guard !archivedIDs.contains(s.id) else { return false }
            guard !feedbackDeletedIDs.contains(s.id) else { return false }
            return s.tags.contains { $0.name == name }
        }
        guard !tagSentences.isEmpty else { return }
        let isOrdered = tagSentences.contains { s in
            s.tags.contains { $0.name == name && $0.index != nil }
        }
        activatedTag = name
        isRandomTagMode = !isOrdered
        narration.stop(); chineseNarration.stop(); playsOnCurrent = 0
        isFavoriteMode = false
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
        if favoritedIDs.contains(id) { favoritedIDs.remove(id) } else { favoritedIDs.insert(id) }
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
        favoritedIDs.remove(id)
        familiarIDs.remove(id)
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

    // MARK: - Feedback

    func feedbackMark() { addFeedback(to: &feedbackMarkedIDs, save: saveFeedbackMarked) }
    func feedbackDelete() { addFeedback(to: &feedbackDeletedIDs, save: saveFeedbackDeleted) }

    private func addFeedback(to set: inout Set<String>, save: () -> Void) {
        set.insert(currentSentence.id)
        save()
        narration.stop(); chineseNarration.stop(); playsOnCurrent = 0
        pickNextMainSentence()
    }

    func clearFeedback() {
        feedbackMarkedIDs.removeAll()
        feedbackDeletedIDs.removeAll()
        saveFeedbackMarked()
        saveFeedbackDeleted()
    }

    func feedbackReport() -> String {
        let marked  = feedbackMarkedIDs.sorted().joined(separator: "\n")
        let deleted = feedbackDeletedIDs.sorted().joined(separator: "\n")
        var parts: [String] = []
        if !feedbackMarkedIDs.isEmpty  { parts.append("[标记]\n\(marked)") }
        if !feedbackDeletedIDs.isEmpty { parts.append("[删除]\n\(deleted)") }
        return parts.joined(separator: "\n\n")
    }

    var hasFeedback: Bool { !feedbackMarkedIDs.isEmpty || !feedbackDeletedIDs.isEmpty }

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
        isFavoriteMode = false; focusedLemma = nil; focusedTokenText = ""
        let pick = filtered.randomElement()!
        mainPlaylist = [pick.id]; mainPlaylistIndex = 0
        currentMainSentence = pick
        snapshotPlayCount()
        speakCurrentSentence()
    }

    // MARK: - Persistence helpers

    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoritedIDs), forKey: favoritesStorageKey)
    }
    private func loadFavorites() {
        if let arr = UserDefaults.standard.stringArray(forKey: favoritesStorageKey) {
            favoritedIDs = Set(arr); return
        }
        // One-time migration from old flat key (French only)
        if config.id == "fr",
           let legacy = UserDefaults.standard.stringArray(forKey: "favoritedIDs") {
            favoritedIDs = Set(legacy); saveFavorites()
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
    private func savePendingUnlock() {
        UserDefaults.standard.set(pendingUnlockIDs, forKey: pendingUnlockStorageKey)
    }
    private func loadPendingUnlock() {
        if let arr = UserDefaults.standard.stringArray(forKey: pendingUnlockStorageKey) {
            pendingUnlockIDs = arr
        }
    }
    /// Refill pool toward `poolCapacity` after an archive event.
    /// Deficit==0 → no-op; ==1 → unlock 1; ≥2 → unlock 2 (cap intentional, slow trickle).
    /// Capacity decreases never trigger eviction (per spec).
    /// If a picked sentence belongs to an indexed (ordered) tag group, the whole
    /// group is unlocked together as a single quota slot (pool may overflow capacity).
    /// Newly-unlocked IDs are STAGED in `pendingUnlockIDs`; they enter the pool only
    /// after the user confirms via `commitPendingUnlock()`. While a notice is pending,
    /// further unlock attempts are skipped to prevent popup pile-up.
    private func tryUnlockAfterArchive() {
        guard pendingUnlockIDs.isEmpty else { return }

        let deficit = poolCapacity - pool.count
        guard deficit > 0 else { return }
        let quota = (deficit == 1) ? 1 : 2

        var inPool   = Set(pool)
        var stagedIDs: [String] = []

        for _ in 0..<quota {
            let candidates = mainSentences.filter {
                !inPool.contains($0.id)
                && !archivedIDs.contains($0.id)
                && !feedbackDeletedIDs.contains($0.id)
                && !soldIDs.contains($0.id)
            }
            guard let picked = candidates.randomElement() else { break }

            for id in expandTagGroup(for: picked) where !inPool.contains(id) {
                inPool.insert(id)
                stagedIDs.append(id)
            }
        }

        guard !stagedIDs.isEmpty else { return }
        pendingUnlockIDs = stagedIDs
        savePendingUnlock()
        print("[\(config.id)] staged \(stagedIDs.count) sentence(s) for unlock notice")
    }

    /// User dismissed the unlock notice — commit staged sentences into the pool
    /// and immediately queue them as the next sentences on the main track,
    /// preserving stage order. If the user is in an example/voice-branch playlist,
    /// just commit silently without disrupting that flow.
    func commitPendingUnlock() {
        guard !pendingUnlockIDs.isEmpty else { return }
        let unlocked = pendingUnlockIDs
        pool.append(contentsOf: unlocked)
        savePool()
        pendingUnlockIDs.removeAll()
        savePendingUnlock()
        print("[\(config.id)] committed \(unlocked.count) unlocked sentence(s) → pool: \(pool.count)/\(poolCapacity)")

        guard examplePlaylist == nil else { return }

        // Splice unlocked IDs right after the current playlist position.
        let insertAt = max(0, min(mainPlaylistIndex + 1, mainPlaylist.count))
        let head = Array(mainPlaylist[..<insertAt])
        let tail = Array(mainPlaylist[insertAt...])
        mainPlaylist = head + unlocked + tail

        narration.stop(); chineseNarration.stop(); playsOnCurrent = 0
        pickNextMainSentence()
    }

    /// Resolved sentence objects for the pending unlock notice (preserves stage order).
    var pendingUnlockSentences: [LessonSentence] {
        let byID = Dictionary(uniqueKeysWithValues: mainSentences.map { ($0.id, $0) })
        return pendingUnlockIDs.compactMap { byID[$0] }
    }

    /// If `sentence` carries an indexed (ordered content) tag, return all sentences
    /// in that tag group sorted by `tag.index`, excluding archived/feedback-deleted.
    /// Otherwise returns just the input sentence's ID.
    private func expandTagGroup(for sentence: LessonSentence) -> [String] {
        guard let indexedTag = sentence.tags.first(where: { $0.index != nil }) else {
            return [sentence.id]
        }
        return mainSentences
            .filter { s in
                s.tags.contains { $0.name == indexedTag.name && $0.index != nil }
                && !archivedIDs.contains(s.id)
                && !feedbackDeletedIDs.contains(s.id)
            }
            .sorted { a, b in
                let ai = a.tags.first(where: { $0.name == indexedTag.name })?.index ?? Int.max
                let bi = b.tags.first(where: { $0.name == indexedTag.name })?.index ?? Int.max
                return ai < bi
            }
            .map(\.id)
    }

    /// Seed the pool with up to 100 random A1 sentences (excluding already-archived
    /// or feedback-deleted) on first run. Idempotent across launches; pool growth
    /// after this happens via archive deficit-unlock (see Step 3).
    private func seedPoolIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: poolInitializedKey) else { return }
        let candidates = mainSentences.filter {
            $0.cefr == "A1"
            && !archivedIDs.contains($0.id)
            && !feedbackDeletedIDs.contains($0.id)
        }
        let seeded = Array(candidates.shuffled().prefix(100)).map(\.id)
        pool = seeded
        savePool()
        UserDefaults.standard.set(true, forKey: poolInitializedKey)
        print("[\(config.id)] pool seeded with \(pool.count) A1 sentences")
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
    private func saveFeedbackMarked() {
        UserDefaults.standard.set(Array(feedbackMarkedIDs), forKey: feedbackMarkedStorageKey)
    }
    private func loadFeedbackMarked() {
        if let arr = UserDefaults.standard.stringArray(forKey: feedbackMarkedStorageKey) {
            feedbackMarkedIDs = Set(arr)
        }
    }
    private func saveFeedbackDeleted() {
        UserDefaults.standard.set(Array(feedbackDeletedIDs), forKey: feedbackDeletedStorageKey)
    }
    private func loadFeedbackDeleted() {
        if let arr = UserDefaults.standard.stringArray(forKey: feedbackDeletedStorageKey) {
            feedbackDeletedIDs = Set(arr)
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
