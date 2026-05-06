import Foundation
import Combine

/// A rescue offer the UI can show: price + streak count being saved + how
/// many rescues are still available this month.
struct StreakRescueOffer: Equatable {
    let price: Int
    let streakDays: Int
    let monthlyRemaining: Int
}

/// Pay candy to recover a missed day so the consecutive count keeps going.
///
/// **Window**: only the immediately-prior day is recoverable. If the user
/// missed two or more days, the streak is gone — `currentOffer(...)` returns
/// nil. Once today's session crosses the 5-min threshold, `UsageTimeTracker`
/// will call `updateStreak()` and reset the count to 1; the rescue window
/// closes at that moment too.
///
/// **Pricing tiers** (current streak length → candy cost):
///   1–6 days: 5  /  7–29: 10  /  30+: 20
///
/// **Monthly cap**: 2 rescues / calendar month. KVS-synced to keep usage
/// consistent across devices.
///
/// This store decides "is rescue possible?" and "what does it cost?", and
/// performs the candy debit + cap bookkeeping. The actual streak rewrite
/// (set streakLastDate to yesterday) is delegated to UsageTimeTracker so the
/// streak source-of-truth stays in one place.
@MainActor
final class StreakRescueStore: ObservableObject {

    // MARK: - Pricing

    static func priceForStreak(_ days: Int) -> Int {
        switch days {
        case ...0:    return 5    // shouldn't happen but keep a sane default
        case 1...6:   return 5
        case 7...29:  return 10
        default:      return 20
        }
    }

    // MARK: - Monthly cap

    static let monthlyLimit = 2

    private static let monthKey      = "streak_rescue_month_v1"
    private static let monthCountKey = "streak_rescue_month_count_v1"

    var monthlyUsed: Int {
        let defaults = UserDefaults.standard
        let stored = defaults.string(forKey: Self.monthKey) ?? ""
        guard stored == Self.currentMonthString() else { return 0 }
        return defaults.integer(forKey: Self.monthCountKey)
    }

    var monthlyRemaining: Int { max(0, Self.monthlyLimit - monthlyUsed) }

    // MARK: - Auto-prompt-once-a-day flag

    private static let promptShownKey = "streak_rescue_prompt_shown_for_v1"

    /// Caller (ContentView) checks this to decide whether to auto-show the
    /// rescue sheet on launch. Manual taps on the streak label ignore it.
    func hasShownAutoPromptToday(today: Date = Date()) -> Bool {
        UserDefaults.standard.string(forKey: Self.promptShownKey) == Self.dayString(today)
    }

    func markAutoPromptShown(today: Date = Date()) {
        UserDefaults.standard.set(Self.dayString(today), forKey: Self.promptShownKey)
    }

    // MARK: - Window detection

    /// Returns a non-nil offer iff:
    ///   - we have a real prior streak (`streakDays > 0` and `streakLastDateKey` non-empty)
    ///   - the last streak date is exactly the day-before-yesterday (i.e. one
    ///     full day was missed but not two)
    ///   - monthly cap has at least one rescue left
    func currentOffer(streakLastDateKey: String,
                      streakDays: Int,
                      today: Date = Date()) -> StreakRescueOffer? {
        guard streakDays > 0,
              !streakLastDateKey.isEmpty,
              monthlyRemaining > 0 else { return nil }

        let cal = Calendar.current
        let fmt = Self.dayFormatter
        guard let lastDate = fmt.date(from: streakLastDateKey) else { return nil }

        // last == today / yesterday → no rescue needed; older than dayBefore → too late.
        guard let dayBefore = cal.date(byAdding: .day, value: -2, to: today) else { return nil }
        guard cal.isDate(lastDate, inSameDayAs: dayBefore) else { return nil }

        return StreakRescueOffer(
            price:            Self.priceForStreak(streakDays),
            streakDays:       streakDays,
            monthlyRemaining: monthlyRemaining
        )
    }

    // MARK: - Spend

    enum RescueResult {
        case success
        case insufficientCandy
        case quotaExceeded
    }

    /// Atomically: charge the user `price` candy, bump the monthly counter.
    ///
    /// The caller (the rescue sheet) is responsible for verifying the offer
    /// via `currentOffer(...)` first AND for calling `usageTracker.applyRescue()`
    /// on success — this method only handles the money side.
    @discardableResult
    func performDebit(price: Int,
                      candyStore: CandyStore,
                      today: Date = Date()) -> RescueResult {
        guard monthlyRemaining > 0 else { return .quotaExceeded }
        guard candyStore.spendCandy(price) else { return .insufficientCandy }
        bumpMonth(today: today)
        objectWillChange.send()   // monthlyUsed changed
        return .success
    }

    private func bumpMonth(today: Date) {
        let defaults = UserDefaults.standard
        let prev = monthlyUsed
        defaults.set(Self.currentMonthString(today), forKey: Self.monthKey)
        defaults.set(prev + 1,                       forKey: Self.monthCountKey)
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

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale   = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM"
        return f
    }()

    private static func dayString(_ date: Date) -> String   { dayFormatter.string(from: date) }
    private static func currentMonthString(_ date: Date = Date()) -> String {
        monthFormatter.string(from: date)
    }
}
