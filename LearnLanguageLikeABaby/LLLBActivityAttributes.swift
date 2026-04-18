import ActivityKit
import Foundation

struct LLLBActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var emoji: String
        var text: String
        var ipa: String
        var translation: String
        var isPlaying: Bool
        var showImage: Bool
        var showSpelling: Bool
        var showIPA: Bool
        var showTranslation: Bool
    }
}
