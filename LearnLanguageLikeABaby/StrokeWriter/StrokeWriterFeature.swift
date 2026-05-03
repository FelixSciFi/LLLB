import Foundation
import SwiftUI

/// Single seam between the stroke-writer feature and the rest of the app.
///
/// To remove the feature: delete `StrokeWriter/`, drop the `writeMode` field
/// in LessonSessionModel, and remove the two call sites in ContentView
/// (right-column toggle, in-chip render). Nothing else in the app touches
/// stroke-writer code.
enum StrokeWriterFeature {

    /// Master kill switch. Set to false to compile out the feature without
    /// touching call sites — they'll evaluate to no-ops.
    static let isEnabled = true

    /// Eligibility for showing the **enabled** Write button or rendering
    /// strokes. Returns true only if every gating rule is met:
    /// - Chinese learning mode
    /// - Single-token sentence
    /// - 1..4 Chinese chars
    /// - Every char is in the 3000-char data pack
    static func canRender(text rawText: String, tokenCount: Int, isChinese: Bool) -> Bool {
        guard isEnabled, isChinese, tokenCount == 1 else { return false }
        let chars = Array(rawText.trimmingCharacters(in: .whitespaces))
        guard !chars.isEmpty, chars.count <= 4 else { return false }
        for c in chars where !HanziStrokeData.shared.contains(c) {
            return false
        }
        return true
    }

    /// Whether the Write button should appear at all (zh learning mode).
    /// Disabled vs enabled is decided separately via `canRender`.
    static func shouldShowButton(isChinese: Bool) -> Bool {
        isEnabled && isChinese
    }

    /// Pick a timing mode given current playback parameters. Caller passes
    /// what they know; this function encapsulates the estimation formula.
    /// Returns nil if the feature is off — caller should not render.
    ///
    /// - Parameters:
    ///   - text: the token text (used for char count)
    ///   - tokenCount: number of tokens in the sentence (used for gap math)
    ///   - repeats: total chunked repeats configured (e.g. 3)
    ///   - hasTranslation: whether translation playback is enabled
    ///   - translationCharCount: number of chars in the translation if read
    ///   - speedMultiplier: global speed knob
    ///   - isSingleLoopMode: app-level loop mode (decoupled animation)
    static func mode(
        text: String,
        tokenCount: Int,
        repeats: Int,
        hasTranslation: Bool,
        translationCharCount: Int,
        speedMultiplier: Double,
        isSingleLoopMode: Bool
    ) -> HanziStrokeView.Mode {
        let speed = max(0.1, speedMultiplier)

        if isSingleLoopMode {
            return .natural(strokeSeconds: 0.25 / speed)
        }

        // Per-char read time estimate; tuned against fr-FR baseline timings
        // and adjusted later if the animation visibly drifts off audio.
        let perCharSeconds = 0.45
        let interTokenSeconds = 1.3
        let chineseChars = text.unicodeScalars.count
        let singlePass = Double(chineseChars) * perCharSeconds
                        + Double(max(0, tokenCount - 1)) * interTokenSeconds
        let lastPass = singlePass * 0.85
        let translation = hasTranslation
            ? Double(translationCharCount) * 0.40
            : 0
        let totalRepeats = max(1, repeats)
        let total = (singlePass * Double(totalRepeats - 1) + lastPass + translation) / speed
        return .paced(seconds: max(1.5, total))
    }
}
