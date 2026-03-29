import Foundation
import NaturalLanguage

enum FrenchLemmaSearch {
    /// Returns lemma tags (lowercased) for each word unit in French text.
    static func lemmas(in phrase: String) -> [String] {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = trimmed
        let range = trimmed.startIndex..<trimmed.endIndex
        tagger.setLanguage(.french, range: range)
        var out: [String] = []
        tagger.enumerateTags(in: range, unit: .word, scheme: .lemma) { tag, _ in
            guard let raw = tag?.rawValue else { return true }
            let v = raw.lowercased()
            if v != "_" && !v.isEmpty { out.append(v) }
            return true
        }
        return out
    }

    /// Picks the first bank key that matches a lemma or an original lowercase token.
    static func lookupLemmaKey(for recognition: String, bankKeys: Set<String>) -> String? {
        let lower = recognition.lowercased()
        for raw in lower.split(whereSeparator: { $0.isWhitespace }) {
            let w = String(raw).trimmingCharacters(in: .punctuationCharacters)
            guard !w.isEmpty else { continue }
            if bankKeys.contains(w) { return w }
        }
        for lem in lemmas(in: lower) {
            if bankKeys.contains(lem) { return lem }
        }
        return nil
    }
}
