import Combine
import Foundation

/// Daily-resetting playback budget for free users. Subscribers (`isPremium`)
/// bypass the budget entirely.
///
/// Usage minutes are taken from `UsageTimeTracker` (foreground play +
/// background play, full weight — both count for the free quota). On top of
/// the free quota, users can spend candy or watch ads to add extra minutes
/// for the day; bought minutes do NOT carry over to the next day.
@MainActor
final class PlaybackBudget: ObservableObject {

    /// Free playback minutes per day for non-subscribers.
    static let freeBudgetMinutes: Int = 45

    /// Each candy / ad refill adds this many minutes.
    static let refillMinutes: Int = 10

    /// Cost in candy per refill.
    static let refillCandyCost: Int = 1

    /// Subscription state (stub — wire to StoreKit later).
    @Published var isPremium: Bool = false

    /// Bought minutes for today (resets at the next calendar day).
    @Published private(set) var boughtMinutesToday: Int = 0

    private let defaults = UserDefaults.standard
    private let keyBoughtByDay = "playback_bought_by_day_v1"
    private let keyIsPremium   = "playback_is_premium_dev_v1"

    /// Current YYYY-MM-DD in user's local time zone.
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale   = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func todayKey() -> String { dayFormatter.string(from: Date()) }

    init() {
        isPremium = defaults.bool(forKey: keyIsPremium)
        boughtMinutesToday = readBoughtMinutes(for: Self.todayKey())

        // Cross-midnight: when day rolls over, recompute bought (becomes 0 for new day).
        NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshDayIfNeeded() }
        }
    }

    // MARK: - Queries

    /// Total minutes the user can play today (free + bought).
    var dailyAllowance: Int {
        Self.freeBudgetMinutes + boughtMinutesToday
    }

    /// Remaining minutes (clamped ≥ 0). Premium users always see Int.max.
    func remaining(usedMinutes: Int) -> Int {
        if isPremium { return .max }
        return max(0, dailyAllowance - usedMinutes)
    }

    /// 0…1 fraction of the day's allowance still available.
    /// Premium users always get 1 (full cup).
    func progress(usedMinutes: Int) -> Double {
        if isPremium { return 1 }
        let rem = Double(remaining(usedMinutes: usedMinutes))
        let total = Double(dailyAllowance)
        guard total > 0 else { return 0 }
        return max(0, min(1, rem / total))
    }

    /// True when the budget is fully drained and we should soft-brake.
    func isExhausted(usedMinutes: Int) -> Bool {
        !isPremium && remaining(usedMinutes: usedMinutes) <= 0
    }

    // MARK: - Mutations

    /// Adds bought minutes to today's pot. Persists per-day so a fresh day
    /// starts at 0 automatically (yesterday's bought minutes are dropped).
    func addBoughtMinutes(_ amount: Int) {
        guard amount > 0 else { return }
        let key = Self.todayKey()
        let current = readBoughtMinutes(for: key)
        let next = current + amount
        writeBoughtMinutes(next, for: key)
        boughtMinutesToday = next
    }

    /// Toggle premium for development / testing. Wire to StoreKit when ready.
    func setPremium(_ value: Bool) {
        isPremium = value
        defaults.set(value, forKey: keyIsPremium)
    }

    // MARK: - Daily refresh

    private func refreshDayIfNeeded() {
        let fresh = readBoughtMinutes(for: Self.todayKey())
        if fresh != boughtMinutesToday {
            boughtMinutesToday = fresh
        }
    }

    // MARK: - Persistence helpers

    private func readBoughtMinutes(for day: String) -> Int {
        let dict = defaults.dictionary(forKey: keyBoughtByDay) as? [String: Int] ?? [:]
        return dict[day] ?? 0
    }

    private func writeBoughtMinutes(_ value: Int, for day: String) {
        var dict = defaults.dictionary(forKey: keyBoughtByDay) as? [String: Int] ?? [:]
        dict[day] = value
        // Garbage-collect entries older than 7 days so the dictionary doesn't grow unbounded.
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let cutoffKey = Self.dayFormatter.string(from: cutoff)
        dict = dict.filter { $0.key >= cutoffKey }
        defaults.set(dict, forKey: keyBoughtByDay)
    }
}
