import Foundation

// MARK: - Types

enum MilestoneDimension {
    case daily, weekly, monthly, lifetime
}

struct MilestoneDefinition: Identifiable {
    let id: String
    let dimension: MilestoneDimension
    let thresholdMinutes: Int
    let candyReward: Int
    let titleZh: String
    let titleEn: String
    let subtitleZh: String
    let subtitleEn: String
}

// MARK: - AchievementManager

@MainActor
final class AchievementManager: ObservableObject {

    // MARK: - Milestone catalog

    static let allMilestones: [MilestoneDefinition] = [
        // 每日时长
        .init(id: "daily_5",    dimension: .daily,    thresholdMinutes: 5,
              candyReward: 10,  titleZh: "入门仪式 — 开始了",    titleEn: "First ritual — it starts",
              subtitleZh: "哪怕五分钟，也是今天的耳朵",          subtitleEn: "Even five minutes counts as today's listening"),
        .init(id: "daily_15",   dimension: .daily,    thresholdMinutes: 15,
              candyReward: 20,  titleZh: "标准模式 — 稳了",      titleEn: "Standard mode — steady",
              subtitleZh: "超过全球80%语言学习者的日均时长",      subtitleEn: "More than 80% of language learners worldwide log daily"),
        .init(id: "daily_30",   dimension: .daily,    thresholdMinutes: 30,
              candyReward: 35,  titleZh: "沉浸模式 — 认真的",    titleEn: "Immersion mode — serious now",
              subtitleZh: "大脑开始为这门语言留出专属通道",       subtitleEn: "Your brain is starting to carve out a dedicated lane"),
        .init(id: "daily_120",  dimension: .daily,    thresholdMinutes: 120,
              candyReward: 60,  titleZh: "全浸模式 — 疯了（褒义）", titleEn: "Full immersion — obsessed (in a good way)",
              subtitleZh: "你今天活在两种语言里",               subtitleEn: "You lived in two languages today"),

        // 每周积累
        .init(id: "week_30",    dimension: .weekly,   thresholdMinutes: 30,
              candyReward: 20,  titleZh: "轻听周 — 起步",        titleEn: "Light week — getting started",
              subtitleZh: "把语言带进了这一周",                  subtitleEn: "You brought the language into this week"),
        .init(id: "week_120",   dimension: .weekly,   thresholdMinutes: 120,
              candyReward: 45,  titleZh: "习惯周 — 形成节律",    titleEn: "Habit week — finding the rhythm",
              subtitleZh: "每天平均17分钟，语言已成日常",        subtitleEn: "17 min/day on average — language is now part of daily life"),
        .init(id: "week_300",   dimension: .weekly,   thresholdMinutes: 300,
              candyReward: 80,  titleZh: "专注周 — 有意投入",    titleEn: "Focused week — intentional effort",
              subtitleZh: "相当于一门大学语言课的周课时",         subtitleEn: "Equivalent to a full week of university language classes"),
        .init(id: "week_600",   dimension: .weekly,   thresholdMinutes: 600,
              candyReward: 150, titleZh: "全力周 — 本周是你的",  titleEn: "Full-throttle week — this week was yours",
              subtitleZh: "职业语言陪练的工作强度",              subtitleEn: "The intensity of a professional language tutor's workload"),

        // 每月积累
        .init(id: "month_120",  dimension: .monthly,  thresholdMinutes: 120,
              candyReward: 30,  titleZh: "初见月 — 刚刚认识",    titleEn: "First meeting month",
              subtitleZh: "耳朵知道了这门语言的存在",            subtitleEn: "Your ears have acknowledged this language exists"),
        .init(id: "month_480",  dimension: .monthly,  thresholdMinutes: 480,
              candyReward: 80,  titleZh: "渐入月 — 开始熟悉",    titleEn: "Warming up month",
              subtitleZh: "常见的语音模式在大脑里留下印记",       subtitleEn: "Common sound patterns are starting to leave traces in your brain"),
        .init(id: "month_1200", dimension: .monthly,  thresholdMinutes: 1200,
              candyReward: 180, titleZh: "沉淀月 — 真的在学",    titleEn: "Depth month — genuinely learning",
              subtitleZh: "每月积累相当于一个语言学习集训营",     subtitleEn: "Monthly hours equivalent to a language learning bootcamp"),
        .init(id: "month_2400", dimension: .monthly,  thresholdMinutes: 2400,
              candyReward: 350, titleZh: "沉浸月 — 这个月你活在别的语言里", titleEn: "Immersion month — you lived in another language",
              subtitleZh: "全职语言课的单月强度",               subtitleEn: "The intensity of full-time language instruction for a month"),

        // 总时长
        .init(id: "life_600",   dimension: .lifetime, thresholdMinutes: 600,
              candyReward: 50,  titleZh: "耳朵开了",             titleEn: "Ears awakened",
              subtitleZh: "开始能感知节奏和音调轮廓",            subtitleEn: "You can now sense the rhythm and tonal contour"),
        .init(id: "life_1800",  dimension: .lifetime, thresholdMinutes: 1800,
              candyReward: 100, titleZh: "音感成形",             titleEn: "Phonetic sense forming",
              subtitleZh: "不再觉得这门语言听起来都一样",        subtitleEn: "The language no longer sounds like one long blur"),
        .init(id: "life_4500",  dimension: .lifetime, thresholdMinutes: 4500,
              candyReward: 200, titleZh: "语感初现",             titleEn: "Language intuition emerging",
              subtitleZh: "高频句型不需要翻译就能直接反应",       subtitleEn: "Common patterns trigger direct responses without translation"),
        .init(id: "life_9000",  dimension: .lifetime, thresholdMinutes: 9000,
              candyReward: 350, titleZh: "拐点到了",             titleEn: "Inflection point",
              subtitleZh: "日常对话基本能跟上语速",              subtitleEn: "Everyday conversations are followable"),
        .init(id: "life_18000", dimension: .lifetime, thresholdMinutes: 18000,
              candyReward: 600, titleZh: "字幕不再是拐杖",        titleEn: "Subtitles are optional now",
              subtitleZh: "能看目标语言的短视频、综艺",           subtitleEn: "You can follow videos and shows by ear"),
        .init(id: "life_30000", dimension: .lifetime, thresholdMinutes: 30000,
              candyReward: 1000,titleZh: "真的活在里面了",        titleEn: "Actually living in it",
              subtitleZh: "大脑在这门语言里开始直接思考",         subtitleEn: "Your brain is starting to think directly in this language"),
        .init(id: "life_45000", dimension: .lifetime, thresholdMinutes: 45000,
              candyReward: 1500,titleZh: "语言成了习惯",          titleEn: "Language as lifestyle",
              subtitleZh: "用这门语言消费内容不再是「学习」",      subtitleEn: "Consuming content in this language is no longer 'studying'"),
        .init(id: "life_60000", dimension: .lifetime, thresholdMinutes: 60000,
              candyReward: 3000,titleZh: "另一个自己",            titleEn: "Another self",
              subtitleZh: "这门语言已经是你认知世界的另一套系统", subtitleEn: "This language is now a second operating system for how you perceive the world"),
    ]

