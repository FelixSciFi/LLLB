import Foundation

enum SentenceLibrary {
    static func loadMainSentences(language: String) throws -> [LessonSentence] {
        let url = try resourceURL("sentences_\(language)")
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(SentencesFile.self, from: data)
        return decoded.sentences
    }

    static func loadExampleBank(language: String) throws -> [String: [LessonSentence]] {
        let url = try resourceURL("exampleSentences_\(language)")
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(ExampleBankFile.self, from: data)
        return decoded.examplesByLemma
    }

    static func loadWordTable(language: String) throws -> [WordEntry] {
        let url = try resourceURL("word_table_\(language)")
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(WordTable.self, from: data)
        return decoded.words
    }

    private static func resourceURL(_ name: String) throws -> URL {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw NSError(domain: "SentenceLibrary", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing \(name).json"])
        }
        return url
    }
}
