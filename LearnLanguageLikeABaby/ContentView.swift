import SwiftUI
import UIKit


// MARK: - Dynamic Type helper

private func dynSize(_ style: UIFont.TextStyle) -> CGFloat {
    UIFont.preferredFont(forTextStyle: style).pointSize
}


// MARK: - View

struct ContentView: View {
    @ObservedObject var session: LessonSessionModel
    @Binding var showProfile: Bool
    var streakDays:         Int = 0
    var candyBalance:       Int = 0
    @ObservedObject var usageTracker:       UsageTimeTracker   = .init()
    @ObservedObject var achievementManager: AchievementManager = .init()
    var onCollectMilestones: () -> Void = {}
    @State private var showLibraryPicker  = false
    @State private var showSpeedPopover   = false
    @State private var showRepeatsPopover = false
    @State private var archiveExpanded    = false
    @State private var showRingsOverlay   = false
    @State private var showCollectCard    = false

    private static let playbackSpeedSteps: [Double] = Array(stride(from: 0.5, through: 2.0, by: 0.25))

    private var effectiveMinutes: [Int] {[
        usageTracker.todayMinutes     + usageTracker.todayBgMinutes     / 3,
        usageTracker.thisWeekMinutes  + usageTracker.thisWeekBgMinutes  / 3,
        usageTracker.thisMonthMinutes + usageTracker.thisMonthBgMinutes / 3,
        usageTracker.allTimeMinutes   + usageTracker.allTimeBgMinutes   / 3,
    ]}

    private var achievedDimensions: [Bool] {[
        achievementManager.hasPending(for: .daily),
        achievementManager.hasPending(for: .weekly),
        achievementManager.hasPending(for: .monthly),
        achievementManager.hasPending(for: .lifetime),
    ]}

