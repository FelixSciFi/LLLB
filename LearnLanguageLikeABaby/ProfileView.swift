import SwiftUI
import AVFoundation

// MARK: - Profile hub

struct ProfileView: View {
    @ObservedObject var appModel: AppModel
    @Binding var selectedLearningLanguageID: String
    /// Tapped from the upgrade row → caller closes ProfileView and presents
    /// the paywall (centralised in RootView). Plain closure so this view
    /// stays oblivious to which sheet/cover the parent is using.
    var onOpenSubscribe: () -> Void = {}

    @State private var showStreakShareSheet: Bool = false

    var body: some View {
        let candyStore = appModel.candyStore
        let sessions   = appModel.availableSessions
        let wordTables = appModel.wordTables
        let nl         = candyStore.nativeLanguage
        return NavigationStack {
            ZStack {
                Color.lllbBackground.ignoresSafeArea()
                List {
                // ── Subscription status ────────────────────────────────────
                Section {
                    SubscriptionStatusRow(
                        subscriptionManager: appModel.subscriptionManager,
                        entitlementStore:    appModel.entitlementStore,
                        nativeLanguage:      nl,
                        onOpenSubscribe:     onOpenSubscribe
                    )
                    Button {
                        Haptics.light()
                        showStreakShareSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.lllbAccent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("分享我的连续学习", "Share my streak", nativeLanguage: nl))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.primary)
                                Text(L("🔥 \(appModel.usageTimeTracker.streakDays) 天 · 完成分享得 \(ShareTriggerStore.rewardPerShare) 🍬",
                                       "🔥 \(appModel.usageTimeTracker.streakDays) days · earn \(ShareTriggerStore.rewardPerShare) 🍬",
                                       nativeLanguage: nl))
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                // Stats moved to the 2×2 rings overlay (tap rings on home screen).

                // ── Language settings ──────────────────────────────────────
                Section(header: Text(L("语言", "Language", nativeLanguage: nl))) {
                    // Learning language — excludes current native language
                    NavigationLink {
                        LanguagePickerView(
                            title: L("学习语言", "Learning Language", nativeLanguage: nl),
                            languages: LanguageConfig.releasedLearningLanguages.filter { $0.id != candyStore.nativeLanguage },
                            selectedID: $selectedLearningLanguageID,
                            nativeLanguage: nl
                        )
                    } label: {
                        let current = LanguageConfig.learningLanguages.first { $0.id == selectedLearningLanguageID }
                        HStack(spacing: 8) {
                            Label(L("学习语言", "Learning", nativeLanguage: nl), systemImage: "graduationcap")
                            Spacer()
                            if let c = current {
                                Text(c.flag + " " + c.displayName(for: nl))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Native / interface language — excludes current learning language
                    NavigationLink {
                        LanguagePickerView(
                            title: L("母语", "Native Language", nativeLanguage: nl),
                            languages: LanguageConfig.uiLanguages.filter { $0.id != selectedLearningLanguageID },
                            selectedID: Binding(
                                get: { candyStore.nativeLanguage },
                                set: { candyStore.nativeLanguage = $0 }
                            ),
                            nativeLanguage: nl
                        )
                    } label: {
                        let current = LanguageConfig.uiLanguages.first { $0.id == candyStore.nativeLanguage }
                        HStack(spacing: 8) {
                            Label(L("母语", "Native", nativeLanguage: nl), systemImage: "house")
                            Spacer()
                            if let c = current {
                                Text(c.flag + " " + c.displayName(for: nl))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // ── Voice hub ──────────────────────────────────────────
                    NavigationLink {
                        let learningCodes = Set(sessions.map { String($0.config.ttsLocale.prefix(2)) })
                        let nativeLocale  = LanguageConfig.uiLanguages
                            .first { $0.id == candyStore.nativeLanguage }?.ttsLocale ?? "zh-CN"
                        let relevantCodes = learningCodes.union([String(nativeLocale.prefix(2))])
                        VoiceLanguageHubView(
                            relevantLanguageCodes: relevantCodes,
                            nativeLanguage: nl
                        )
                    } label: {
                        Label(L("语音", "Voices", nativeLanguage: nl),
                              systemImage: "waveform")
                    }
                }

                // ── My assets (我的词句) ────────────────────────────────────
                Section {
                    NavigationLink {
                        MyAssetsView(
                            session:        appModel.activeSession,
                            nativeLanguage: nl
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bag.fill")
                                .font(.title2)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("我的词句", "My Collection", nativeLanguage: nl))
                                    .font(.headline)
                                Text(L("播放池 · 学会了 · 稍后学",
                                       "Pool · Mastered · Later",
                                       nativeLanguage: nl))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // ── Word store entry hidden (2026-05-03) — buy-individual-words
                // monetization is paused. StoreView and supporting code below are
                // intentionally retained in case the feature is revived.

                // ── Playback settings ──────────────────────────────────────
                Section(header: Text(L("播放设置", "Playback", nativeLanguage: nl))) {
                    HStack {
                        Label(L("句间停顿", "Sentence gap", nativeLanguage: nl),
                              systemImage: "timer")
                        Spacer()
                        Picker("", selection: $appModel.interSentencePause) {
                            ForEach(1...5, id: \.self) { s in
                                Text("\(s)s").tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }

                    // Sleep timer
                    Menu {
                        if appModel.sleepTimerFireDate != nil {
                            Button(role: .destructive) {
                                appModel.cancelSleepTimer()
                            } label: {
                                Label(L("取消定时", "Cancel timer", nativeLanguage: nl),
                                      systemImage: "xmark.circle")
                            }
                            Divider()
                        }
                        ForEach([10, 20, 30, 45, 60], id: \.self) { mins in
                            Button {
                                appModel.setSleepTimer(minutes: mins)
                            } label: {
                                Text(L("\(mins) 分钟", "\(mins) min", nativeLanguage: nl))
                            }
                        }
                    } label: {
                        HStack {
                            Label(L("睡眠定时", "Sleep timer", nativeLanguage: nl),
                                  systemImage: "moon.zzz")
                            Spacer()
                            if appModel.sleepTimerFireDate != nil {
                                // Self-driven 1Hz countdown — only this Text rebuilds,
                                // not the whole ProfileView.
                                TimelineView(.periodic(from: .now, by: 1)) { _ in
                                    if let r = appModel.sleepTimerRemainingSeconds {
                                        let mm = r / 60, ss = r % 60
                                        Text(String(format: "%d:%02d", mm, ss))
                                            .font(.subheadline.monospacedDigit())
                                            .foregroundStyle(Color.lllbAccent)
                                    } else {
                                        Text(L("关", "Off", nativeLanguage: nl))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } else {
                                Text(L("关", "Off", nativeLanguage: nl))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }

                // ── Live Activity toggle — hidden, code retained for future cleanup ──

                #if DEBUG
                Section(header: Text("Developer"),
                        footer: Text(L("仅 DEBUG 构建可见，用来手动切换订阅状态测试 UI",
                                       "DEBUG-only — toggle premium state to test UI",
                                       nativeLanguage: nl))) {
                    DebugPremiumToggle(entitlementStore: appModel.entitlementStore)
                    DebugPromoControls(promoStore: appModel.promoStore)
                }
                #endif
            }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(L("我的", "Profile", nativeLanguage: nl))
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Color.lllbAccent)
        .sheet(isPresented: $showStreakShareSheet) {
            // Manual share entry: trigger=nil so we don't accidentally
            // mark a milestone as seen on dismiss.
            StreakShareSheet(
                trigger:           nil,
                triggerStore:      appModel.shareTriggerStore,
                candyStore:        appModel.candyStore,
                streakDays:        appModel.usageTimeTracker.streakDays,
                learningLanguage:  appModel.activeSession.config,
                totalHours:        (appModel.usageTimeTracker.allTimeMinutes
                                    + appModel.usageTimeTracker.allTimeBgMinutes / 3) / 60,
                nativeLanguage:    appModel.candyStore.nativeLanguage
            )
        }
    }
}

#if DEBUG
/// Tiny wrapper so the DEBUG premium toggle observes EntitlementStore directly
/// without forcing the whole ProfileView to re-render.
private struct DebugPremiumToggle: View {
    @ObservedObject var entitlementStore: EntitlementStore

    var body: some View {
        Toggle(isOn: $entitlementStore.debugOverride) {
            Label("Premium (∞ time)", systemImage: "infinity")
        }
    }
}

/// DEBUG promo controls: re-grant or wipe the onboarding 7-day promo so the
/// countdown / expiry warning can be re-tested without uninstalling the app.
private struct DebugPromoControls: View {
    @ObservedObject var promoStore: PromoStore

    var body: some View {
        HStack {
            Label("Promo", systemImage: "gift")
            Spacer()
            Text(promoStore.daysRemaining.map { "\($0)d" } ?? "—")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Button("Reset") {
                promoStore.debugReset()
                UserDefaults.standard.removeObject(forKey: "promo_warned_at_1d_v1")
                UserDefaults.standard.removeObject(forKey: "promo_warned_at_2d_v1")
                UserDefaults.standard.removeObject(forKey: "promo_expiry_paywall_shown_v1")
            }
            .buttonStyle(.bordered)
            Button("Grant") { promoStore.grantOnboardingPromo() }
                .buttonStyle(.borderedProminent)
        }
    }
}
#endif

// MARK: - Voice language hub

private struct VoiceLanguageHubView: View {
    let relevantLanguageCodes: Set<String>  // 2-letter codes used by the app, e.g. {"fr","zh"}
    let nativeLanguage: String
    @State private var voiceByLanguage: [String: String] = [:]

    private struct LanguageGroup: Identifiable {
        let id: String                      // 2-letter code, e.g. "fr"
        let displayName: String
        let voices: [AVSpeechSynthesisVoice]
    }

    private var languageGroups: [LanguageGroup] {
        var dict: [String: [AVSpeechSynthesisVoice]] = [:]
        for voice in AVSpeechSynthesisVoice.speechVoices() {
            let code = String(voice.language.prefix(2))
            guard relevantLanguageCodes.contains(code) else { continue }
            dict[code, default: []].append(voice)
        }
        return dict.map { code, voices -> LanguageGroup in
            let display = Locale.current.localizedString(forIdentifier: code) ?? code
            let sorted  = voices.sorted {
                if $0.quality.rawValue != $1.quality.rawValue { return $0.quality.rawValue > $1.quality.rawValue }
                return $0.name < $1.name
            }
            return LanguageGroup(id: code, displayName: display, voices: sorted)
        }
        .sorted { $0.displayName < $1.displayName }
    }

    private func selectedVoiceName(for code: String) -> String {
        guard let id = voiceByLanguage[code],
              let v  = AVSpeechSynthesisVoice(identifier: id) else {
            return L("自动", "Auto", nativeLanguage: nativeLanguage)
        }
        return v.name
    }

    var body: some View {
        ZStack {
        Color.lllbBackground.ignoresSafeArea()
        List {
            ForEach(languageGroups) { group in
                NavigationLink {
                    VoiceLanguageDetailView(
                        langCode:        group.id,
                        langDisplayName: group.displayName,
                        voices:          group.voices,
                        voiceByLanguage: $voiceByLanguage,
                        nativeLanguage:  nativeLanguage
                    )
                } label: {
                    LabeledContent(group.displayName) {
                        Text(selectedVoiceName(for: group.id))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(L("语音", "Voices", nativeLanguage: nativeLanguage))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            voiceByLanguage = UserDefaults.standard.dictionary(forKey: "voiceByLanguage")
                                  as? [String: String] ?? [:]
        }
        }
    }
}

// MARK: - Voice language detail

private struct VoiceLanguageDetailView: View {
    let langCode:        String
    let langDisplayName: String
    let voices:          [AVSpeechSynthesisVoice]
    @Binding var voiceByLanguage: [String: String]
    let nativeLanguage:  String

    @State private var previewer = AVSpeechSynthesizer()

    private var selectedID: String? { voiceByLanguage[langCode] }

    private func select(_ id: String?) {
        if let id {
            voiceByLanguage[langCode] = id
        } else {
            voiceByLanguage.removeValue(forKey: langCode)
        }
        UserDefaults.standard.set(voiceByLanguage, forKey: "voiceByLanguage")
    }

    private func playPreview(_ voice: AVSpeechSynthesisVoice) {
        previewer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: Self.previewText(for: langCode, voiceName: voice.name))
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.75
        previewer.speak(utterance)
    }

    private static func previewText(for code: String, voiceName: String) -> String {
        switch code {
        case "fr": return "Bonjour, je m'appelle \(voiceName)."
        case "es": return "Hola, me llamo \(voiceName)."
        case "de": return "Hallo, ich heiße \(voiceName)."
        case "it": return "Ciao, mi chiamo \(voiceName)."
        case "pt": return "Olá, eu me chamo \(voiceName)."
        case "en": return "Hello, my name is \(voiceName)."
        case "zh": return "你好，我叫\(voiceName)。"
        case "ja": return "こんにちは、私は\(voiceName)です。"
        case "ko": return "안녕하세요, 저는 \(voiceName)입니다."
        case "ru": return "Привет, меня зовут \(voiceName)."
        default:   return voiceName
        }
    }

    private func qualityLabel(_ voice: AVSpeechSynthesisVoice) -> String {
        let nl = nativeLanguage
        switch voice.quality {
        case .premium:  return " · " + L("高品质", "Premium",  nativeLanguage: nl)
        case .enhanced: return " · " + L("增强",   "Enhanced", nativeLanguage: nl)
        default:        return " · " + L("标准",   "Standard", nativeLanguage: nl)
        }
    }

    var body: some View {
        ZStack {
        Color.lllbBackground.ignoresSafeArea()
        List {
            // Auto option
            Section {
                Button {
                    select(nil)
                } label: {
                    HStack {
                        Text(L("自动", "Auto", nativeLanguage: nativeLanguage))
                        Spacer()
                        if selectedID == nil {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }

            // Voices for this language
            Section(footer: Text(L(
                "更多语音：设置 → 辅助功能 → 朗读内容 → 声音\nSiri 语音为系统专用，不支持第三方应用使用",
                "More voices: Settings → Accessibility → Spoken Content → Voices\nSiri voices are system-exclusive and unavailable to third-party apps",
                nativeLanguage: nativeLanguage
            ))) {
                ForEach(voices, id: \.identifier) { voice in
                    Button {
                        select(voice.identifier)
                        playPreview(voice)
                    } label: {
                        HStack {
                            Text(voice.name + qualityLabel(voice))
                            Spacer()
                            if selectedID == voice.identifier {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(langDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            previewer.stopSpeaking(at: .immediate)
        }
        }
    }
}

// MARK: - My Assets (我的词句)

/// Three-tab view for the **current learning language** only:
/// Pool / Mastered / Later. Pool capacity stepper lives at the top of the
/// pool tab. Per-language word ownership UI is gone (paused with word-store).
private struct MyAssetsView: View {
    @ObservedObject var session: LessonSessionModel
    let nativeLanguage: String

    @State private var selectedTab: Int = 0   // 0=Pool, 1=Mastered, 2=Later
    @State private var searchText  = ""

    var body: some View {
        let nl = nativeLanguage
        let pool     = session.filteredPool
        let mastered = session.masteredList
        let later    = session.laterList

        ZStack {
            Color.lllbBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text(L("播放池", "Pool",     nativeLanguage: nl) + " \(pool.count)").tag(0)
                    Text(L("学会了", "Mastered", nativeLanguage: nl) + " \(mastered.count)").tag(1)
                    Text(L("稍后学", "Later",    nativeLanguage: nl) + " \(later.count)").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Group {
                    switch selectedTab {
                    case 0: poolList(pool: pool, nl: nl)
                    case 1: archiveList(items: mastered, nl: nl)
                    case 2: archiveList(items: later, nl: nl)
                    default: EmptyView()
                    }
                }
            }
            .searchable(text: $searchText, prompt: L("搜索", "Search", nativeLanguage: nl))
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(L("我的词句", "My Collection", nativeLanguage: nl))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func filtered(_ items: [LessonSentence]) -> [LessonSentence] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter {
            $0.text.lowercased().contains(q)
            || $0.translation.values.contains { $0.lowercased().contains(q) }
            || $0.cefr.lowercased().contains(q)
        }
    }

    @ViewBuilder
    private func poolList(pool: [LessonSentence], nl: String) -> some View {
        let items = filtered(pool)
        List {
            Section(footer: Text(L(
                "推荐同时在播句子保持在 20–50 句之间，数量太少重复率高，太多则每句复习频率降低。",
                "For best results, keep 20–50 sentences in the pool. Too few causes repetition; too many reduces review frequency.",
                nativeLanguage: nl)).font(.caption2)
            ) {
                HStack {
                    Text(L("共 \(pool.count) 句", "\(pool.count) sentences total", nativeLanguage: nl))
                        .font(.subheadline)
                    Spacer()
                    Text(L("容量 \(session.poolCapacity)", "Cap \(session.poolCapacity)", nativeLanguage: nl))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.lllbAccent)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.lllbAccent.opacity(0.12))
                        .clipShape(Capsule())
                }
                Stepper(value: $session.poolCapacity, in: 20...500, step: 10) {
                    HStack {
                        Label(L("句子池容量", "Pool capacity", nativeLanguage: nl),
                              systemImage: "tray.full")
                        Spacer()
                        Text("\(session.poolCapacity)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                if items.isEmpty {
                    Text(L("暂无句子", "No sentences", nativeLanguage: nl))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { sentence in
                        sentenceRow(sentence, nl: nl)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func archiveList(items: [LessonSentence], nl: String) -> some View {
        let shown = filtered(items)
        List {
            if shown.isEmpty {
                Text(L("暂无记录", "Nothing here yet", nativeLanguage: nl))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(shown) { sentence in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sentence.text).font(.body).lineLimit(2)
                            let tr = sentence.translation.resolvedTranslation(nativeLanguage: nl)
                            if !tr.isEmpty {
                                Text(tr).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        Spacer()
                        Button(L("恢复", "Restore", nativeLanguage: nl)) {
                            session.restoreSentence(id: sentence.id)
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func sentenceRow(_ sentence: LessonSentence, nl: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top) {
                Text(sentence.text).font(.body).lineLimit(2)
                Spacer()
                Text(sentence.cefr)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.lllbTagBg)
                    .clipShape(Capsule())
            }
            let tr = sentence.translation.resolvedTranslation(nativeLanguage: nl)
            if !tr.isEmpty {
                Text(tr).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Store language hub

struct StoreView: View {
    @ObservedObject var candyStore: CandyStore
    let sessions:       [LessonSessionModel]
    let wordTables:     [String: [WordEntry]]
    let nativeLanguage: String

    var body: some View {
        ZStack {
        Color.lllbBackground.ignoresSafeArea()
        List {
            ForEach(sessions) { session in
                let wt = wordTables[session.config.id] ?? []
                NavigationLink {
                    if wt.isEmpty {
                        StoreComingSoonView(
                            flag:           session.config.flag,
                            title:          session.config.displayName(for: nativeLanguage),
                            nativeLanguage: nativeLanguage
                        )
                    } else {
                        LanguageStoreView(
                            candyStore:     candyStore,
                            config:         session.config,
                            wordTable:      wt,
                            session:        session,
                            nativeLanguage: nativeLanguage
                        )
                    }
                } label: {
                    Text("\(session.config.flag) \(session.config.displayName(for: nativeLanguage))")
                        .font(.body)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(L("词商城", "Word store", nativeLanguage: nativeLanguage))
        .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Per-language store

struct LanguageStoreView: View {
    @ObservedObject var candyStore: CandyStore
    let config:         LanguageConfig
    let wordTable:      [WordEntry]
    let session:        LessonSessionModel
    let nativeLanguage: String

    var body: some View {
        LanguageStoreContent(
            candyStore:     candyStore,
            config:         config,
            wordTable:      wordTable,
            session:        session,
            nativeLanguage: nativeLanguage
        )
        .navigationTitle(config.displayName(for: nativeLanguage))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Coming soon placeholder

private struct StoreComingSoonView: View {
    let flag:           String
    let title:          String
    let nativeLanguage: String

    var body: some View {
        VStack(spacing: 16) {
            Text(flag).font(.system(size: 48))
            Text(L("敬请期待", "Coming soon", nativeLanguage: nativeLanguage))
                .font(.body).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Language store content

private enum StoreTab: CaseIterable, Hashable { case buy, sentences }

private struct LanguageStoreContent: View {
    @ObservedObject var candyStore: CandyStore
    let config:         LanguageConfig
    let wordTable:      [WordEntry]
    let session:        LessonSessionModel
    let nativeLanguage: String

    @State private var tab: StoreTab = .buy
    @State private var searchText      = ""
    @State private var buyConfirmEntry:  WordEntry?
    @State private var showBuyConfirm    = false
    @State private var buyAlertShowsFree = false
    @State private var buyAlertFreeCount = 0
    @State private var sentenceConfirmID: String?
    @State private var showSentenceConfirm = false

    /// lemma → total sentences in full library
    @State private var totalCounts:     [String: Int] = [:]
    /// lemma → sentences not yet individually purchased
    @State private var remainingCounts: [String: Int] = [:]

    private var language: String { config.id }

    @ViewBuilder
    private func sentenceCountLabel(lemma: String) -> some View {
        let total = totalCounts[lemma] ?? 0
        if total > 0 {
            let rem = remainingCounts[lemma] ?? 0
            Text("\(rem)/\(total)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var ownedLemmas: Set<String> { candyStore.ownedLemmas(for: language) }

    private var buyEntries: [WordEntry] {
        wordTable.filter { !ownedLemmas.contains($0.lemma) }.sorted { $0.rank < $1.rank }
    }

    private var purchasableSentences: [LessonSentence] {
        let ownedSentences = candyStore.ownedSentenceIDs(for: language)
        let soldIDs        = session.soldIDs
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return session.mainSentences.reversed()
            .filter { sentence in
                if ownedSentences.contains(sentence.id) { return false }
                if sentence.tokens.contains(where: { t in
                    guard let l = t.lemma else { return false }
                    return ownedLemmas.contains(l)
                }) { return false }
                if q.isEmpty { return true }
                return sentence.text.lowercased().contains(q)
                    || sentence.translation.values.contains { $0.lowercased().contains(q) }
            }
            .sorted { a, b in
                let aSold = soldIDs.contains(a.id)
                let bSold = soldIDs.contains(b.id)
                if aSold != bSold { return !aSold }
                return false
            }
    }

    private var filteredBuyEntries: [WordEntry] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return buyEntries }
        return buyEntries.filter {
            $0.lemma.lowercased().contains(q)
            || $0.translation.values.contains { $0.lowercased().contains(q) }
        }
    }

    var body: some View {
        ZStack {
        Color.lllbBackground.ignoresSafeArea()
        List {
            Section {
                Text("🍬 \(candyStore.candyBalance) Candy")
                    .font(.title3.weight(.semibold))
            }

            Section {
                Picker("", selection: $tab) {
                    Text(L("购买词", "Buy words",  nativeLanguage: nativeLanguage)).tag(StoreTab.buy)
                    Text(L("句子",   "Sentences",   nativeLanguage: nativeLanguage)).tag(StoreTab.sentences)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            switch tab {
            case .buy:
                Section {
                    ForEach(filteredBuyEntries, id: \.lemma) { entry in
                        HStack(spacing: 10) {
                            if !entry.emoji.isEmpty { Text(entry.emoji).frame(width: 24) }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.lemma).font(.body)
                                Text(entry.translation.resolvedTranslation(nativeLanguage: nativeLanguage))
                                    .font(.caption).foregroundStyle(.secondary)
                                sentenceCountLabel(lemma: entry.lemma)
                            }
                            Spacer()
                            Text("\(entry.rank)🍬").font(.caption).foregroundStyle(.secondary)
                            Button(L("购买", "Buy", nativeLanguage: nativeLanguage)) {
                                candyStore.refreshDailyFreeIfNeeded()
                                buyAlertShowsFree = candyStore.dailyFreeRemaining > 0
                                buyAlertFreeCount = candyStore.dailyFreeRemaining
                                buyConfirmEntry   = entry
                                showBuyConfirm    = true
                            }
                            .buttonStyle(.bordered).controlSize(.small)
                        }
                    }
                }

            case .sentences:
                Section(footer: Text(L("每句 10🍬，购买后立即加入播放池",
                                       "10🍬 per sentence · added to playlist immediately",
                                       nativeLanguage: nativeLanguage))
                    .font(.caption)) {
                    ForEach(purchasableSentences, id: \.id) { sentence in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(sentence.text).font(.body).lineLimit(2)
                                Text(sentence.translation.resolvedTranslation(nativeLanguage: nativeLanguage))
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Button("10🍬") {
                                sentenceConfirmID   = sentence.id
                                showSentenceConfirm = true
                            }
                            .buttonStyle(.bordered).controlSize(.small)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: L("搜索", "Search", nativeLanguage: nativeLanguage))
        .scrollContentBackground(.hidden)
        .onAppear { candyStore.refreshDailyFreeIfNeeded() }
        .task {
            let ownedSentences = candyStore.ownedSentenceIDs(for: language)
            var total:     [String: Int] = [:]
            var remaining: [String: Int] = [:]
            for sentence in session.mainSentences {
                let isBought = ownedSentences.contains(sentence.id)
                var seen = Set<String>()
                for token in sentence.tokens {
                    guard let lemma = token.lemma, !seen.contains(lemma) else { continue }
                    seen.insert(lemma)
                    total[lemma, default: 0] += 1
                    if !isBought { remaining[lemma, default: 0] += 1 }
                }
            }
            totalCounts     = total
            remainingCounts = remaining
        }
        .alert(buyWordAlertTitle, isPresented: $showBuyConfirm) {
            Button(buyWordConfirmTitle) {
                if let e = buyConfirmEntry { _ = candyStore.buyLemma(e.lemma, language: language, price: e.rank) }
                buyConfirmEntry = nil
            }
            Button(L("取消", "Cancel", nativeLanguage: nativeLanguage), role: .cancel) {
                buyConfirmEntry = nil
            }
        } message: { Text(buyWordAlertMessage) }
        .alert(L("购买句子", "Buy sentence", nativeLanguage: nativeLanguage),
               isPresented: $showSentenceConfirm) {
            Button(L("确认 · 10🍬", "Confirm · 10🍬", nativeLanguage: nativeLanguage)) {
                if let id = sentenceConfirmID { _ = candyStore.buySentence(id, language: language) }
                sentenceConfirmID = nil
            }
            Button(L("取消", "Cancel", nativeLanguage: nativeLanguage), role: .cancel) {
                sentenceConfirmID = nil
            }
        } message: { Text(L("花费 10🍬", "Cost: 10🍬", nativeLanguage: nativeLanguage)) }
        }
    }

    private var buyWordAlertTitle: String {
        guard let e = buyConfirmEntry else { return "" }
        if buyAlertShowsFree { return L("本次购买免费 🎁", "Free purchase 🎁", nativeLanguage: nativeLanguage) }
        return L("购买 \(e.lemma)", "Buy \(e.lemma)", nativeLanguage: nativeLanguage)
    }
    private var buyWordAlertMessage: String {
        guard let e = buyConfirmEntry else { return "" }
        if buyAlertShowsFree {
            return L("今天还剩 \(buyAlertFreeCount) 次免费机会",
                     "You have \(buyAlertFreeCount) free purchase(s) left today",
                     nativeLanguage: nativeLanguage)
        }
        return L("花费 \(e.rank) 🍬", "Cost: \(e.rank) 🍬", nativeLanguage: nativeLanguage)
    }
    private var buyWordConfirmTitle: String {
        buyAlertShowsFree
            ? L("确认购买", "Confirm purchase", nativeLanguage: nativeLanguage)
            : L("确认",     "Confirm",          nativeLanguage: nativeLanguage)
    }
}

// MARK: - Generic language picker (learning or native)

private struct LanguagePickerView: View {
    let title:          String
    let languages:      [LanguageConfig]
    @Binding var selectedID: String
    let nativeLanguage: String

    var body: some View {
        ZStack {
        Color.lllbBackground.ignoresSafeArea()
        List {
            ForEach(languages) { lang in
                Button {
                    selectedID = lang.id
                } label: {
                    HStack(spacing: 12) {
                        Text(lang.flag).font(.title2)
                        Text(lang.displayName(for: nativeLanguage))
                            .foregroundStyle(.primary)
                        Spacer()
                        if lang.id == selectedID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Subscription status row

/// Top-of-profile row that flips between two states based on
/// `subscriptionManager.isSubscribed`. Subscribed users get a manage-sub
/// shortcut; everyone else gets an upgrade affordance routed back to the
/// shared paywall presenter via `onOpenSubscribe`.
private struct SubscriptionStatusRow: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @ObservedObject var entitlementStore: EntitlementStore
    let nativeLanguage: String
    let onOpenSubscribe: () -> Void

    private var gold: Color { Color.lllbRingColors[3] }

    var body: some View {
        Group {
            if subscriptionManager.isSubscribed {
                subscribedRow
            } else {
                upgradeRow
            }
        }
    }

    // MARK: subscribed
    //
    // Read-only by design — cancel / change plan goes through Settings →
    // Apple ID → Subscriptions (Apple's standard path). Keeping it out of
    // the app per product decision: avoid surfacing the cancel button.

    private var subscribedRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(gold)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("LLLB Pro")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Text(subscribedSubtitle)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            Spacer()
        }
    }

    private var subscribedSubtitle: String {
        // Intentionally show only the plan — no renewal/expiry date. Reminding
        // subscribed users of an upcoming bill encourages cancellation.
        if subscriptionManager.activeProductID == SubscriptionManager.yearlyProductID {
            return L("年付", "Yearly", nativeLanguage: nativeLanguage)
        }
        if subscriptionManager.activeProductID == SubscriptionManager.monthlyProductID {
            return L("月付", "Monthly", nativeLanguage: nativeLanguage)
        }
        return L("已订阅", "Active", nativeLanguage: nativeLanguage)
    }

    // MARK: upgrade

    private var upgradeRow: some View {
        Button {
            Haptics.medium()
            onOpenSubscribe()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "infinity")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(gold)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("升级 LLLB Pro", "Upgrade to LLLB Pro", nativeLanguage: nativeLanguage))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    Text(upgradeSubtitle)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary.opacity(0.55))
            }
        }
        .buttonStyle(.plain)
    }

    /// Promo-aware subtitle: while the 7-day welcome promo is still running,
    /// remind the user how much is left rather than just hyping the upgrade.
    private var upgradeSubtitle: String {
        if let days = entitlementStore.promoDaysRemaining, entitlementStore.isPromoActive {
            return L("新人礼包还剩 \(days) 天 🎁",
                     "Welcome gift — \(days) days left 🎁",
                     nativeLanguage: nativeLanguage)
        }
        return L("无限学习时间", "Unlimited learning time", nativeLanguage: nativeLanguage)
    }
}
