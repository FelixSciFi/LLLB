import AppIntents
import Foundation

private func postDarwinNotification(name: String) {
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFNotificationName(name as CFString),
        nil,
        nil,
        true
    )
}

struct PlayPauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Play/Pause"

    func perform() async throws -> some IntentResult {
        postDarwinNotification(name: "com.learn.LLLB.playpause")
        return .result()
    }
}

struct PreviousIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Previous"

    func perform() async throws -> some IntentResult {
        postDarwinNotification(name: "com.learn.LLLB.previous")
        return .result()
    }
}

struct NextIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Next"

    func perform() async throws -> some IntentResult {
        postDarwinNotification(name: "com.learn.LLLB.next")
        return .result()
    }
}