    // MARK: - Persistence

    private let keyLifetimeEarned = "achievement_lifetime_v1"
    private let keyPeriodEarned   = "achievement_period_v1"
    private let keyPending        = "achievement_pending_v1"

    private var lifetimeEarned: Set<String> = []
    private var periodEarned:   [String: String] = [:]
    @Published private(set) var pendingIDs: [String] = []

    // MARK: - Init

    init() { load() }

    // MARK: - Detection (no candy yet)

    /// `dayKey` / `weekKey` / `monthKey` MUST come from the same source that
    /// produced the minute counts (UsageTimeTracker), so a stale minute value
    /// never gets paired with a fresh period key across midnight rollover.
    func checkMilestones(
        todayMinutes:   Int,
        weekMinutes:    Int,
        monthMinutes:   Int,
        allTimeMinutes: Int,
        dayKey:   String,
        weekKey:  String,
        monthKey: String
    ) {
        // If the tracker hasn't initialized its period keys yet, skip — we'd
        // otherwise persist empty-string keys and re-award next launch.
        guard !dayKey.isEmpty, !weekKey.isEmpty, !monthKey.isEmpty else { return }

        var dirty = false

        for m in Self.allMilestones {
            let minutes: Int
            let periodKey: String

            switch m.dimension {
            case .daily:    minutes = todayMinutes;    periodKey = dayKey
            case .weekly:   minutes = weekMinutes;     periodKey = weekKey
            case .monthly:  minutes = monthMinutes;    periodKey = monthKey
            case .lifetime: minutes = allTimeMinutes;  periodKey = ""
            }

            guard minutes >= m.thresholdMinutes else { continue }

            switch m.dimension {
            case .lifetime:
                guard !lifetimeEarned.contains(m.id) else { continue }
                lifetimeEarned.insert(m.id)
            default:
                guard periodEarned[m.id] != periodKey else { continue }
                periodEarned[m.id] = periodKey
            }

            if !pendingIDs.contains(m.id) { pendingIDs.append(m.id) }
            dirty = true
        }

        if dirty { save() }
    }

