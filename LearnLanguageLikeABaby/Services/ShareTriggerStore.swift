import Foundation
import Combine

/// What kind of event prompted us to ask the user to share.
/// Encoded as a stable string id so seen-flags survive across app versions.
enum ShareTrigger: Hashable {
    case streakMilestone(days: Int)

    /// Stable ID used for the seen-flag UserDefaults key.
    var id: String {
        switch self {
        case .streakMilestone(let n): return "streak_\(n)"
        }
    }
}

/// Generic "you should ask the user to share now" coordinator.
///
/// Trigger sources call `observeStreak(_:)` (or future `observe…` methods) when a
/// notable event happens. The store decides whether it's a milestone, whether
/// it's already been shown before, and exposes a single `pending` slot for the
/// UI to drain — only one share prompt at a time.
///
/// Reward bookkeeping is shared across all triggers: daily / monthly caps live
/// here, so adding a new trigger source later doesn't fork the quota logic.
final class ShareTriggerStore: ObservableObject {

    // MARK: - Pending prompt

    /// One slot. UI reads this and presents a sheet; user dismisses → cleared.
    @Published private(set) var pending: ShareTrigger?

    // MARK: - Streak milestones

    /// Hard-coded early milestones; after 100 we step every 50.
    private static let streakBaseMilestones: Set<Int> = [10, 20, 50, 100]

    static func isStreakMilestone(_ days: Int) -> Bool {
        if streakBaseMilestones.contains(days) { return true }
        return days > 100 && days % 50 == 0
    }

    /// Called when the streak counter changes. No-op unless `days` is a milestone
    /// AND we haven't already shown this exact milestone before.
    func observeStreak(_ days: Int) {
        guard Self.isStreakMilestone(days) else { return }
        let trigger = ShareTrigger.streakMilestone(days: days)
        guard !hasSeen(trigger) else { return }
        guard pending == nil else { return }   // don't clobber an existing prompt
        pending = trigger
    }

    // MARK: - Seen tracking

    /// User shared OR dismissed the sheet — either way we don't ask again for
    /// this exact trigger.
    func dismiss(_ trigger: ShareTrigger) {
        markSeen(trigger)
        if pending == trigger { pending = nil }
    }

    func hasSeen(_ trigger: ShareTrigger) -> Bool {
        UserDefaults.standard.bool(forKey: seenKey(trigger))
    }

    private func markSeen(_ trigger: ShareTrigger) {
        UserDefaults.standard.set(true, forKey: seenKey(trigger))
    }

    private func seenKey(_ trigger: ShareTrigger) -> String {
        "shareTriggerSeen_\(trigger.id)_v1"
    }

    // MARK: - Reward (shared across all triggers)

    static let rewardPerShare = 2
    static let dailyLimit     = 1
    static let monthlyLimit   = 5

    private static let rewardLastDateKey   = "share_reward_last_date_v1"
    private static let rewardMonthKey      = "share_reward_month_v1"
    private static let rewardMonthCountKey = "share_reward_month_count_v1"

    /// True if a successful share right now is eligible for a candy reward.
    func canRewardNow(date: Date = Date()) -> Bool {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: Self.rewardLastDateKey) == Self.dayKey(date) {
            return false
        }
        return monthCount(at: date) < Self.monthlyLimit
    }

    /// Mark a successful share. Returns the candy amount the caller should
    /// credit — 0 if quota was already exhausted (caller should still dismiss
    /// the trigger).
    @discardableResult
    func grantRewardForSuccessfulShare(date: Date = Date()) -> Int {
        guard canRewardNow(date: date) else { return 0 }
        let defaults = UserDefaults.standard
        let prev = monthCount(at: date)
        defaults.set(Self.dayKey(date),   forKey: Self.rewardLastDateKey)
        defaults.set(Self.monthKey(date), forKey: Self.rewardMonthKey)
        defaults.set(prev + 1,            forKey: Self.rewardMonthCountKey)
        return Self.rewardPerShare
    }

    private func monthCount(at date: Date) -> Int {
        let defaults = UserDefaults.standard
        let stored = defaults.string(forKey: Self.rewardMonthKey) ?? ""
        guard stored == Self.monthKey(date) else { return 0 }
        return defaults.integer(forKey: Self.rewardMonthCountKey)
    }

    // MARK: - Date helpers

    private static func dayKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func monthKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"
        return f.string(from: date)
    }
}
