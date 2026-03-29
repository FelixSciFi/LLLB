import Foundation

struct TokenChunk: Codable, Equatable {
    let text: String
    let lemma: String?
    let hasImage: Bool
    let emoji: String
    let ipa: String?
    let translation: String?

    enum CodingKeys: String, CodingKey {
        case text, lemma, hasImage, emoji, ipa, translation
    }

    init(text: String, lemma: String?, hasImage: Bool, emoji: String, ipa: String? = nil, translation: String? = nil) {
        self.text = text
        self.lemma = lemma
        self.hasImage = hasImage
        self.emoji = emoji
        self.ipa = ipa
        self.translation = translation
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(String.self, forKey: .text)
        lemma = try c.decodeIfPresent(String.self, forKey: .lemma)
        hasImage = try c.decode(Bool.self, forKey: .hasImage)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? ""
        ipa = try c.decodeIfPresent(String.self, forKey: .ipa)
        translation = try c.decodeIfPresent(String.self, forKey: .translation)
    }
}

struct LessonSentence: Codable, Equatable, Identifiable {
    let id: String
    let text: String
    let ipa: String
    let translation: String
    var tokens: [TokenChunk]
}

struct SentencesFile: Codable {
    let sentences: [LessonSentence]
}

struct ExampleBankFile: Codable {
    /// Key is lemma string (e.g. "pain", "vouloir").
    let examplesByLemma: [String: [LessonSentence]]

    enum CodingKeys: String, CodingKey {
        case examplesByLemma = "examples_by_lemma"
    }
}
