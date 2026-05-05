import Foundation
import StoreKit

/// StoreKit 2 wrapper for the LLLB Pro auto-renewable subscription group.
///
/// Owns three responsibilities:
/// 1. Loading the two product configs (monthly + yearly) at launch.
/// 2. Driving purchase / restore flows for the paywall.
/// 3. Continuously listening for transactions (renewals, refunds, family
///    sharing changes) and re-publishing the current subscription state.
///
/// `EntitlementStore` observes this object and folds `isSubscribed` into
/// the unified `isUnlimited` flag the rest of the app reads.
@MainActor
final class SubscriptionManager: ObservableObject {

    static let monthlyProductID = "com.fanzhang.lllb.pro.monthly"
    static let yearlyProductID  = "com.fanzhang.lllb.pro.yearly"
    private static let allProductIDs: [String] = [monthlyProductID, yearlyProductID]

    /// Loaded product metadata (price, locale, period). Empty until the
    /// async load completes — or permanently empty if products aren't
    /// configured (e.g. running on a real device outside an Xcode-launched
    /// session, before App Store Connect has the product IDs).
    @Published private(set) var products: [Product] = []

    /// True after the first `loadProducts()` attempt has resolved. Lets the
    /// paywall distinguish "still loading" (spinner) from "loaded but empty"
    /// (show retry / error state) — without this, a misconfigured launch
    /// shows an indefinite spinner.
    @Published private(set) var didFinishInitialLoad: Bool = false

    /// True iff a transaction in the LLLB Pro group is currently entitled.
    @Published private(set) var isSubscribed: Bool = false

    /// Expiry date of the active subscription period, or nil when not
    /// subscribed. Used to drive the "renews on" line in account UI later.
    @Published private(set) var expiresAt: Date? = nil

    /// True iff auto-renew is on. False after the user cancels but before
    /// the period ends — they're still entitled, just won't renew.
    @Published private(set) var willRenew: Bool = false

    /// The product ID currently entitling the user (yearly vs monthly), or nil.
    @Published private(set) var activeProductID: String? = nil

    private var transactionListener: Task<Void, Never>? = nil

    init() {
        transactionListener = Task { [weak self] in
            await self?.listenForTransactions()
        }
        Task { await loadProducts() }
        Task { await refreshSubscriptionStatus() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Product loading

    func loadProducts() async {
        // Reset to loading state so a retry triggers UI back to spinner.
        if didFinishInitialLoad { didFinishInitialLoad = false }
        defer { didFinishInitialLoad = true }
        do {
            let fetched = try await Product.products(for: Self.allProductIDs)
            // Yearly first, monthly second — paywall renders in this order.
            self.products = fetched.sorted { lhs, rhs in
                if lhs.id == Self.yearlyProductID  { return true  }
                if rhs.id == Self.yearlyProductID  { return false }
                return false
            }
        } catch {
            // Swallow — paywall just shows empty product list. UI handles that.
            self.products = []
        }
    }

    var monthly: Product? { products.first { $0.id == Self.monthlyProductID } }
    var yearly:  Product? { products.first { $0.id == Self.yearlyProductID  } }

    // MARK: - Purchase

    /// Initiates a purchase. Returns true on success. UI should refresh the
    /// paywall on success (entitlement state updates via the listener).
    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshSubscriptionStatus()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// Triggers Apple's restore flow. StoreKit 2's transaction listener will
    /// pick up any restored entitlements and refresh state.
    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshSubscriptionStatus()
    }

    // MARK: - State refresh

    /// Walks the user's current entitlements and updates published state.
    /// Called at boot, after purchase, after restore, and on every
    /// transaction-listener wake.
    func refreshSubscriptionStatus() async {
        var subscribed       = false
        var soonestExpiry:   Date?    = nil
        var winningRenew:    Bool     = false
        var winningProductID: String? = nil

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productType == .autoRenewable,
                  Self.allProductIDs.contains(transaction.productID)
            else { continue }
            // Skip revoked transactions (refunded, family-share lost, etc).
            if transaction.revocationDate != nil { continue }

            subscribed = true
            if let exp = transaction.expirationDate {
                if soonestExpiry == nil || exp > (soonestExpiry ?? .distantPast) {
                    soonestExpiry    = exp
                    winningProductID = transaction.productID
                }
            }
        }

        // Pull renewal info from the active subscription group. All products
        // in the group share the same status — checking yearly is enough.
        if subscribed,
           let yearlyProduct = yearly,
           let info = yearlyProduct.subscription,
           let statuses = try? await info.status {
            for status in statuses {
                guard case .verified(let renewalInfo) = status.renewalInfo else { continue }
                winningRenew = renewalInfo.willAutoRenew
                break
            }
        }

        self.isSubscribed    = subscribed
        self.expiresAt       = soonestExpiry
        self.willRenew       = winningRenew
        self.activeProductID = winningProductID
    }

    // MARK: - Transaction listener

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish()
            await refreshSubscriptionStatus()
        }
    }

    // MARK: - Helpers

    private func checkVerified<T>(_ verification: VerificationResult<T>) throws -> T {
        switch verification {
        case .unverified:
            throw SubscriptionError.unverifiedTransaction
        case .verified(let safe):
            return safe
        }
    }

    enum SubscriptionError: Error {
        case unverifiedTransaction
    }
}
