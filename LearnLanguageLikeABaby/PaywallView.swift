import StoreKit
import SwiftUI

/// LLLB Pro paywall — full-screen, dismissible.
///
/// **Visual style A** (sturdy big-brand): deep navy background, gold logo +
/// CTA, clean type-led layout. Colors sourced from `lllbPaywallNavy` and
/// `lllbRingColors[3]` (gold). Always renders dark regardless of system
/// appearance — the paywall is intentionally one-tone.
///
/// Triggered from two places:
/// 1. CoffeeRefillMenu "subscribe" button (user-initiated)
/// 2. Onboarding 7-day promo expiry (one-shot system trigger)
struct PaywallView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    let nativeLanguage: String
    let onDismiss: () -> Void

    @State private var selectedID: String = SubscriptionManager.yearlyProductID
    @State private var purchasing: Bool = false
    @State private var purchaseError: String? = nil

    private static let termsURL   = URL(string: "https://felixscifi.github.io/lllb-legal/terms.html")!
    private static let privacyURL = URL(string: "https://felixscifi.github.io/lllb-legal/privacy.html")!

    private var navy:     Color { Color.lllbPaywallNavy }
    private var navyElev: Color { Color.lllbPaywallNavyElevated }
    private var gold:     Color { Color.lllbRingColors[3] }

    var body: some View {
        ZStack(alignment: .topLeading) {
            navy.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    heroSection
                    featureSection
                    productSection
                    ctaButton
                    autoRenewNote
                    footerLinks
                }
                .padding(.top, 56)
                .padding(.bottom, 40)
            }

            closeButton
        }
        .preferredColorScheme(.dark)
        .alert(L("出错了", "Something went wrong", nativeLanguage: nativeLanguage),
               isPresented: Binding(
                get: { purchaseError != nil },
                set: { if !$0 { purchaseError = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(purchaseError ?? "")
        }
        .onChange(of: subscriptionManager.isSubscribed) { newValue in
            if newValue { onDismiss() }
        }
    }

    // MARK: - Close button

    private var closeButton: some View {
        Button {
            Haptics.soft()
            onDismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.55))
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.10), in: Circle())
                .padding(.leading, 16)
                .padding(.top, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 4) {
            Text("LLLB")
                .font(.system(size: 68, weight: .black))
                .tracking(-2)
                .foregroundStyle(gold)
            Text("Pro")
                .font(.system(size: 24, weight: .heavy))
                .tracking(6)
                .foregroundStyle(gold)
                .padding(.top, -4)
        }
        .padding(.top, 16)
    }

    // MARK: - Features

    /// Pro 唯一与免费版的差异是无限时间，所以这里只讲这一件事——不放
    /// 任何其他"特性"以免误导用户。
    private var featureSection: some View {
        VStack(spacing: 8) {
            Text(L("无限学习时间",
                   "Unlimited learning time",
                   nativeLanguage: nativeLanguage))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.white)
            Text(L("不再受咖啡杯每天 45 分钟的限制",
                   "Lifts the 45-minute daily cup limit",
                   nativeLanguage: nativeLanguage))
                .font(.system(size: 14))
                .foregroundStyle(Color.white.opacity(0.70))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 36)
    }

    // MARK: - Product cards

    private var productSection: some View {
        VStack(spacing: 10) {
            if !subscriptionManager.didFinishInitialLoad {
                ProgressView()
                    .tint(gold)
                    .padding(.vertical, 36)
            } else if subscriptionManager.products.isEmpty {
                productErrorState
            } else {
                if let yearly = subscriptionManager.yearly {
                    productCard(product: yearly, isYearly: true)
                }
                if let monthly = subscriptionManager.monthly {
                    productCard(product: monthly, isYearly: false)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    /// Shown when product loading completes but the list is empty (App Store
    /// not configured / network failure / running off-Xcode without ASC).
    private var productErrorState: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(gold)
            Text(L("订阅产品暂时无法加载",
                   "Couldn't load subscriptions",
                   nativeLanguage: nativeLanguage))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.85))
            Text(L("请检查网络后重试",
                   "Check your connection and try again",
                   nativeLanguage: nativeLanguage))
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.55))
            Button {
                Haptics.light()
                Task { await subscriptionManager.loadProducts() }
            } label: {
                Text(L("重试", "Retry", nativeLanguage: nativeLanguage))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(navy)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 9)
                    .background(gold, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(navyElev, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func productCard(product: Product, isYearly: Bool) -> some View {
        let selected = selectedID == product.id
        return Button {
            Haptics.light()
            selectedID = product.id
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(selected ? gold : Color.white.opacity(0.30), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if selected {
                        Circle().fill(gold).frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(isYearly
                             ? L("年付", "Yearly",  nativeLanguage: nativeLanguage)
                             : L("月付", "Monthly", nativeLanguage: nativeLanguage))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.white)
                        if isYearly {
                            Text(L("省 44%", "Save 44%", nativeLanguage: nativeLanguage))
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(navy)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(gold, in: Capsule())
                        }
                    }
                    Text(productSubtitle(product: product, isYearly: isYearly))
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.55))
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(navyElev, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? gold : Color.white.opacity(0.10),
                            lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func productSubtitle(product: Product, isYearly: Bool) -> String {
        let auto = L("自动续订", "auto-renews", nativeLanguage: nativeLanguage)
        if isYearly {
            let perMonth  = product.price / 12
            let formatted = product.priceFormatStyle.format(perMonth)
            let monthLbl  = L("月", "mo", nativeLanguage: nativeLanguage)
            return "\(formatted) / \(monthLbl) · \(auto)"
        }
        return auto
    }

    // MARK: - CTA

    private var ctaButton: some View {
        let product = subscriptionManager.products.first { $0.id == selectedID }
        let enabled = product != nil && !purchasing
        return Button {
            guard let product, !purchasing else { return }
            Haptics.medium()
            Task { await performPurchase(product) }
        } label: {
            ZStack {
                if purchasing {
                    ProgressView().tint(navy)
                } else {
                    Text(L("立即开通", "Subscribe now", nativeLanguage: nativeLanguage))
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(navy)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: gold.opacity(0.35), radius: 18, y: 8)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
        .padding(.horizontal, 24)
    }

    private func performPurchase(_ product: Product) async {
        purchasing = true
        defer { purchasing = false }
        do {
            _ = try await subscriptionManager.purchase(product)
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Auto-renew note

    private var autoRenewNote: some View {
        Text(L("订阅自动续订，可随时在 App Store 设置中取消。",
               "Subscriptions auto-renew. Cancel anytime in App Store settings.",
               nativeLanguage: nativeLanguage))
            .font(.system(size: 11))
            .foregroundStyle(Color.white.opacity(0.50))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 36)
    }

    // MARK: - Footer

    private var footerLinks: some View {
        HStack(spacing: 14) {
            Button {
                Haptics.soft()
                Task { await subscriptionManager.restorePurchases() }
            } label: {
                Text(L("恢复购买", "Restore", nativeLanguage: nativeLanguage))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            dot
            Link(destination: Self.termsURL) {
                Text(L("条款", "Terms", nativeLanguage: nativeLanguage))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            dot
            Link(destination: Self.privacyURL) {
                Text(L("隐私", "Privacy", nativeLanguage: nativeLanguage))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
        }
    }

    private var dot: some View {
        Text("·").foregroundStyle(Color.white.opacity(0.30))
    }
}
