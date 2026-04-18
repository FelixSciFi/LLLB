import Combine
import Foundation

@MainActor
final class CandyStore: ObservableObject {
    @Published private(set) var candyBalance: Int
    /// Lemmas owned per learning language: ["fr": ["pain", ...], "es": [...]]
    @Published private(set) var ownedLemmasByLanguage: [String: Set<String>]
    /// Sentence IDs directly purchased per language
    @Published private(set) var ownedSentenceIDsByLanguage: [String: Set<String>]
    @Published private(set) var dailyFreeRemaining: Int

    private let defaults = UserDefaults.standard
    private let keyBalance            = "candy_balance"
    private let keyOwnedV3            = "owned_lemmas_v3"   // JSON-encoded [String:[String]]
    private let keyOwnedSentences     = "owned_sentences_v1" // JSON-encoded [String:[String]]
    private let keyInitializedV3      = "candy_initialized_v3"
    private let keyDailyFreeRemaining = "daily_free_remaining"
    private let keyDailyFreeDate      = "daily_free_date"
    private let keyBootstrapVersion   = "candy_bootstrap_version"
    /// Bump this when bootstrap defaults change; forces one-time re-init on existing installs.
    private static let currentBootstrapVersion = 5

    private let keyNativeLanguage       = "native_language"
    private let keyNativeLanguageLegacy = "nativeLanguage"

    @Published var nativeLanguage: String {
        didSet { defaults.set(nativeLanguage, forKey: keyNativeLanguage) }
    }

    // MARK: - Date helpers

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale   = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func todayDateString() -> String { dayFormatter.string(from: Date()) }

    // MARK: - Init

    init(initialLemmasByLanguage: [String: [String]]) {
        let storedLang = defaults.string(forKey: keyNativeLanguage)
            ?? defaults.string(forKey: keyNativeLanguageLegacy)
            ?? "zh"
        nativeLanguage = storedLang

        // Force re-init when bootstrap version bumps
        let v = defaults.integer(forKey: keyBootstrapVersion)
        if v < Self.currentBootstrapVersion {
            defaults.removeObject(forKey: keyInitializedV3)
            defaults.set(Self.currentBootstrapVersion, forKey: keyBootstrapVersion)
        }

        if defaults.object(forKey: keyInitializedV3) == nil {
            // Fresh install (or forced reset)
            candyBalance = 99999999
            ownedLemmasByLanguage = initialLemmasByLanguage.mapValues { Set($0) }
            ownedSentenceIDsByLanguage = [:]
            dailyFreeRemaining = 3
            defaults.set(3, forKey: keyDailyFreeRemaining)
            defaults.set(Self.todayDateString(), forKey: keyDailyFreeDate)
            persist()
            defaults.set(true, forKey: keyInitializedV3)
        } else {
            candyBalance = defaults.integer(forKey: keyBalance)
            if let data = defaults.data(forKey: keyOwnedV3),
               let dict = try? JSONDecoder().decode([String: [String]].self, from: data) {
                ownedLemmasByLanguage = dict.mapValues { Set($0) }
            } else {
                ownedLemmasByLanguage = initialLemmasByLanguage.mapValues { Set($0) }
            }
            if let data = defaults.data(forKey: keyOwnedSentences),
               let dict = try? JSONDecoder().decode([String: [String]].self, from: data) {
                ownedSentenceIDsByLanguage = dict.mapValues { Set($0) }
            } else {
                ownedSentenceIDsByLanguage = [:]
            }
            dailyFreeRemaining = (defaults.object(forKey: keyDailyFreeRemaining) as? Int) ?? 3
            refreshDailyFreeIfNeeded()
        }

        if defaults.string(forKey: keyNativeLanguage) == nil {
            defaults.set(storedLang, forKey: keyNativeLanguage)
        }
    }

    // MARK: - Public accessors

    func ownedLemmas(for language: String) -> Set<String> {
        ownedLemmasByLanguage[language] ?? []
    }

    func ownedSentenceIDs(for language: String) -> Set<String> {
        ownedSentenceIDsByLanguage[language] ?? []
    }

    @discardableResult
    func buySentence(_ id: String, language: String) -> Bool {
        if ownedSentenceIDsByLanguage[language, default: []].contains(id) { return true }
        guard candyBalance >= 10 else { return false }
        candyBalance -= 10
        ownedSentenceIDsByLanguage[language, default: []].insert(id)
        persist()
        return true
    }

    func addCandy(_ amount: Int) {
        candyBalance += amount
        persist()
    }

    func removeSentence(_ id: String, language: String) {
        ownedSentenceIDsByLanguage[language]?.remove(id)
        persist()
    }

    func refreshDailyFreeIfNeeded() {
        let today = Self.todayDateString()
        guard defaults.string(forKey: keyDailyFreeDate) != today else { return }
        dailyFreeRemaining = 3
        defaults.set(3, forKey: keyDailyFreeRemaining)
        defaults.set(today, forKey: keyDailyFreeDate)
    }

    @discardableResult
    func buyLemma(_ lemma: String, language: String, price: Int) -> Bool {
        refreshDailyFreeIfNeeded()
        if ownedLemmasByLanguage[language, default: []].contains(lemma) { return true }
        if dailyFreeRemaining > 0 {
            dailyFreeRemaining -= 1
            ownedLemmasByLanguage[language, default: []].insert(lemma)
            persist()
            return true
        }
        guard candyBalance >= price else { return false }
        candyBalance -= price
        ownedLemmasByLanguage[language, default: []].insert(lemma)
        persist()
        return true
    }

    func sellLemma(_ lemma: String, language: String, price: Int) {
        guard ownedLemmasByLanguage[language]?.remove(lemma) != nil else { return }
        candyBalance += Int(ceil(Double(price) * 0.8))
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        defaults.set(candyBalance, forKey: keyBalance)
        let lemmaDict = ownedLemmasByLanguage.mapValues { Array($0).sorted() }
        if let data = try? JSONEncoder().encode(lemmaDict) {
            defaults.set(data, forKey: keyOwnedV3)
        }
        let sentenceDict = ownedSentenceIDsByLanguage.mapValues { Array($0).sorted() }
        if let data = try? JSONEncoder().encode(sentenceDict) {
            defaults.set(data, forKey: keyOwnedSentences)
        }
        defaults.set(dailyFreeRemaining, forKey: keyDailyFreeRemaining)
    }
}