    // MARK: - Collection (candy enters balance)

    func collectPending(candyStore: CandyStore) {
        for id in pendingIDs {
            guard let m = Self.allMilestones.first(where: { $0.id == id }) else { continue }
            candyStore.addCandy(m.candyReward)
        }
        pendingIDs = []
        save()
    }

    // MARK: - Pending helpers

    func hasPending(for dimension: MilestoneDimension) -> Bool {
        pendingIDs.contains { id in
            Self.allMilestones.first { $0.id == id }?.dimension == dimension
        }
    }

    var pendingMilestones: [MilestoneDefinition] {
        pendingIDs.compactMap { id in Self.allMilestones.first { $0.id == id } }
    }

    // MARK: - Progress (0…1) for ring display

    /// Progress 0…1 toward the next milestone: currentMinutes / nextThreshold.
    func progress(for dimension: MilestoneDimension, currentMinutes: Int) -> Double {
        let sorted = Self.allMilestones
            .filter { $0.dimension == dimension }
            .sorted { $0.thresholdMinutes < $1.thresholdMinutes }
        guard !sorted.isEmpty else { return 0 }

        if currentMinutes >= sorted.last!.thresholdMinutes { return 1.0 }

        guard let next = sorted.first(where: { $0.thresholdMinutes > currentMinutes }) else {
            return 1.0
        }
        return Double(currentMinutes) / Double(next.thresholdMinutes)
    }

    /// Next milestone threshold for a dimension (for display as the ring "target").
    func nextThreshold(for dimension: MilestoneDimension, currentMinutes: Int) -> Int? {
        Self.allMilestones
            .filter { $0.dimension == dimension }
            .sorted { $0.thresholdMinutes < $1.thresholdMinutes }
            .first { $0.thresholdMinutes > currentMinutes }?
            .thresholdMinutes
    }

    // MARK: - Persistence

    private func save() {
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(Array(lifetimeEarned)) { d.set(data, forKey: keyLifetimeEarned) }
        if let data = try? JSONEncoder().encode(periodEarned)          { d.set(data, forKey: keyPeriodEarned)   }
        if let data = try? JSONEncoder().encode(pendingIDs)            { d.set(data, forKey: keyPending)        }
    }

    private func load() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: keyLifetimeEarned),
           let arr  = try? JSONDecoder().decode([String].self, from: data) {
            lifetimeEarned = Set(arr)
        }
        if let data = d.data(forKey: keyPeriodEarned),
           let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            periodEarned = dict
        }
        if let data = d.data(forKey: keyPending),
           let arr  = try? JSONDecoder().decode([String].self, from: data) {
            pendingIDs = arr
        }
    }
}
