import SwiftUI

/// Shown either passively (auto-prompt once per day when a rescue window opens)
/// or actively (user taps the streak label). Renders one of four screens
/// depending on offer / candy / quota state, and on the success path.
struct StreakRescueSheet: View {

    @ObservedObject var rescueStore:   StreakRescueStore
    @ObservedObject var usageTracker:  UsageTimeTracker
    var candyStore:    CandyStore
    var shareTriggerStore: ShareTriggerStore
    var nativeLanguage: String
    /// Called when the user picks "Share my streak" from the no-window screen.
    /// Caller is responsible for dismissing this sheet (we already dismiss
    /// before invoking) and presenting the share sheet on a small delay so
    /// SwiftUI can finish closing this one first.
    var onRequestShare: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var didSucceed: Bool = false

    private var offer: StreakRescueOffer? {
        rescueStore.currentOffer(
            streakLastDateKey: usageTracker.streakLastDateString,
            streakDays:        usageTracker.streakDays
        )
    }

    var body: some View {
        VStack(spacing: 24) {
            handle
            content
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private var handle: some View {
        Capsule().fill(Color.lllbSeparator)
            .frame(width: 36, height: 5)
    }

    @ViewBuilder
    private var content: some View {
        if didSucceed {
            successScreen
        } else if let offer {
            if candyStore.candyBalance < offer.price {
                insufficientScreen(price: offer.price, balance: candyStore.candyBalance)
            } else {
                offerScreen(offer)
            }
        } else if rescueStore.monthlyRemaining == 0 {
            quotaExceededScreen
        } else {
            noWindowScreen
        }
    }

    // MARK: - Screens

    private func offerScreen(_ offer: StreakRescueOffer) -> some View {
        VStack(spacing: 20) {
            flameHeader(streakDays: offer.streakDays, color: rescueColor)
            Text(L("你的 \(offer.streakDays) 天连胜还能救",
                   "Your \(offer.streakDays)-day streak can still be saved"))
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(L("昨天没打卡。花 \(offer.price) 颗 🍬，把昨天补成已学习。",
                   "You missed yesterday. Spend \(offer.price) 🍬 to count it as a learning day."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                attemptRescue(offer: offer)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                    Text(L("用 \(offer.price) 🍬 补救", "Rescue · \(offer.price) 🍬"))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.lllbAccent, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
            }

            Button(L("以后再说", "Maybe later")) { dismiss() }
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(L("本月还能补救 \(offer.monthlyRemaining) 次",
                   "\(offer.monthlyRemaining) rescue\(offer.monthlyRemaining == 1 ? "" : "s") left this month"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private func insufficientScreen(price: Int, balance: Int) -> some View {
        VStack(spacing: 18) {
            flameHeader(streakDays: usageTracker.streakDays, color: .lllbSecondaryText)
            Text(L("🍬 余额不足", "Not enough 🍬"))
                .font(.title3.weight(.semibold))
            Text(L("救援需要 \(price) 颗,你目前有 \(balance) 颗。",
                   "Rescue costs \(price) 🍬, you have \(balance)."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(L("关闭", "Close")) { dismiss() }
                .font(.headline)
                .padding(.top, 4)
        }
    }

    private var quotaExceededScreen: some View {
        VStack(spacing: 18) {
            flameHeader(streakDays: usageTracker.streakDays, color: .lllbSecondaryText)
            Text(L("本月救援次数已用完", "Monthly rescue limit reached"))
                .font(.title3.weight(.semibold))
            Text(L("每月最多 \(StreakRescueStore.monthlyLimit) 次救援机会,下个月再来吧。",
                   "Max \(StreakRescueStore.monthlyLimit) rescues per month. Try again next month."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(L("关闭", "Close")) { dismiss() }
                .font(.headline)
                .padding(.top, 4)
        }
    }

    private var noWindowScreen: some View {
        VStack(spacing: 18) {
            flameHeader(streakDays: usageTracker.streakDays, color: usageTracker.streakDays > 0 ? Color.lllbRingColors[0] : .lllbSecondaryText)
            if usageTracker.streakDays > 0 {
                Text(L("已连续学习 \(usageTracker.streakDays) 天", "\(usageTracker.streakDays)-day streak going"))
                    .font(.title3.weight(.semibold))
                Text(L("继续保持!", "Keep it up!"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Haptics.light()
                    dismiss()
                    onRequestShare()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text(L("分享我的连胜", "Share my streak"))
                            .font(.headline)
                        if shareTriggerStore.canRewardNow() {
                            Text("+\(ShareTriggerStore.rewardPerShare) 🍬")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.22), in: Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.lllbAccent, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
                }
                .padding(.top, 4)
            } else {
                Text(L("还没开始连胜", "No active streak"))
                    .font(.title3.weight(.semibold))
                Text(L("每天学习满 5 分钟即可开启连胜。",
                       "Study at least 5 minutes a day to start a streak."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(L("关闭", "Close")) { dismiss() }
                .font(.headline)
                .padding(.top, 4)
        }
    }

    private var successScreen: some View {
        VStack(spacing: 18) {
            flameHeader(streakDays: usageTracker.streakDays, color: Color.lllbRingColors[0])
            Text(L("救援成功 🎉", "Rescued 🎉"))
                .font(.title2.weight(.heavy))
                .foregroundStyle(Color.lllbRingColors[0])
            Text(L("连胜继续!今天学满 5 分钟,你的连胜将变成 \(usageTracker.streakDays + 1) 天。",
                   "Streak saved! Reach 5 min today and it'll become \(usageTracker.streakDays + 1) days."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(L("好的", "Done")) { dismiss() }
                .font(.headline)
                .padding(.top, 4)
        }
    }

    // MARK: - Header

    private var rescueColor: Color { Color(red: 0.42, green: 0.50, blue: 0.62) }

    private func flameHeader(streakDays: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 56, weight: .black))
                .foregroundStyle(color)
            Text("\(streakDays)")
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(color)
        }
        .padding(.top, 8)
    }

    // MARK: - Action

    private func attemptRescue(offer: StreakRescueOffer) {
        let result = rescueStore.performDebit(price: offer.price, candyStore: candyStore)
        switch result {
        case .success:
            usageTracker.applyRescue()
            Haptics.medium()
            withAnimation { didSucceed = true }
        case .insufficientCandy, .quotaExceeded:
            // The screen will re-render with the corresponding state.
            Haptics.light()
        }
    }

    // MARK: - i18n

    private func L(_ zh: String, _ en: String) -> String {
        nativeLanguage == "en" ? en : zh
    }
}
