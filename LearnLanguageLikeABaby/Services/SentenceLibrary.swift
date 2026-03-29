import Foundation

enum SentenceLibrary {
    static func loadMainSentences() throws -> [LessonSentence] {
        let url = try resourceURL("sentences")
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(SentencesFile.self, from: data)
        return decoded.sentences
    }

    static func loadExampleBank() throws -> [String: [LessonSentence]] {
        let url = try resourceURL("exampleSentences")
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(ExampleBankFile.self, from: data)
        return decoded.examplesByLemma
    }

    private static func resourceURL(_ name: String) throws -> URL {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw NSError(domain: "SentenceLibrary", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing \(name).json"])
        }
        return url
    }
}