    var body: some View {
        NavigationStack {
            ZStack {
                // ── Background ────────────────────────────────────────────────
                Group {
                    if session.isFavoriteMode          { Color.lllbAccent.opacity(0.10) }
                    else if session.focusedLemma != nil { Color.lllbAccent.opacity(0.10) }
                    else                               { Color.lllbBackground }
                }
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: session.focusedLemma)
                .animation(.easeInOut(duration: 0.3), value: session.isFavoriteMode)

                // ── Archive expanded dismiss layer ────────────────────────────
                if archiveExpanded {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.28)) { archiveExpanded = false }
                        }
                }

                // ── Three-column layout ───────────────────────────────────────
                VStack(spacing: 0) {
                    topBar

                    HStack(alignment: .top, spacing: 0) {
                        leftControls
                            .frame(width: 56)
                            .padding(.top, 16)

                        VStack(spacing: 0) {
                            peekArrow(systemName: "chevron.up")
                            Spacer(minLength: 0)
                            ViewThatFits(in: .vertical) {
                                sentenceArea(scale: 1.50)
                                sentenceArea(scale: 1.30)
                                sentenceArea(scale: 1.15)
                                sentenceArea(scale: 1.00)
                                sentenceArea(scale: 0.85)
                                sentenceArea(scale: 0.70)
                                sentenceArea(scale: 0.55)
                            }
                            .padding(.horizontal, 12)
                            Spacer(minLength: 110)
                            peekArrow(systemName: "chevron.down")
                        }
                        .frame(maxWidth: .infinity)

                        rightColumn
                            .frame(width: 56)
                            .padding(.top, 16)
                    }
                    .padding(.horizontal, 4)
                }

                // ── Floating xmark (focus / favorite / tag mode) ──────────────
                if session.focusedLemma != nil || session.isFavoriteMode || session.activatedTag != nil {
                    VStack {
                        Spacer()
                        Button { session.dismissVoiceBranch() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .font(.title2)
                                .foregroundStyle(Color.lllbAccent)
                                .padding(14)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(.bottom, 32)
                    }
                }

                // ── Profile button (bottom-right, normal mode) ────────────────
                if session.focusedLemma == nil && !session.isFavoriteMode && session.activatedTag == nil {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button { showProfile = true } label: {
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 22, weight: .regular))
                                    .foregroundStyle(Color.lllbAccent)
                                    .frame(width: 44, height: 44)
                                    .background(Color.lllbChipBg, in: Circle())
                                    .overlay(Circle().stroke(Color.lllbChipStroke, lineWidth: 0.5))
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 32)
                        }
                    }
                }

                // ── Tag chips (bottom-center) ─────────────────────────────────
                let currentTags = session.currentSentence.tags
                if !currentTags.isEmpty {
                    VStack {
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(currentTags, id: \.name) { tag in
                                tagChip(tag)
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }

                // ── Play count badge (bottom-left) ────────────────────────────
                VStack {
                    Spacer()
                    HStack {
                        playCountBadge
                            .padding(.leading, 20)
                            .padding(.bottom, 32)
                        Spacer()
                    }
                }

                // ── Library picker overlay ─────────────────────────────────────
                if showLibraryPicker {
                    LibraryPickerView(session: session) {
                        withAnimation(.easeOut(duration: 0.18)) { showLibraryPicker = false }
                    }
                    .transition(.opacity)
                }

                // ── Unlock notice overlay ──────────────────────────────────────
                if !session.pendingUnlockIDs.isEmpty {
                    UnlockNoticeView(
                        sentences:      session.pendingUnlockSentences,
                        nativeLanguage: session.nativeLanguage,
                        onConfirm: {
                            withAnimation(.easeOut(duration: 0.18)) {
                                session.commitPendingUnlock()
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(150)
                }

                // ── Milestone collect card ─────────────────────────────────────
                if showCollectCard {
                    MilestoneCollectCard(
                        milestones:     achievementManager.pendingMilestones,
                        nativeLanguage: session.nativeLanguage,
                        onCollect: {
                            onCollectMilestones()
                            withAnimation(.easeOut(duration: 0.18)) { showCollectCard = false }
                            withAnimation(.easeOut(duration: 0.18)) { showRingsOverlay = true }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(200)
                }

                // ── Progress rings overlay ──────────────────────────────────────
                if showRingsOverlay {
                    ProgressRingsOverlay(
                        progresses:     [
                            achievementManager.progress(for: .daily,    currentMinutes: effectiveMinutes[0]),
                            achievementManager.progress(for: .weekly,   currentMinutes: effectiveMinutes[1]),
                            achievementManager.progress(for: .monthly,  currentMinutes: effectiveMinutes[2]),
                            achievementManager.progress(for: .lifetime, currentMinutes: effectiveMinutes[3]),
                        ],
                        currentMinutes: effectiveMinutes,
                        targetMinutes:  [
                            achievementManager.nextThreshold(for: .daily,    currentMinutes: effectiveMinutes[0]),
                            achievementManager.nextThreshold(for: .weekly,   currentMinutes: effectiveMinutes[1]),
                            achievementManager.nextThreshold(for: .monthly,  currentMinutes: effectiveMinutes[2]),
                            achievementManager.nextThreshold(for: .lifetime, currentMinutes: effectiveMinutes[3]),
                        ],
                        nativeLanguage: session.nativeLanguage,
                        onDismiss:      { withAnimation(.easeOut(duration: 0.18)) { showRingsOverlay = false } }
                    )
                    .transition(.opacity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                        let screenH = UIScreen.main.bounds.height
                        guard value.startLocation.y < screenH - 80 else { return }
                        let dy = value.translation.height
                        if dy < -60      { session.goNextSentence() }
                        else if dy > 60  { session.goPreviousSentence() }
                    }
            )
        }
        .sheet(isPresented: $showSpeedPopover)   { speedSheet }
        .sheet(isPresented: $showRepeatsPopover) { repeatsSheet }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Label("\(streakDays)", systemImage: "flame.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(streakDays > 0
                    ? Color.lllbRingColors[0]   // #F07840 — echoes the "today" ring
                    : Color.lllbSecondaryText)
            HStack(spacing: 3) {
                Text("🍬").font(.system(size: 13))
                Text("\(candyBalance)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.lllbSecondaryText)
            }
            Spacer()
            Button {
                if achievementManager.pendingMilestones.isEmpty {
                    showRingsOverlay = true
                } else {
                    showCollectCard = true
                }
            } label: {
                ProgressRingsSmall(
                    progresses: [
                        achievementManager.progress(for: .daily,    currentMinutes: effectiveMinutes[0]),
                        achievementManager.progress(for: .weekly,   currentMinutes: effectiveMinutes[1]),
                        achievementManager.progress(for: .monthly,  currentMinutes: effectiveMinutes[2]),
                        achievementManager.progress(for: .lifetime, currentMinutes: effectiveMinutes[3]),
                    ],
                    achieved: achievedDimensions
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .frame(height: 36)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.lllbSeparator)
                .frame(height: 0.5)
        }
    }

    // MARK: - Peek arrows

    private func peekArrow(systemName: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: systemName)
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.35))
            Image(systemName: systemName)
                .font(.system(size: 8))
                .foregroundStyle(.secondary.opacity(0.18))
        }
        .padding(.vertical, 10)
    }

    // MARK: - Speed sheet

    private var speedSheet: some View {
        let nl      = session.nativeLanguage
        let current = Self.snappedSpeedStep(session.speedMultiplier)
        return VStack(spacing: 24) {
            Text(L("播放速度", "Playback speed", nativeLanguage: nl)).font(.headline)
            HStack(spacing: 40) {
                Button { stepSpeed(by: -1) } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(canStepSpeed(by: -1) ? Color.lllbAccent : Color.secondary.opacity(0.4))
                }
                .disabled(!canStepSpeed(by: -1)).buttonStyle(.plain)

                Text(Self.formatSpeedDisplay(current))
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .frame(minWidth: 80)

                Button { stepSpeed(by: 1) } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(canStepSpeed(by: 1) ? Color.lllbAccent : Color.secondary.opacity(0.4))
                }
                .disabled(!canStepSpeed(by: 1)).buttonStyle(.plain)
            }
        }
        .padding(.vertical, 32).frame(maxWidth: .infinity)
        .presentationDetents([.height(160)]).presentationDragIndicator(.visible)
    }

    // MARK: - Repeats sheet

    private var repeatsSheet: some View {
        let nl      = session.nativeLanguage
        let current = session.repeatsBeforeAdvance
        return VStack(spacing: 24) {
            Text(L("重复遍数", "Repeats", nativeLanguage: nl)).font(.headline)
            HStack(spacing: 40) {
                Button { session.repeatsBeforeAdvance = max(1, current - 1) } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(current > 1 ? Color.lllbAccent : Color.secondary.opacity(0.4))
                }
                .disabled(current <= 1).buttonStyle(.plain)

                Text("\(current)")
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .frame(minWidth: 60)

                Button { session.repeatsBeforeAdvance = min(10, current + 1) } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(current < 10 ? Color.lllbAccent : Color.secondary.opacity(0.4))
                }
                .disabled(current >= 10).buttonStyle(.plain)
            }
        }
        .padding(.vertical, 32).frame(maxWidth: .infinity)
        .presentationDetents([.height(160)]).presentationDragIndicator(.visible)
    }

    // MARK: - Speed helpers

    private func stepSpeed(by delta: Int) {
        let idx  = Self.speedStepIndex(for: session.speedMultiplier)
        let next = min(Self.playbackSpeedSteps.count - 1, max(0, idx + delta))
        session.applySpeed(Self.playbackSpeedSteps[next])
    }

    private func canStepSpeed(by delta: Int) -> Bool {
        let idx = Self.speedStepIndex(for: session.speedMultiplier)
        return (idx + delta) >= 0 && (idx + delta) < Self.playbackSpeedSteps.count
    }

    private static func snappedSpeedStep(_ v: Double) -> Double {
        playbackSpeedSteps.min(by: { abs($0 - v) < abs($1 - v) }) ?? 1.0
    }
    private static func speedStepIndex(for v: Double) -> Int {
        let s = snappedSpeedStep(v)
        return playbackSpeedSteps.firstIndex(where: { abs($0 - s) < 0.001 }) ?? 2
    }
    private static func formatSpeedDisplay(_ v: Double) -> String {
        let r = (v * 4).rounded() / 4
        if abs(r - 1) < 0.001 { return "1×" }
        if abs(r - 2) < 0.001 { return "2×" }
        return abs(r * 2 - floor(r * 2 + 0.0001)) < 0.001
            ? String(format: "%.1f×", r)
            : String(format: "%.2f×", r)
    }

    // MARK: - Left controls

    private var leftControls: some View {
        let nl = session.nativeLanguage
        return VStack(spacing: 10) {

            // Play mode (shuffle / sequential / single-loop)
            Button { session.cyclePlayMode() } label: {
                let (icon, label): (String, String) = {
                    switch session.playMode {
                    case .shuffle:    return ("shuffle",  L("随机", "Shuffle", nativeLanguage: nl))
                    case .sequential: return ("repeat",   L("顺序", "Order",   nativeLanguage: nl))
                    case .singleLoop: return ("repeat.1", L("单曲", "Loop 1", nativeLanguage: nl))
                    }
                }()
                controlCell(
                    icon:     icon,
                    label:    label,
                    isActive: session.playMode != .shuffle
                )
            }
            .buttonStyle(.plain)

            // Library
            Button { withAnimation(.easeOut(duration: 0.18)) { showLibraryPicker = true } } label: {
                controlCell(icon: "books.vertical", label: L("库", "Library", nativeLanguage: nl))
            }
            .buttonStyle(.plain)

            // Favorites mode
            Button {
                if session.isFavoriteMode { session.dismissVoiceBranch() }
                else                      { session.enterFavoriteMode() }
            } label: {
                controlCell(
                    icon:        session.isFavoriteMode ? "star.fill" : "star",
                    label:       L("收藏", "Fav", nativeLanguage: nl),
                    isActive:    session.isFavoriteMode,
                    activeColor: .yellow
                )
            }
            .buttonStyle(.plain)

            // Speed
            Button { showSpeedPopover = true } label: {
                VStack(spacing: 3) {
                    Text(Self.formatSpeedDisplay(Self.snappedSpeedStep(session.speedMultiplier)))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.primary)
                    Text(L("速度", "Speed", nativeLanguage: nl)).font(.caption2)
                        .foregroundStyle(Color.lllbSecondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lllbCellStroke, lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            // Repeats
            Button { showRepeatsPopover = true } label: {
                VStack(spacing: 3) {
                    Text("\(session.repeatsBeforeAdvance)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.primary)
                    Text(L("遍数", "Repeats", nativeLanguage: nl)).font(.caption2)
                        .foregroundStyle(Color.lllbSecondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lllbCellStroke, lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            // Play / Pause
            Button {
                if session.isAutoPlaying { session.pause() } else { session.resume() }
            } label: {
                controlCell(
                    icon:  session.isAutoPlaying ? "pause.fill" : "play.fill",
                    label: session.isAutoPlaying
                        ? L("暂停", "Pause", nativeLanguage: nl)
                        : L("播放", "Play",  nativeLanguage: nl)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Right column

    private var rightColumn: some View {
        let nl = session.nativeLanguage
        return VStack(spacing: 7) {
            toggleCell(L("图片", "Pic",  nativeLanguage: nl), icon: "photo",          on: $session.showImage)
            toggleCell(L("拼写", "Text", nativeLanguage: nl), icon: "textformat.abc",  on: $session.showSpelling)
            toggleCell(L("音标", "IPA",  nativeLanguage: nl), icon: "waveform",        on: $session.showIPA)
            toggleCell(L("翻译", "Tr.",  nativeLanguage: nl), icon: "globe",           on: $session.showTranslation)
            translationModeCell(nativeLanguage: nl)

            if session.config.id != "zh" {
                let isSingle = session.currentSentence.text.split(separator: " ").count == 1
                ZStack(alignment: .topTrailing) {
                    toggleCell(L("字母", "Spell", nativeLanguage: nl), icon: "a.circle", on: $session.spellMode)
                    if isSingle {
                        Circle()
                            .fill(session.spellMode ? Color.lllbSelectedFg : Color.lllbSecondaryText)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                            .padding(.trailing, 6)
                    }
                }
            }

            let isFav      = session.favoritedIDs.contains(session.currentSentence.id)
            let isFamiliar = session.familiarIDs.contains(session.currentSentence.id)

            Button { session.toggleFavorite(for: session.currentSentence.id) } label: {
                controlCell(
                    icon:        isFav ? "heart.fill" : "heart",
                    label:       L("喜欢", "Like", nativeLanguage: nl),
                    isActive:    isFav,
                    activeColor: .red
                )
            }
            .buttonStyle(.plain)

            Button { session.toggleFamiliar() } label: {
                controlCell(
                    icon:        isFamiliar ? "checkmark.circle.fill" : "checkmark.circle",
                    label:       L("熟悉", "Familiar", nativeLanguage: nl),
                    isActive:    isFamiliar,
                    activeColor: .green
                )
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.spring(response: 0.28)) { archiveExpanded.toggle() }
            } label: {
                controlCell(icon: "archivebox", label: L("存档", "Archive", nativeLanguage: nl), isActive: archiveExpanded)
            }
            .buttonStyle(.plain)
            .frame(width: 56)
            .overlay(alignment: .leading) {
                if archiveExpanded {
                    VStack(spacing: 6) {
                        Button {
                            session.archiveCurrentSentence(as: .mastered)
                            withAnimation(.spring(response: 0.28)) { archiveExpanded = false }
                        } label: {
                            controlCell(icon: "checkmark.seal", label: L("学会了", "Known", nativeLanguage: nl))
                        }
                        .buttonStyle(.plain)

                        Button {
                            session.archiveCurrentSentence(as: .later)
                            withAnimation(.spring(response: 0.28)) { archiveExpanded = false }
                        } label: {
                            controlCell(icon: "clock", label: L("稍后学", "Later", nativeLanguage: nl))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 56)
                    .offset(x: -(56 + 6))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .onChange(of: session.currentSentence.id) { _ in
            withAnimation { archiveExpanded = false }
        }
    }

    // MARK: - Shared cell shapes

    /// Standard control cell. Transparent background with 0.5pt stroke.
    /// Active state: accent tint bg + accent stroke + accent foreground.
    @ViewBuilder
    private func controlCell(
        icon:        String,
        label:       String,
        isActive:    Bool  = false,
        activeColor: Color = .lllbAccent
    ) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.title3)
            Text(label).font(.caption2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .foregroundStyle(isActive ? activeColor : Color.lllbSecondaryText)
        .background(isActive ? activeColor.opacity(0.10) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? activeColor.opacity(0.30) : Color.lllbCellStroke, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func translationModeCell(nativeLanguage nl: String) -> some View {
        let mode     = session.translationPlaybackMode
        let isActive = mode != .off
        let (icon, label): (String, String) = {
            switch mode {
            case .off:    return ("character.bubble",       L("译音", "Tr.", nativeLanguage: nl))
            case .before: return ("arrow.up.circle.fill",   L("译前", "Pre", nativeLanguage: nl))
            case .after:  return ("arrow.down.circle.fill", L("译后", "Post", nativeLanguage: nl))
            }
        }()
        Button {
            switch session.translationPlaybackMode {
            case .off:    session.translationPlaybackMode = .before
            case .before: session.translationPlaybackMode = .after
            case .after:  session.translationPlaybackMode = .off
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.title3)
                Text(label).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(isActive ? Color.lllbSelectedFg : Color.lllbSecondaryText)
            .background(isActive ? Color.lllbSelectedBg : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? Color.lllbSelectedStroke : Color.lllbCellStroke, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func toggleCell(_ label: String, icon: String, on: Binding<Bool>) -> some View {
        Button { on.wrappedValue.toggle() } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.title3)
                Text(label).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(on.wrappedValue ? Color.lllbSelectedFg : Color.lllbSecondaryText)
            .background(on.wrappedValue ? Color.lllbSelectedBg : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(on.wrappedValue ? Color.lllbSelectedStroke : Color.lllbCellStroke, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var playCountBadge: some View {
        let count = session.currentSentencePlayCount
        if count > 0 {
            let color: Color = count < 20 ? Color.lllbRingColors[0]      // 橙
                             : count < 50 ? Color.lllbRingColors[1]      // 绿
                             : count < 100 ? Color.lllbRingColors[2]     // 蓝
                                           : Color.lllbRingColors[3]     // 金
            Text("▶ \(count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(color)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(color.opacity(0.1))
                .clipShape(Capsule())
        }
    }

    // MARK: - Sentence area

    @ViewBuilder
    private func sentenceArea(scale: CGFloat) -> some View {
        let s  = session.currentSentence
        let nl = session.nativeLanguage
        VStack(spacing: 16 * scale) {
            // Favorite mode indicator
            if session.isFavoriteMode, let playlist = session.examplePlaylist {
                HStack {
                    Image(systemName: "heart.fill").foregroundStyle(Color.lllbAccent)
                    Text("\(session.exampleIndex + 1)/\(playlist.count)")
                        .font(.system(size: dynSize(.caption1) * scale, weight: .semibold))
                        .foregroundStyle(Color.lllbAccent.opacity(0.7))
                    Spacer()
                }
                .padding(.bottom, 4 * scale)
            }

            // Focus mode header
            if let lemma = session.focusedLemma {
                HStack(spacing: 8 * scale) {
                    Text(session.focusedTokenText)
                        .font(.system(size: dynSize(.title1) * scale, weight: .bold))
                        .foregroundStyle(Color.lllbAccent)
                    Text("·").foregroundStyle(Color.lllbAccent.opacity(0.5))
                    Text(lemma)
                        .font(.system(size: dynSize(.title3) * scale))
                        .foregroundStyle(Color.lllbAccent.opacity(0.7))
                    Spacer()
                    if let playlist = session.examplePlaylist {
                        Text("\(session.exampleIndex + 1)/\(playlist.count)")
                            .font(.system(size: dynSize(.caption1) * scale, weight: .semibold))
                            .foregroundStyle(Color.lllbAccent.opacity(0.7))
                    }
                }
                .padding(.bottom, 4 * scale)
            }

            if let err = session.loadError {
                Text(L("无法加载句库：", "Could not load sentences: ", nativeLanguage: nl) + err)
                    .foregroundStyle(.red).multilineTextAlignment(.center)
            }

            if session.showIPA, !session.isFamiliarSuppressed, !s.ipa.isEmpty {
                Text("/ \(s.ipa) /")
                    .font(.system(size: dynSize(.subheadline) * scale))
                    .foregroundStyle(Color.lllbSecondaryText)
                    .multilineTextAlignment(.center)
            }

            let sentenceTr = s.translation.resolvedTranslation(nativeLanguage: session.nativeLanguage)
            if session.showTranslation, !session.isFamiliarSuppressed, !sentenceTr.isEmpty {
                Text(sentenceTr)
                    .font(.system(size: dynSize(.headline) * scale, weight: .semibold))
                    .foregroundStyle(Color.lllbSecondaryText)
                    .multilineTextAlignment(.center)
            }

            TokenFlowLayout(spacing: 10 * scale, runSpacing: 14 * scale) {
                ForEach(Array(s.tokens.enumerated()), id: \.offset) { idx, token in
                    tokenChip(token: token, index: idx,
                              highlighted: idx == session.narration.highlightedTokenIndex,
                              scale: scale)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Token chip

    @ViewBuilder
    private func tokenChip(token: TokenChunk, index: Int, highlighted: Bool, scale: CGFloat) -> some View {
        let display            = token.text.trimmingCharacters(in: .whitespaces)
        let showEmoji          = session.showImage && !token.emoji.isEmpty
        let showFallbackText   = !showEmoji && !display.isEmpty
        let familiar           = session.isFamiliarSuppressed
        let showSpell          = session.showSpelling && !familiar && !display.isEmpty
        let showTokIPA         = session.showIPA && !familiar && (token.ipa?.isEmpty == false)
        let showTokTr          = session.showTranslation && !familiar &&
            !token.translation.resolvedTranslation(nativeLanguage: session.nativeLanguage).isEmpty
        let tokenLemmaForFocus = token.lemma ?? display
        let isFocusedToken     = session.focusedLemma != nil && tokenLemmaForFocus == session.focusedLemma

        // Outline-only active states: keep chip bg, boost stroke, leave text primary
        let chipBg     = Color.lllbChipBg
        let chipStroke: Color = isFocusedToken ? Color.lllbAccent :
                                highlighted    ? Color.lllbAccent.opacity(0.75) :
                                                 Color.lllbChipStroke
        let chipStrokeWidth: CGFloat = isFocusedToken ? 1.8 : highlighted ? 1.5 : 0.5
        let spellingColor: Color     = Color.primary

        VStack(alignment: .center, spacing: 6 * scale) {
            if showEmoji {
                Text(token.emoji).font(.system(size: 44 * scale))
            }
            if showFallbackText && !showSpell {
                Text(display).font(.system(size: 44 * scale))
                    .foregroundStyle(Color.lllbSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            if showSpell {
                Text(display)
                    .font(.system(size: dynSize(.title3) * scale, weight: .medium))   // §3: medium weight
                    .foregroundStyle(spellingColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            if showTokIPA, let ipa = token.ipa {
                Text("/\(ipa)/")
                    .font(.system(size: dynSize(.caption1) * scale).italic())          // §3: italic IPA
                    .foregroundStyle(Color.lllbSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if showTokTr {
                Text(token.translation.resolvedTranslation(nativeLanguage: session.nativeLanguage))
                    .font(.system(size: dynSize(.caption1) * scale))
                    .foregroundStyle(Color.lllbSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 12 * scale)
        .padding(.vertical, 10 * scale)
        .background(RoundedRectangle(cornerRadius: 12).fill(chipBg))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(chipStroke, lineWidth: chipStrokeWidth))
        .simultaneousGesture(
            TapGesture().onEnded {
                if session.focusedLemma == tokenLemmaForFocus { session.dismissVoiceBranch() }
                else                                          { session.focusOnToken(token) }
            }
        )
    }

    // MARK: - Tag chip (§5)

    @ViewBuilder
    private func tagChip(_ tag: SentenceTag) -> some View {
        let isActive = session.activatedTag == tag.name
        Button {
            if isActive { session.dismissVoiceBranch() }
            else        { session.activateTag(tag.name) }
        } label: {
            Text(tag.name)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundStyle(isActive ? Color.lllbAccent : Color.lllbSecondaryText)
                .background(isActive ? Color.lllbAccent.opacity(0.10) : Color.lllbTagBg)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        isActive ? Color.lllbAccent.opacity(0.28) : Color.lllbTagStroke,
                        lineWidth: 0.5
                    )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Unlock notice overlay

private struct UnlockNoticeView: View {
    let sentences:      [LessonSentence]
    let nativeLanguage: String
    let onConfirm:      () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text(L("解锁了 \(sentences.count) 个新句子",
                       "\(sentences.count) New Sentence\(sentences.count == 1 ? "" : "s") Unlocked",
                       nativeLanguage: nativeLanguage))
                    .font(.headline)
                    .padding(.top, 22)
                    .padding(.bottom, 14)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(sentences) { sentence in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top) {
                                    Text(sentence.text)
                                        .font(.body.weight(.medium))
                                    Spacer()
                                    Text(sentence.cefr)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.lllbTagBg)
                                        .clipShape(Capsule())
                                }
                                let tr = sentence.translation.resolvedTranslation(nativeLanguage: nativeLanguage)
                                if !tr.isEmpty {
                                    Text(tr)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.04),
                                        in: RoundedRectangle(cornerRadius: 11))
                        }
                    }
                    .padding(.horizontal, 18)
                }
                .frame(maxHeight: 320)

                Button(action: onConfirm) {
                    Text(L("知道了", "Got it", nativeLanguage: nativeLanguage))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.lllbAccent, in: RoundedRectangle(cornerRadius: 13))
                        .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 22)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 28)
        }
    }
}
