import Foundation
import Combine

/// Tracks foreground ("active / 主动") and background ("passive / 被动") usage time separately.
/// Persists per-day seconds in UserDefaults.
/// Call beginSession() on foreground, endSession() on background (and vice-versa for Bg variants).
final class UsageTimeTracker: ObservableObject {

    // MARK: - Streak
    @Published private(set) var streakDays: Int = 0

    private static let streakCountKey    = "streakCount_v1"
    private static let streakLastDateKey = "streakLastDate_v1"

    private func updateStreak() {
        let today = Self.dayKey(for: Date())
        let last  = UserDefaults.standard.string(forKey: Self.streakLastDateKey) ?? ""
        if last == today { return }  // already recorded today

        let cal      = Calendar.current
        let fmt      = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let isConsec = last.isEmpty ? false : {
            guard let lastDate = fmt.date(from: last) else { return false }
            return cal.isDate(lastDate, inSameDayAs: cal.date(byAdding: .day, value: -1, to: Date())!)
        }()

        let current = UserDefaults.standard.integer(forKey: Self.streakCountKey)
        let next    = isConsec ? current + 1 : 1
        UserDefaults.standard.set(next,  forKey: Self.streakCountKey)
        UserDefaults.standard.set(today, forKey: Self.streakLastDateKey)
        streakDays = next
    }

    // MARK: - Foreground (主动)
    @Published private(set) var todayMinutes:      Int = 0
    @Published private(set) var thisWeekMinutes:   Int = 0
    @Published private(set) var thisMonthMinutes:  Int = 0
    @Published private(set) var allTimeMinutes:    Int = 0

    // MARK: - Background (被动)
    @Published private(set) var todayBgMinutes:    Int = 0
    @Published private(set) var thisWeekBgMinutes: Int = 0
    @Published private(set) var thisMonthBgMinutes:Int = 0
    @Published private(set) var allTimeBgMinutes:  Int = 0

    // Keep the original key so existing foreground data is preserved
    private static let fgStorageKey = "usageTimeByDate_v1"
    private static let bgStorageKey = "usageBgTimeByDate_v1"

    private var dailySeconds:   [String: Int] = [:]
    private var dailyBgSeconds: [String: Int] = [:]

    private var sessionStart:   Date?
    private var bgSessionStart: Date?

    private var flushTimer:   Timer?
    private var bgFlushTimer: Timer?

    init() {
        load()
        recompute()
        streakDays = UserDefaults.standard.integer(forKey: Self.streakCountKey)
    }

    // MARK: - Foreground session

    func beginSession() {
        guard sessionStart == nil else { return }
        updateStreak()
        sessionStart = Date()
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in self?.flush() }
        RunLoop.main.add(t, forMode: .common)
        flushTimer = t
    }

    func endSession() {
        flush()
        flushTimer?.invalidate()
        flushTimer   = nil
        sessionStart = nil
    }

    // MARK: - Background session

    func beginBgSession() {
        guard bgSessionStart == nil else { return }
        bgSessionStart = Date()
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in self?.flushBg() }
        RunLoop.main.add(t, forMode: .common)
        bgFlushTimer = t
    }

    func endBgSession() {
        flushBg()
        bgFlushTimer?.invalidate()
        bgFlushTimer   = nil
        bgSessionStart = nil
    }

    /// Call when the stats UI is about to appear to get up-to-date values.
    func refresh() { flush(); flushBg() }

    // MARK: - Private flush

    private func flush() {
        guard let start = sessionStart else { return }
        let now     = Date()
        let elapsed = Int(now.timeIntervalSince(start))
        guard elapsed > 0 else { return }
        dailySeconds[Self.dayKey(for: start), default: 0] += elapsed
        sessionStart = now
        save()
        recompute()
    }

    private func flushBg() {
        guard let start = bgSessionStart else { return }
        let now     = Date()
        let elapsed = Int(now.timeIntervalSince(start))
        guard elapsed > 0 else { return }
        dailyBgSeconds[Self.dayKey(for: start), default: 0] += elapsed
        bgSessionStart = now
        saveBg()
        recompute()
    }

    // MARK: - Recompute published values

    private func recompute() {
        let cal = Calendar.current
        let now = Date()

        todayMinutes    = secondsForDay(now, in: dailySeconds)   / 60
        todayBgMinutes  = secondsForDay(now, in: dailyBgSeconds) / 60

        if let wStart = cal.dateInterval(of: .weekOfYear, for: now)?.start {
            thisWeekMinutes   = secondsInRange(from: wStart, in: dailySeconds)   / 60
            thisWeekBgMinutes = secondsInRange(from: wStart, in: dailyBgSeconds) / 60
        }
        if let mStart = cal.dateInterval(of: .month, for: now)?.start {
            thisMonthMinutes   = secondsInRange(from: mStart, in: dailySeconds)   / 60
            thisMonthBgMinutes = secondsInRange(from: mStart, in: dailyBgSeconds) / 60
        }
        allTimeMinutes   = dailySeconds.values.reduce(0, +)   / 60
        allTimeBgMinutes = dailyBgSeconds.values.reduce(0, +) / 60
    }

    private func secondsForDay(_ date: Date, in dict: [String: Int]) -> Int {
        dict[Self.dayKey(for: date)] ?? 0
    }

    private func secondsInRange(from start: Date, in dict: [String: Int]) -> Int {
        let cal = Calendar.current
        var total = 0
        var d = start
        let end = Date()
        while d <= end {
            total += secondsForDay(d, in: dict)
            guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return total
    }

    private static func dayKey(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    private func save() {
        UserDefaults.standard.set(dailySeconds, forKey: Self.fgStorageKey)
    }
    private func saveBg() {
        UserDefaults.standard.set(dailyBgSeconds, forKey: Self.bgStorageKey)
    }
    private func load() {
        dailySeconds   = (UserDefaults.standard.dictionary(forKey: Self.fgStorageKey) as? [String: Int]) ?? [:]
        dailyBgSeconds = (UserDefaults.standard.dictionary(forKey: Self.bgStorageKey) as? [String: Int]) ?? [:]
    }
}
