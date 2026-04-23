import AVFoundation
import Foundation
import UIKit

/// Utterance tagged with the `speak()` session so `didFinish` ignores completions from a superseded `speak()` or `stop()`.
private final class ChunkUtterance: AVSpeechUtterance {
    let speakGen: Int

    init(string: String, speakGen: Int) {
        self.speakGen = speakGen
        super.init(string: string)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// Maps `AVSpeechSynthesizer` to token indices; speaks sentence as queued per-token utterances for clearer highlights.
final class NarrationEngine: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var highlightedTokenIndex: Int = 0
    @Published private(set) var isSpeaking: Bool = false

    /// Set while `speak(_: LessonSentence)` owns playback; cleared when idle. Avoids mismatched highlight index after `LessonSentence` changes before `speak` runs.
    private(set) var activeSentenceID: String?

    var rateMultiplier: Double = 1.0 {
        didSet { applyPendingRateToSynth() }
    }

    /// Silence gap between sentences in seconds. Set by LessonSessionModel.
    var interSentenceDelay: TimeInterval = 4.0

    /// BCP-47 locale for TTS (e.g. fr-FR, es-ES). Used as fallback when voiceIdentifier is nil.
    var language: String = "fr-FR"

    /// When true and the sentence has exactly one token, speak letters one-by-one before the full word.
    /// Checked per-call via spellFirst parameter in speak(); this flag is used by the session model.
    var spellEnabled: Bool = false

    private let synthesizer = AVSpeechSynthesizer()
    private var tokenRanges: [NSRange] = []
    private var activeFullText: String = ""

    /// Ignores `willSpeakRange` mapping when speaking one utterance per token.
    private var chunkHighlightMode = false
    private var chunkUtteranceTokenIndices: [Int] = []
    private var chunkDidStartCursor = 0
    private var pendingChunkFinishes = 0
    private var chunksFinished = 0
    private var speakGeneration = 0

    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?

    var onUtteranceFinished: (() -> Void)?
    var onInterrupted: (() -> Void)?
    var onInterruptionEnded: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self

        let session = AVAudioSession.sharedInstance()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioSessionInterruption(notification)
        }
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        if let routeChangeObserver {
            NotificationCenter.default.removeObserver(routeChangeObserver)
        }
    }

    func stop() {
        speakGeneration += 1
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        activeSentenceID = nil
        resetChunkTracking()
    }

    func speak(_ sentence: LessonSentence, spellFirst: Bool = false) {
        synthesizer.stopSpeaking(at: .immediate)
        speakGeneration += 1
        let generation = speakGeneration
        resetChunkTracking()

        activeSentenceID = sentence.id
        activeFullText = sentence.text
        tokenRanges = Self.rangesOfTokens(in: sentence.text, tokens: sentence.tokens)
        highlightedTokenIndex = 0

        let voice = resolveVoice()
        let rate = Self.utteranceRate(rateMultiplier: rateMultiplier)

        var toSpeak: [(tokenIndex: Int, text: String)] = []
        for (i, token) in sentence.tokens.enumerated() {
            let t = token.text
            guard !t.isEmpty else { continue }
            let clean = Self.cleanTextForSpeech(t)
            guard !clean.isEmpty else { continue }
            toSpeak.append((i, clean))
        }

        guard !toSpeak.isEmpty else {
            isSpeaking = false
            activeSentenceID = nil
            DispatchQueue.main.async {
                guard generation == self.speakGeneration else { return }
                self.onUtteranceFinished?()
            }
            return
        }

        // Spell mode: prepend per-letter utterances when single token (index -1 = no highlight)
        var spellLetters: [String] = []
        let isSingleWord = sentence.text.split(separator: " ").count == 1
        if spellFirst && isSingleWord {
            spellLetters = toSpeak[0].text.lowercased().map {
                String($0).applyingTransform(.stripDiacritics, reverse: false) ?? String($0)
            }
            for (i, letter) in spellLetters.enumerated() {
                let u = ChunkUtterance(string: letter, speakGen: generation)
                u.voice = voice
                u.rate = rate
                u.preUtteranceDelay = i == 0 ? 0 : 0.15
                synthesizer.speak(u)
            }
        }

        chunkHighlightMode = true
        chunkUtteranceTokenIndices = spellLetters.map { _ in -1 } + toSpeak.map(\.tokenIndex)
        chunkDidStartCursor = 0
        pendingChunkFinishes = spellLetters.count + toSpeak.count
        chunksFinished = 0

        for (j, item) in toSpeak.enumerated() {
            let utterance = ChunkUtterance(string: item.text, speakGen: generation)
            utterance.voice = voice
            utterance.rate = rate
            if j == 0 && !spellLetters.isEmpty {
                utterance.preUtteranceDelay = 0.45
            } else if j > 0 {
                utterance.preUtteranceDelay = 1.3
            }
            synthesizer.speak(utterance)
        }

        isSpeaking = true
    }

    func speakText(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        speakGeneration += 1
        let generation = speakGeneration
        activeSentenceID = nil
        resetChunkTracking()
        let utterance = ChunkUtterance(string: text, speakGen: generation)
        utterance.voice = resolveVoice()
        utterance.rate = Self.utteranceRate(rateMultiplier: rateMultiplier)
        pendingChunkFinishes = 1
        chunksFinished = 0
        chunkHighlightMode = false
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    /// Speaks the full sentence as a single utterance (no inter-token gaps).
    /// Token highlights are driven by willSpeakRange rather than the chunk cursor.
    /// Used for the final repeat so the sentence flows naturally after chunked practice.
    func speakConnected(_ sentence: LessonSentence) {
        synthesizer.stopSpeaking(at: .immediate)
        speakGeneration += 1
        let generation = speakGeneration
        resetChunkTracking()

        activeSentenceID = sentence.id
        activeFullText   = sentence.text
        tokenRanges      = Self.rangesOfTokens(in: sentence.text, tokens: sentence.tokens)
        highlightedTokenIndex = 0

        let utterance    = ChunkUtterance(string: sentence.text, speakGen: generation)
        utterance.voice  = resolveVoice()
        utterance.rate   = Self.utteranceRate(rateMultiplier: rateMultiplier)

        // chunkHighlightMode = false → willSpeakRange drives highlights
        pendingChunkFinishes = 1
        chunksFinished       = 0

        synthesizer.speak(utterance)
        isSpeaking = true
    }

    /// Same formula as `speak()` / `speakText()`: 0.75 × default rate, scaled and clamped to platform bounds.
    private static func utteranceRate(rateMultiplier: Double) -> Float {
        let base = Double(AVSpeechUtteranceDefaultSpeechRate) * 0.75
        let scaled = base * rateMultiplier
        let rate = Float(min(max(scaled, Double(AVSpeechUtteranceMinimumSpeechRate)), Double(AVSpeechUtteranceMaximumSpeechRate)))
        return rate
    }

    /// Strips punctuation for TTS only; UI still uses raw `token.text` from JSON.
    private static func cleanTextForSpeech(_ text: String) -> String {
        text
            .replacingOccurrences(of: "[,\\.!?;:\"«»()\\-]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private func resetChunkTracking() {
        chunkHighlightMode = false
        chunkUtteranceTokenIndices = []
        chunkDidStartCursor = 0
        pendingChunkFinishes = 0
        chunksFinished = 0
    }

    private func applyPendingRateToSynth() {
        // Rate is applied on next `speak()`; mid-utterance unchanged.
    }

    /// Resolves the voice to use: checks the global per-language dict in UserDefaults first,
    /// then falls back to the system default for `language`.
    private func resolveVoice() -> AVSpeechSynthesisVoice? {
        let langCode = String(language.prefix(2))
        if let dict = UserDefaults.standard.dictionary(forKey: "voiceByLanguage") as? [String: String],
           let id = dict[langCode],
           let voice = AVSpeechSynthesisVoice(identifier: id) {
            return voice
        }
        return AVSpeechSynthesisVoice(language: language)
    }

    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }
        switch type {
        case .began:
            speakGeneration += 1
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            activeSentenceID = nil
            resetChunkTracking()
            onInterrupted?()
        case .ended:
            let opts = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: opts).contains(.shouldResume)
            guard shouldResume else { break }
            try? AVAudioSession.sharedInstance().setActive(true)
            onInterruptionEnded?()
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
              reason == .oldDeviceUnavailable
        else { return }
        speakGeneration += 1
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        activeSentenceID = nil
        resetChunkTracking()
    }

    static func rangesOfTokens(in fullText: String, tokens: [TokenChunk]) -> [NSRange] {
        let ns = fullText as NSString
        var ranges: [NSRange] = []
        var searchLoc = 0
        for token in tokens {
            let t = token.text
            let len = max(0, ns.length - searchLoc)
            guard len > 0 else {
                ranges.append(NSRange(location: NSNotFound, length: 0))
                continue
            }
            let r = ns.range(of: t, options: [], range: NSRange(location: searchLoc, length: len))
            if r.location != NSNotFound {
                ranges.append(r)
                searchLoc = r.location + r.length
            } else {
                ranges.append(NSRange(location: NSNotFound, length: 0))
            }
        }
        return ranges
    }

    private func tokenIndex(forSpeakRange range: NSRange) -> Int {
        guard !tokenRanges.isEmpty else { return 0 }
        for (i, tr) in tokenRanges.enumerated() where tr.location != NSNotFound {
            let a = range.location
            let b = a + range.length
            let ta = tr.location
            let tb = ta + tr.length
            if a < tb && b > ta { return i }
        }
        for (i, tr) in tokenRanges.enumerated() where tr.location != NSNotFound {
            let ta = tr.location
            let tb = ta + tr.length
            let a = range.location
            if a >= ta && a < tb { return i }
        }
        return min(highlightedTokenIndex, max(0, tokenRanges.count - 1))
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard chunkHighlightMode, chunkDidStartCursor < chunkUtteranceTokenIndices.count else { return }
        let idx = chunkUtteranceTokenIndices[chunkDidStartCursor]
        chunkDidStartCursor += 1
        guard idx >= 0 else { return }  // -1: spell letter, skip highlight update
        DispatchQueue.main.async {
            self.highlightedTokenIndex = idx
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        guard !chunkHighlightMode else { return }
        let idx = tokenIndex(forSpeakRange: characterRange)
        DispatchQueue.main.async {
            if self.highlightedTokenIndex != idx {
                self.highlightedTokenIndex = idx
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let gen = (utterance as? ChunkUtterance)?.speakGen ?? speakGeneration
        DispatchQueue.main.async {
            guard gen == self.speakGeneration else { return }
            guard self.pendingChunkFinishes > 0 else { return }
            self.chunksFinished += 1
            guard self.chunksFinished >= self.pendingChunkFinishes else { return }

            let finish: () -> Void = {
                guard gen == self.speakGeneration else { return }
                self.isSpeaking = false
                self.resetChunkTracking()
                self.onUtteranceFinished?()
            }

            // Request background execution time so iOS doesn't suspend during the
            // inter-sentence silence gap. Without this, asyncAfter may never fire
            // when the app is backgrounded mid-gap.
            let bgTask = UIApplication.shared.beginBackgroundTask(withName: "LLLB.sentenceGap") {}
            DispatchQueue.main.asyncAfter(deadline: .now() + self.interSentenceDelay) {
                finish()
                UIApplication.shared.endBackgroundTask(bgTask)
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let gen = speakGeneration
        DispatchQueue.main.async {
            guard gen == self.speakGeneration else { return }
            self.isSpeaking = false
            self.resetChunkTracking()
            // 不在此处调用 onUtteranceFinished：stop() 等主动打断不应触发下一句，避免与录音争用 AudioSession。
        }
    }
}
