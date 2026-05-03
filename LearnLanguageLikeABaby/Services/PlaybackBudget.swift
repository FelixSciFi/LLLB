import Combine
import Foundation

/// Daily playback budget for free users. Premium subscribers bypass it entirely.
///
/// **Model**: a coffee cup with fixed capacity (45 min). The cup starts full
/// each day, drains as the user plays, and can be refilled (candy / ad) up
/// to capacity — never above. Refills near a full cup are blocked to prevent
/// candy waste.
///
/// `cupMinutes` is the only piece of state we need; everything else (refill
/// affordances, top-up cost) is derived from it. AppModel forwards the
/// usage tracker's playback-minute totals into `sync(playMinutes:)`, which
/// translates accumulated play time into cup drainage.
@MainActor
final class PlaybackBudget: ObservableObject {

    /// Cup capacity in minutes (per-day allowance).
    static let freeBudgetMinutes: Int = 45

    /// One refill unit (candy / ad) tops the cup up by this many minutes.
    static let refillMinutes: Int = 10

    /// Cost in candy of one single refill.
    static let refillCandyCost: Int = 1

    /// Minimum free space (in minutes) required to enable a single refill.
    /// Prevents wasting most of a `refillMinutes`-unit purchase near full.
    private static let strictRefillMinSpace: Int = refillMinutes

    /// Subscription state (StoreKit wiring stub).
    @Published var isPremium: Bool = false

    /// Current liquid in the cup, 0 ... freeBudgetMinutes.
    @Published private(set) var cupMinutes: Int

    private let defaults = UserDefaults.standard
    private let keyCupMinutes        = "cup_minutes_v2"
    private let keyLastSeenDay       = "cup_last_seen_day_v2"
    private let keyLastSeenPlayMin   = "cup_last_seen_play_v2"
    private let keyIsPremium         = "playback_is_premium_dev_v1"
    /// Legacy keys we proactively wipe on first launch of v2 — the previous
    /// model accumulated `bought` minutes which led to a "frozen" cup.
    private let legacyBoughtKey      = "playback_bought_by_day_v1"

    /// `todayMinutes + todayBgMinutes` value last seen by `sync()`. Used to
    /// compute the per-call delta to subtract from the cup.
    private var lastSeenPlayMinutes: Int

    /// The day key the cup is currently scoped to. When `sync()` notices a
    /// new day, the cup resets to full and the baseline is rebased.
    private var lastSeenDay: String

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
        let d = defaults

        // One-time migration — drop the v1 stockpile so users don't carry
        // over the now-broken accumulated `bought` minutes.
        if d.object(forKey: legacyBoughtKey) != nil {
            d.removeObject(forKey: legacyBoughtKey)
        }

        let today = Self.todayKey()
        let storedDay = d.string(forKey: keyLastSeenDay) ?? ""

        if storedDay == today {
            cupMinutes          = d.object(forKey: keyCupMinutes) as? Int ?? Self.freeBudgetMinutes
            lastSeenPlayMinutes = d.integer(forKey: keyLastSeenPlayMin)
            lastSeenDay         = today
        } else {
            // Fresh day (or first run) — full cup, baseline reset.
            cupMinutes          = Self.freeBudgetMinutes
            lastSeenPlayMinutes = 0
            lastSeenDay         = today
            persist()
        }

        isPremium = d.bool(forKey: keyIsPremium)

        // Catch midnight rollover even if the app stays open.
        NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleDayChange() }
        }
    }

    // MARK: - External sync

    /// Called by AppModel whenever usage tracker minute totals change.
    /// Translates accumulated play minutes into cup drainage.
    func sync(playMinutes: Int) {
        let today = Self.todayKey()

        if today != lastSeenDay {
            // Crossed midnight while running — reset cup, rebase the baseline
            // so today's already-elapsed minutes don't count against it.
            cupMinutes          = Self.freeBudgetMinutes
            lastSeenPlayMinutes = playMinutes
            lastSeenDay         = today
            persist()
            return
        }

        let delta = playMinutes - lastSeenPlayMinutes
        guard delta > 0 else { return }
        let drained = max(0, cupMinutes - delta)
        if drained != cupMinutes {
            cupMinutes = drained
        }
        lastSeenPlayMinutes = playMinutes
        persist()
    }

    private func handleDayChange() {
        // Clean midnight reset (sync() will rebase next time playMinutes arrives).
        cupMinutes  = Self.freeBudgetMinutes
        lastSeenDay = Self.todayKey()
        // lastSeenPlayMinutes stays — usage tracker also resets at midnight,
        // so the next sync delta will be correct.
        lastSeenPlayMinutes = 0
        persist()
    }

    // MARK: - Refill API

    /// Free space in the cup (minutes that could still be added).
    var freeSpaceMinutes: Int { Self.freeBudgetMinutes - cupMinutes }

    /// Strict mode: only allow a single refill if the full unit fits without waste.
    var canRefillSingle: Bool { freeSpaceMinutes >= Self.strictRefillMinSpace }

    /// Candy needed for a bulk top-up. Floors to whole candy units, so a 1-candy
    /// purchase always buys 10 min of cup space — never partial. When less than
    /// one full unit fits, the bulk button stays disabled (`canTopUp == false`).
    var topUpCost: Int { freeSpaceMinutes / Self.refillMinutes }

    /// True when the cup has space for at least one full bulk unit.
    var canTopUp: Bool { topUpCost >= 1 }

    /// Add a single refill (caller must have already spent the candy / shown the ad).
    func refillSingle() {
        guard canRefillSingle else { return }
        cupMinutes = min(Self.freeBudgetMinutes, cupMinutes + Self.refillMinutes)
        persist()
    }

    /// Bulk refill — adds `topUpCost * refillMinutes` minutes (always exact whole
    /// units, capped at capacity). Caller charges `topUpCost` candy.
    func topUpToFull() {
        let units = topUpCost
        guard units >= 1 else { return }
        let added = units * Self.refillMinutes
        cupMinutes = min(Self.freeBudgetMinutes, cupMinutes + added)
        persist()
    }

    // MARK: - Soft-brake gate

    /// Returns the current cup level — used by views and the soft-brake gate.
    func remaining() -> Int { isPremium ? .max : cupMinutes }

    func progress() -> Double {
        if isPremium { return 1 }
        return max(0, min(1, Double(cupMinutes) / Double(Self.freeBudgetMinutes)))
    }

    func isExhausted() -> Bool { !isPremium && cupMinutes <= 0 }

    // MARK: - Premium toggle (dev only for now)

    func setPremium(_ value: Bool) {
        isPremium = value
        defaults.set(value, forKey: keyIsPremium)
    }

    // MARK: - Persistence

    private func persist() {
        defaults.set(cupMinutes,           forKey: keyCupMinutes)
        defaults.set(lastSeenPlayMinutes,  forKey: keyLastSeenPlayMin)
        defaults.set(lastSeenDay,          forKey: keyLastSeenDay)
    }
}
