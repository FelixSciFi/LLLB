import Foundation

// MARK: - Language configuration

struct LanguageConfig: Identifiable, Equatable {
    let id: String                    // BCP-47 base code, e.g. "fr"
    let flag: String                  // emoji flag
    let displayNames: [String: String] // nativeLanguage → display name
    let ttsLocale: String             // AVSpeechSynthesizer locale, e.g. "fr-FR"
    let storeWelcome: String
    let storeSuccess: String
    let storeFail: String
    /// Difficulty levels for this language, ordered easiest → hardest.
    /// Names are arbitrary labels (CEFR A1..C2, HSK1..HSK6, JLPT N5..N1, or any
    /// custom system). The app treats them as a sequence; only position matters.
    let levelOrder: [String]
    /// Whether this language is content-complete enough to surface in the user-
    /// facing pickers. Sessions are still created for unreleased languages so
    /// that any persisted state survives — they're just hidden from the UI.
    /// Flip to true once sentences + word table + placement bank are ready.
    var released: Bool = true

    func displayName(for nativeLanguage: String) -> String {
        displayNames[nativeLanguage] ?? displayNames["en"] ?? id.uppercased()
    }
}

// MARK: - Static catalogues

extension LanguageConfig {

    /// Learning languages in commercial-market order.
    /// Adding a new language = one entry here + sentences_{id}.json + word_table_{id}.json.
    static let cefr = ["A1", "A2", "B1", "B2", "C1", "C2"]
    static let hsk  = ["HSK1", "HSK2", "HSK3", "HSK4", "HSK5", "HSK6"]

    static let learningLanguages: [LanguageConfig] = [
        .init(id: "en", flag: "🇺🇸",
              displayNames: ["zh": "英语", "en": "English"],
              ttsLocale: "en-US",
              storeWelcome: "Welcome!",
              storeSuccess: "Great choice!",
              storeFail: "Not enough candy...",
              levelOrder: cefr),
        .init(id: "es", flag: "🇪🇸",
              displayNames: ["zh": "西班牙语", "en": "Spanish"],
              ttsLocale: "es-ES",
              storeWelcome: "¡Bienvenido!",
              storeSuccess: "¡Excelente elección!",
              storeFail: "No tienes suficientes caramelos...",
              levelOrder: cefr,
              released: false),
        .init(id: "fr", flag: "🇫🇷",
              displayNames: ["zh": "法语", "en": "French"],
              ttsLocale: "fr-FR",
              storeWelcome: "Bienvenue !",
              storeSuccess: "Excellent choix !",
              storeFail: "Pas assez de candy...",
              levelOrder: cefr),
        .init(id: "ja", flag: "🇯🇵",
              displayNames: ["zh": "日语", "en": "Japanese"],
              ttsLocale: "ja-JP",
              storeWelcome: "いらっしゃいませ！",
              storeSuccess: "素晴らしい選択！",
              storeFail: "キャンディが足りません...",
              levelOrder: cefr,
              released: false),
        .init(id: "ko", flag: "🇰🇷",
              displayNames: ["zh": "韩语", "en": "Korean"],
              ttsLocale: "ko-KR",
              storeWelcome: "어서오세요!",
              storeSuccess: "훌륭한 선택!",
              storeFail: "캔디가 부족해요...",
              levelOrder: cefr,
              released: false),
        .init(id: "de", flag: "🇩🇪",
              displayNames: ["zh": "德语", "en": "German"],
              ttsLocale: "de-DE",
              storeWelcome: "Willkommen!",
              storeSuccess: "Ausgezeichnete Wahl!",
              storeFail: "Nicht genug Bonbons...",
              levelOrder: cefr,
              released: false),
        .init(id: "ar", flag: "🇸🇦",
              displayNames: ["zh": "阿拉伯语", "en": "Arabic"],
              ttsLocale: "ar-SA",
              storeWelcome: "أهلاً وسهلاً!",
              storeSuccess: "اختيار ممتاز!",
              storeFail: "ليس لديك حلوى كافية...",
              levelOrder: cefr,
              released: false),
        .init(id: "zh", flag: "🇨🇳",
              displayNames: ["zh": "普通话", "en": "Mandarin"],
              ttsLocale: "zh-CN",
              storeWelcome: "欢迎！",
              storeSuccess: "好眼力！",
              storeFail: "糖果不够了……",
              levelOrder: hsk),
    ]

    /// Subset of `learningLanguages` whose content is ready enough to show users.
    /// Sessions still exist for the rest (so any prior persisted state survives),
    /// but pickers should iterate this list rather than the full one.
    static var releasedLearningLanguages: [LanguageConfig] {
        learningLanguages.filter(\.released)
    }

    /// UI / interface languages (used in native-language picker).
    /// `levelOrder` is irrelevant here (not used as learning languages).
    static let uiLanguages: [LanguageConfig] = [
        .init(id: "zh", flag: "🇨🇳",
              displayNames: ["zh": "中文", "en": "Chinese"],
              ttsLocale: "zh-CN",
              storeWelcome: "", storeSuccess: "", storeFail: "",
              levelOrder: []),
        .init(id: "en", flag: "🇺🇸",
              displayNames: ["zh": "英语", "en": "English"],
              ttsLocale: "en-US",
              storeWelcome: "", storeSuccess: "", storeFail: "",
              levelOrder: []),
    ]
}
