import SwiftUI
import AVFoundation

// MARK: - Profile hub

struct ProfileView: View {
    @ObservedObject var appModel: AppModel
    @Binding var selectedLearningLanguageID: String

    var body: some View {
        let candyStore = appModel.candyStore
        let sessions   = appModel.availableSessions
        let wordTables = appModel.wordTables
        let nl         = candyStore.nativeLanguage
        return NavigationStack {
            List {
                // ── Usage stats ────────────────────────────────────────────
                let tracker = appModel.usageTimeTracker
                Section(
                    header: Text(L("学习统计", "Stats", nativeLanguage: nl)),
                    footer: Text(L(
                        "学习时间 = 主动 + 被动 ÷ 3（被动收听效果约为主动的三分之一）",
                        "Learning time = active + passive ÷ 3 (passive listening counts at ⅓ efficiency)",
                        nativeLanguage: nl))
                        .font(.caption2)
                ) {
                    VStack(spacing: 6) {
                        // Column header row
                        HStack(spacing: 0) {
                            Color.clear.frame(width: 36)
                            ForEach([
                                L("今天", "Today", nativeLanguage: nl),
                                L("本周", "Week",  nativeLanguage: nl),
                                L("本月", "Month", nativeLanguage: nl),
                                L("全部", "All",   nativeLanguage: nl)
                            ], id: \.self) { col in
                                Text(col)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        Divider()

                        // 学习时间 row = active + passive / 3
                        let learnMinutes: [Int] = [
                            tracker.todayMinutes      + tracker.todayBgMinutes      / 3,
                            tracker.thisWeekMinutes   + tracker.thisWeekBgMinutes   / 3,
                            tracker.thisMonthMinutes  + tracker.thisMonthBgMinutes  / 3,
                            tracker.allTimeMinutes    + tracker.allTimeBgMinutes    / 3,
                        ]
                        statRow(L("学时", "Time", nativeLanguage: nl), learnMinutes,
                                nl: nl, prominent: true)

                        Divider()

                        // 主动 row
                        statRow(L("主动", "Active",  nativeLanguage: nl), [
                            tracker.todayMinutes, tracker.thisWeekMinutes,
                            tracker.thisMonthMinutes, tracker.allTimeMinutes
                        ], nl: nl)

                        Divider()

                        // 被动 row
                        statRow(L("被动", "Passive", nativeLanguage: nl), [
                            tracker.todayBgMinutes, tracker.thisWeekBgMinutes,
                            tracker.thisMonthBgMinutes, tracker.allTimeBgMinutes
                        ], nl: nl)
                    }
                    .padding(.vertical, 6)
                }
                .onAppear { tracker.refresh() }

                // ── Language settings ──────────────────────────────────────
                Section(header: Text(L("语言", "Language", nativeLanguage: nl))) {
                    // Learning language — excludes current native language
                    NavigationLink {
                        LanguagePickerView(
                            title: L("学习语言", "Learning Language", nativeLanguage: nl),
                            languages: LanguageConfig.learningLanguages.filter { $0.id != candyStore.nativeLanguage },
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

                // ── Balance ────────────────────────────────────────────────
                Section {
                    Text("🍬 \(candyStore.candyBalance) Candy")
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }

                // ── My assets (我的词句) ────────────────────────────────────
                Section {
                    NavigationLink {
                        MyAssetsView(
                            candyStore:     candyStore,
                            sessions:       sessions,
                            wordTables:     wordTables,
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
                                Text(L("已购词汇 · 存档句子",
                                       "Owned words · archived sentences",
                                       nativeLanguage: nl))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // ── Word store ─────────────────────────────────────────────
                Section {
                    NavigationLink {
                        StoreView(
                            candyStore:     candyStore,
                            sessions:       sessions,
                            wordTables:     wordTables,
                            nativeLanguage: nl
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "cart.fill")
                                .font(.title2)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("词商城", "Word store", nativeLanguage: nl))
                                    .font(.headline)
                                Text(L("按语言浏览 · 购买新词",
                                       "Browse by language · buy new words",
                                       nativeLanguage: nl))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

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
                    let remaining = appModel.sleepTimerRemainingSeconds
                    Menu {
                        if remaining != nil {
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
                            if let r = remaining {
                                let mm = r / 60, ss = r % 60
                                Text(String(format: "%d:%02d", mm, ss))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.orange)
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
            }
            .navigationTitle(L("我的", "Profile", nativeLanguage: nl))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - ProfileView helpers

private extension ProfileView {
    /// Single data row: row label + 4 value cells (no repeated column labels).
    func statRow(_ rowLabel: String, _ minuteValues: [Int],
                 nl: String, prominent: Bool = false) -> some View {
        HStack(spacing: 0) {
            Text(rowLabel)
                .font(.caption2)
                .foregroundStyle(prominent ? .primary : .secondary)
                .frame(width: 36, alignment: .leading)
            ForEach(minuteValues.indices, id: \.self) { i in
                Text(formatMinutes(minuteValues[i], nl: nl))
                    .font(prominent ? .subheadline.weight(.bold) : .subheadline.weight(.semibold))
                    .foregroundStyle(prominent ? .primary : .secondary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    func formatMinutes(_ minutes: Int, nl: String) -> String {
        let minUnit  = L("分", "m", nativeLanguage: nl)
        let hourUnit = L("h", "h", nativeLanguage: nl)
        if minutes <= 0 { return "0\(minUnit)" }
        if minutes < 60  { return "\(minutes)\(minUnit)" }
        let hours = Double(minutes) / 60.0
        if hours < 10    { return String(format: "%.1f\(hourUnit)", hours) }
        return "\(minutes / 60)\(hourUnit)"
    }
}

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
        .navigationTitle(L("语音", "Voices", nativeLanguage: nativeLanguage))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            voiceByLanguage = UserDefaults.standard.dictionary(forKey: "voiceByLanguage")
                                  as? [String: String] ?? [:]
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

    private var selectedID: String? { voiceByLanguage[langCode] }

    private func select(_ id: String?) {
        if let id {
            voiceByLanguage[langCode] = id
        } else {
            voiceByLanguage.removeValue(forKey: langCode)
        }
        UserDefaults.standard.set(voiceByLanguage, forKey: "voiceByLanguage")
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
        .navigationTitle(langDisplayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - My Assets (我的词句)

private struct MyAssetsView: View {
    @ObservedObject var candyStore: CandyStore
    let sessions:       [LessonSessionModel]
    let wordTables:     [String: [WordEntry]]
    let nativeLanguage: String

    var body: some View {
        let nl = nativeLanguage
        return List {
            // ── My words (我的词) ──────────────────────────────────────
            Section(header: Text(L("我的词", "My Words", nativeLanguage: nl))) {
                ForEach(sessions) { session in
                    let wt = wordTables[session.config.id] ?? []
                    NavigationLink {
                        SellWordsPageView(
                            candyStore:     candyStore,
                            config:         session.config,
                            wordTable:      wt,
                            session:        session,
                            nativeLanguage: nl
                        )
                    } label: {
                        HStack {
                            Text(session.config.flag)
                            Text(session.config.displayName(for: nl))
                            Spacer()
                            let owned = candyStore.ownedLemmas(for: session.config.id).count
                            if owned > 0 {
                                Text("\(owned)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            // ── Play pool ──────────────────────────────────────────────
            Section(header: Text(L("播放池", "Play Pool", nativeLanguage: nl))) {
                ForEach(sessions) { session in
                    let count = session.filteredSentences().count
                    NavigationLink {
                        PlayPoolView(session: session, nativeLanguage: nl)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle")
                                .font(.title2)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.config.flag + " " + session.config.displayName(for: nl))
                                    .font(.headline)
                                Text(L("\(count) 句", "\(count) sentences", nativeLanguage: nl))
                                    .font(.caption)
                                    .foregroundStyle(
                                        count < 20 ? .orange :
                                        count <= 50 ? .green : .secondary
                                    )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // ── Archived sentences (存档句子) ──────────────────────────
            Section(header: Text(L("存档句子", "Archived Sentences", nativeLanguage: nl))) {
                let archiveCount = sessions.flatMap { $0.trashedSentences() }.count
                NavigationLink {
                    ArchiveView(sessions: sessions, nativeLanguage: nl)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "archivebox")
                            .font(.title2)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("存档", "Archive", nativeLanguage: nl))
                                .font(.headline)
                            Text(archiveCount == 0
                                 ? L("暂无", "Empty", nativeLanguage: nl)
                                 : L("\(archiveCount) 条句子", "\(archiveCount) sentences",
                                     nativeLanguage: nl))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(L("我的词句", "My Collection", nativeLanguage: nl))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sell words page (我的词 → per language)

private struct SellWordsPageView: View {
    @ObservedObject var candyStore: CandyStore
    let config:         LanguageConfig
    let wordTable:      [WordEntry]
    let session:        LessonSessionModel
    let nativeLanguage: String

    @State private var searchText      = ""
    @State private var totalCounts:     [String: Int] = [:]
    @State private var remainingCounts: [String: Int] = [:]

    private var language: String { config.id }
    private var ownedLemmas: Set<String> { candyStore.ownedLemmas(for: language) }

    private var lemmaToEntry: [String: WordEntry] {
        Dictionary(uniqueKeysWithValues: wordTable.map { ($0.lemma, $0) })
    }

    private var sellEntries: [WordEntry] {
        ownedLemmas.compactMap { lemmaToEntry[$0] }.sorted { $0.rank < $1.rank }
    }

    private var filteredSellEntries: [WordEntry] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return sellEntries }
        return sellEntries.filter {
            $0.lemma.lowercased().contains(q)
            || $0.translation.values.contains { $0.lowercased().contains(q) }
        }
    }

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

    var body: some View {
        List {
            Section {
                Text("🍬 \(candyStore.candyBalance) Candy")
                    .font(.title3.weight(.semibold))
            }
            Section {
                ForEach(filteredSellEntries, id: \.lemma) { entry in
                    let refund = Int(ceil(Double(entry.rank) * 0.8))
                    HStack(spacing: 10) {
                        if !entry.emoji.isEmpty { Text(entry.emoji).frame(width: 24) }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.lemma).font(.body)
                            Text(entry.translation.resolvedTranslation(nativeLanguage: nativeLanguage))
                                .font(.caption).foregroundStyle(.secondary)
                            sentenceCountLabel(lemma: entry.lemma)
                        }
                        Spacer()
                        Text("+\(refund)🍬").font(.caption).foregroundStyle(.secondary)
                        Button(L("出售", "Sell", nativeLanguage: nativeLanguage)) {
                            candyStore.sellLemma(entry.lemma, language: language, price: entry.rank)
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: L("搜索", "Search", nativeLanguage: nativeLanguage))
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
        .navigationTitle(config.displayName(for: nativeLanguage))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Archive sub-page

private struct ArchiveView: View {
    let sessions:       [LessonSessionModel]
    let nativeLanguage: String
    @State private var searchText = ""

    var body: some View {
        let allTrashed = sessions.flatMap { s in s.trashedSentences().map { (session: s, sentence: $0) } }
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let trashed = q.isEmpty ? allTrashed : allTrashed.filter {
            $0.sentence.text.lowercased().contains(q)
            || $0.sentence.translation.values.contains { $0.lowercased().contains(q) }
        }
        List {
            if trashed.isEmpty {
                Text(L("暂无存档", "No archived sentences", nativeLanguage: nativeLanguage))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(trashed, id: \.sentence.id) { item in
                    TrashedSentenceRow(
                        sentence:       item.sentence,
                        flag:           item.session.config.flag,
                        nativeLanguage: nativeLanguage,
                        onRestore:      { item.session.restoreSentence(id: item.sentence.id) },
                        onSell:         { item.session.sellArchivedSentence(id: item.sentence.id) }
                    )
                }
            }
        }
        .searchable(text: $searchText, prompt: L("搜索", "Search", nativeLanguage: nativeLanguage))
        .navigationTitle(L("存档", "Archive", nativeLanguage: nativeLanguage))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Play pool view

private struct PlayPoolView: View {
    let session:       LessonSessionModel
    let nativeLanguage: String
    @State private var searchText = ""

    private var sentences: [LessonSentence] {
        let all = session.filteredSentences()
        let q   = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.text.lowercased().contains(q)
            || $0.translation.values.contains { $0.lowercased().contains(q) }
            || $0.cefr.lowercased().contains(q)
        }
    }

    var body: some View {
        let count = session.filteredSentences().count
        let nl    = nativeLanguage
        List {
            Section(footer: Text(L(
                "推荐同时在播句子保持在 20–50 句之间，数量太少重复率高，太多则每句复习频率降低。",
                "For best results, keep 20–50 sentences in the pool. Too few causes repetition; too many reduces review frequency.",
                nativeLanguage: nl))
                .font(.caption2)
            ) {
                HStack {
                    Text(L("共 \(count) 句", "\(count) sentences total", nativeLanguage: nl))
                        .font(.subheadline)
                    Spacer()
                    Text(count < 20 ? L("偏少", "Too few", nativeLanguage: nl) :
                         count <= 50 ? L("理想", "Ideal", nativeLanguage: nl) :
                                       L("偏多", "Many", nativeLanguage: nl))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(count < 20 ? .orange : count <= 50 ? .green : .secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(
                            (count < 20 ? Color.orange : count <= 50 ? Color.green : Color.secondary)
                                .opacity(0.12)
                        )
                        .clipShape(Capsule())
                }
            }

            Section {
                ForEach(sentences) { sentence in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .top) {
                            Text(sentence.text)
                                .font(.body)
                                .lineLimit(2)
                            Spacer()
                            Text(sentence.cefr)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(Capsule())
                        }
                        let tr = sentence.translation.resolvedTranslation(nativeLanguage: nl)
                        if !tr.isEmpty {
                            Text(tr)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .searchable(text: $searchText, prompt: L("搜索", "Search", nativeLanguage: nl))
        .navigationTitle(session.config.flag + " " + session.config.displayName(for: nl))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Trashed sentence row

private struct TrashedSentenceRow: View {
    let sentence:       LessonSentence
    let flag:           String
    let nativeLanguage: String
    let onRestore:      () -> Void
    let onSell:         () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(flag)
            VStack(alignment: .leading, spacing: 2) {
                Text(sentence.text)
                    .font(.body)
                    .lineLimit(2)
                let tr = sentence.translation.resolvedTranslation(nativeLanguage: nativeLanguage)
                if !tr.isEmpty {
                    Text(tr)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Button(L("恢复", "Restore", nativeLanguage: nativeLanguage)) { onRestore() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button("8🍬") { onSell() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.orange)
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
        .navigationTitle(L("词商城", "Word store", nativeLanguage: nativeLanguage))
        .navigationBarTitleDisplayMode(.inline)
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
                            .buttonStyle(.borderedProminent).controlSize(.small)
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
                            .buttonStyle(.borderedProminent).controlSize(.small)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: L("搜索", "Search", nativeLanguage: nativeLanguage))
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
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
