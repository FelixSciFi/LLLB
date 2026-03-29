import AVFoundation
import Foundation

/// Maps `AVSpeechSynthesizer` character ranges to token indices for a `LessonSentence`.
final class NarrationEngine: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var highlightedTokenIndex: Int = 0
    @Published private(set) var isSpeaking: Bool = false

    var rateMultiplier: Double = 1.0 {
        didSet { applyPendingRateToSynth() }
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var tokenRanges: [NSRange] = []
    private var activeFullText: String = ""

    var onUtteranceFinished: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    func speak(_ sentence: LessonSentence) {
        stop()
        activeFullText = sentence.text
        tokenRanges = Self.rangesOfTokens(in: sentence.text, tokens: sentence.tokens)
        highlightedTokenIndex = 0

        let utterance = AVSpeechUtterance(string: sentence.text)
        utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR")
        let base = Double(AVSpeechUtteranceDefaultSpeechRate)
        let scaled = base * rateMultiplier
        let clamped = min(max(scaled, Double(AVSpeechUtteranceMinimumSpeechRate)), Double(AVSpeechUtteranceMaximumSpeechRate))
        utterance.rate = Float(clamped)

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    private func applyPendingRateToSynth() {
        // Rate is applied on next utterance; if mid-speech, optional restart — skip for simplicity.
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

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let idx = tokenIndex(forSpeakRange: characterRange)
        DispatchQueue.main.async {
            if self.highlightedTokenIndex != idx {
                self.highlightedTokenIndex = idx
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.onUtteranceFinished?()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.onUtteranceFinished?()
        }
    }
}
