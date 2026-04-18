import Foundation

func L(_ zh: String, _ en: String, nativeLanguage: String) -> String {
    nativeLanguage == "en" ? en : zh
}
