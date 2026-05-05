import Combine
import Foundation

/// Single source of truth for whether the user currently has unlimited
/// playback time. Aggregates several inputs into one published flag the
/// rest of the app reads:
///
/// - DEBUG override (testing toggle in ProfileView)
/// - Onboarding 7-day promo (`PromoStore`)
/// - App Store subscription (`SubscriptionManager`)
///
/// Consumers that need to know whether the cup applies (`PlaybackBudget`
/// gating, `CoffeeCupView` ♾️ display, `ContentView` topBar) read
/// `isUnlimited` and observe this object directly via `@ObservedObject`.
/// Per the AppModel forwarding rule, this object is **not** forwarded to
/// `AppModel.objectWillChange`.
@MainActor
final class EntitlementStore: ObservableObject {

    /// True when the user has unlimited time — the cup is effectively bypassed
    /// and ♾️ is shown.
    var isUnlimited: Bool {
        debugOverride || promoStore.isActive || subscriptionManager.isSubscribed
    }

    /// Days remaining on the onboarding promo, or nil when not in a promo.
    var promoDaysRemaining: Int? { promoStore.daysRemaining }

    /// True iff the unlimited time is currently being provided by the promo.
    /// Used by `CoffeeRefillMenu` to pick the right "you're unlimited" subtitle.
    var isPromoActive: Bool { promoStore.isActive }

    /// True iff the user has an active App Store subscription.
    var isSubscribed: Bool { subscriptionManager.isSubscribed }

    /// DEBUG-only override, settable from the profile toggle. Persisted under
    /// the legacy `playback_is_premium_dev_v1` key so the existing toggle
    /// state carries over with no migration.
    @Published var debugOverride: Bool {
        didSet {
            defaults.set(debugOverride, forKey: keyDebugOverride)
            objectWillChange.send()
        }
    }

    private let promoStore: PromoStore
    private let subscriptionManager: SubscriptionManager
    private let defaults = UserDefaults.standard
    private let keyDebugOverride = "playback_is_premium_dev_v1"
    private var cancellables = Set<AnyCancellable>()

    init(promoStore: PromoStore, subscriptionManager: SubscriptionManager) {
        self.promoStore          = promoStore
        self.subscriptionManager = subscriptionManager
        self.debugOverride       = defaults.bool(forKey: keyDebugOverride)

        // Forward sub-component changes so views observing EntitlementStore
        // pick up promo grant / expiry / subscription updates without
        // observing the underlying stores directly.
        promoStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        subscriptionManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
