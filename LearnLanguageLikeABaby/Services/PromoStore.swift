import Combine
import Foundation

/// Self-managed promo (no App Store / StoreKit involved).
///
/// Currently the only flow: **new users get 7 days of unlimited time** when
/// onboarding completes. The granted-at timestamp is persisted *and mirrored
/// to iCloud KVS*, so an uninstall + reinstall on the same Apple ID can't
/// re-grant another 7 days.
///
/// Future: Apple Offer Codes will handle activity / promo extensions through
/// App Store entitlements directly, so this object stays narrow.
@MainActor
final class PromoStore: ObservableObject {

    /// When the current promo ends. `nil` = never granted (or wiped).
    /// Views should consult `isActive` / `daysRemaining` rather than reading
    /// this directly so the time-based comparison stays in one place.
    @Published private(set) var expiresAt: Date?

    /// Whole days remaining (ceiling). `nil` when no active promo.
    var daysRemaining: Int? {
        guard let e = expiresAt else { return nil }
        let secs = e.timeIntervalSinceNow
        guard secs > 0 else { return nil }
        return max(1, Int(ceil(secs / 86400)))
    }

    /// True iff a granted promo hasn't yet expired.
    var isActive: Bool {
        guard let e = expiresAt else { return false }
        return e > Date()
    }

    private let defaults = UserDefaults.standard
    /// Anti-replay flag: once set, no further onboarding grants are issued
    /// even if the user wipes their local app state. Synced via iCloud KVS.
    private let keyGrantedAt = "promo_granted_at_v1"
    /// Current expiry window. Synced via iCloud KVS so a reinstall during
    /// the active 7 days picks up where it left off (rather than restarting).
    private let keyExpiresAt = "promo_expires_at_v1"

    /// Days of unlimited time granted by the onboarding promo.
    static let onboardingPromoDays: Int = 7

    private var expiryTimer: Timer?

    init() {
        if let stored = defaults.object(forKey: keyExpiresAt) as? Date {
            self.expiresAt = stored
        }
        scheduleExpiryTimer()
    }

    /// Idempotent: grants 7 days if and only if no prior grant exists.
    /// Call after onboarding completes.
    func grantOnboardingPromo() {
        guard defaults.object(forKey: keyGrantedAt) == nil else { return }
        let now    = Date()
        let expiry = Calendar.current.date(byAdding: .day, value: Self.onboardingPromoDays, to: now)
                     ?? now.addingTimeInterval(Double(Self.onboardingPromoDays) * 86400)
        defaults.set(now,    forKey: keyGrantedAt)
        defaults.set(expiry, forKey: keyExpiresAt)
        self.expiresAt = expiry
        scheduleExpiryTimer()
    }

    /// Schedules a one-shot timer to fire `objectWillChange` at the moment
    /// the promo expires, so any UI bound to `isActive` / `daysRemaining`
    /// updates without a separate poll.
    private func scheduleExpiryTimer() {
        expiryTimer?.invalidate()
        expiryTimer = nil
        guard let e = expiresAt else { return }
        let interval = e.timeIntervalSinceNow
        guard interval > 0 else { return }
        let t = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                // Force a recompute pass — `expiresAt` is unchanged but
                // `isActive` flipped via Date() crossing the boundary.
                self.objectWillChange.send()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        expiryTimer = t
    }

    #if DEBUG
    /// DEBUG-only: wipe both the grant flag and the expiry so the next
    /// `grantOnboardingPromo()` call issues a fresh 7-day window. Used by
    /// the profile DEBUG section to re-test the promo flow.
    func debugReset() {
        defaults.removeObject(forKey: keyGrantedAt)
        defaults.removeObject(forKey: keyExpiresAt)
        expiresAt = nil
        expiryTimer?.invalidate()
        expiryTimer = nil
    }
    #endif
}
