import Foundation

extension Dictionary where Key == String, Value == String {
    func resolvedTranslation(nativeLanguage: String) -> String {
        self[nativeLanguage] ?? self["zh"] ?? ""
    }
}

extension Optional where Wrapped == [String: String] {
    func resolvedTranslation(nativeLanguage: String) -> String {
        switch self {
        case .none:
            return ""
        case .some(let dict):
            return dict.resolvedTranslation(nativeLanguage: nativeLanguage)
        }
    }
}

struct TokenChunk: Codable, Equatable {
    let text: String
    let lemma: String?
    let emoji: String
    let ipa: String?
    let translation: [String: String]?
}

struct SentenceTag: Codable, Equatable, Hashable {
    let name: String
    let index: Int?   // nil = random tag; non-nil = ordered content tag (1-based position)
}

struct LessonSentence: Codable, Equatable, Identifiable {
    let id: String
    let text: String
    let ipa: String
    let translation: [String: String]
    let cefr: String
    let rank: Int
    let tokens: [TokenChunk]
    let tags: [SentenceTag]

    enum CodingKeys: String, CodingKey {
        case id, text, ipa, translation, tokens, cefr, rank, library, tags
    }

    init(id: String, text: String, ipa: String, translation: [String: String], cefr: String, rank: Int, tokens: [TokenChunk], tags: [SentenceTag] = []) {
        self.id = id
        self.text = text
        self.ipa = ipa
        self.translation = translation
        self.cefr = cefr
        self.rank = rank
        self.tokens = tokens
        self.tags = tags
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        ipa = try c.decodeIfPresent(String.self, forKey: .ipa) ?? ""
        translation = try c.decodeIfPresent([String: String].self, forKey: .translation) ?? [:]
        tokens = try c.decode([TokenChunk].self, forKey: .tokens)

        if let ce = try c.decodeIfPresent(String.self, forKey: .cefr) {
            cefr = ce
        } else if let lib = try c.decodeIfPresent(String.self, forKey: .library) {
            cefr = (lib == "A1-CDI") ? "A1" : lib
        } else {
            cefr = "A2"
        }

        rank = try c.decodeIfPresent(Int.self, forKey: .rank) ?? 999
        tags = try c.decodeIfPresent([SentenceTag].self, forKey: .tags) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(text, forKey: .text)
        try c.encode(ipa, forKey: .ipa)
        try c.encode(translation, forKey: .translation)
        try c.encode(tokens, forKey: .tokens)
        try c.encode(cefr, forKey: .cefr)
        try c.encode(rank, forKey: .rank)
        if !tags.isEmpty { try c.encode(tags, forKey: .tags) }
    }
}

struct SentencesFile: Codable {
    let sentences: [LessonSentence]
}

struct WordEntry: Codable {
    let rank: Int
    let lemma: String
    let translation: [String: String]
    let emoji: String
    let cefr: String
    let ipa: String?
}

struct WordTable: Codable {
    let words: [WordEntry]
}

struct ExampleBankFile: Codable {
    /// Key is lemma string (e.g. "pain", "vouloir").
    let examplesByLemma: [String: [LessonSentence]]

    enum CodingKeys: String, CodingKey {
        case examplesByLemma = "examples_by_lemma"
    }
}
