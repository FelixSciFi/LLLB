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
    var candyBalance:       Int = 0
    @ObservedObject var usageTracker:       UsageTimeTracker   = .init()
    @ObservedObject var achievementManager: AchievementManager = .init()
    @ObservedObject var playbackBudget:     PlaybackBudget     = .init()
    var onboardingCompleted: Bool = true
    var onCollectMilestones: () -> Void = {}
    var onUseCandyForRefill: () -> Void = {}
    var onTopUpForRefill:    (Int) -> Void = { _ in }
    var onWatchAdForRefill:  () -> Void = {}
    var onOpenSubscribe:     () -> Void = {}
    @State private var showLibraryPicker  = false
    @State private var showSpeedPopover   = false
    @State private var showRepeatsPopover = false
    @State private var archiveExpanded    = false
    @State private var showRingsOverlay   = false
    @State private var showCollectCard    = false
    @State private var showCelebration    = false
    @State private var showRefillMenu     = false
    @State private var placementModel:    PlacementTestModel? = nil

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
                            // Force a fresh view tree on every sentence change so the
                            // crossfade transition fires (instead of in-place re-render).
                            .id(session.currentSentence.id)
                            .transition(.opacity)
                            .animation(.easeOut(duration: 0.22), value: session.currentSentence.id)
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
                        .buttonStyle(.plain)
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
                            .buttonStyle(.plain)
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

                // ── Unlock picker overlay ──────────────────────────────────────
                if !session.pendingCandidateGroups.isEmpty {
                    UnlockPickerView(
                        groups:         session.pendingCandidateSentences,
                        remaining:      session.pendingPicksRemaining,
                        nativeLanguage: session.nativeLanguage,
                        onPick: { idx in
                            Haptics.success()
                            withAnimation(.easeOut(duration: 0.18)) {
                                session.pickCandidate(at: idx)
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
                            Haptics.success()
                            onCollectMilestones()
                            withAnimation(.easeOut(duration: 0.18)) { showCollectCard = false }
                            // Quick celebration burst, then reveal the rings overlay.
                            showCelebration = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                                showCelebration = false
                                withAnimation(.easeOut(duration: 0.18)) { showRingsOverlay = true }
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(200)
                }

                if showCelebration {
                    MilestoneBurst()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .zIndex(220)
                }

                if showRefillMenu {
                    refillMenuOverlay
                        .transition(.opacity)
                        .zIndex(240)
                }

                // ── Progress rings overlay ──────────────────────────────────────
                if showRingsOverlay {
                    let activeMins:  [Int] = [
                        usageTracker.todayMinutes,    usageTracker.thisWeekMinutes,
                        usageTracker.thisMonthMinutes, usageTracker.allTimeMinutes,
                    ]
                    let passiveMins: [Int] = [
                        usageTracker.todayBgMinutes,    usageTracker.thisWeekBgMinutes,
                        usageTracker.thisMonthBgMinutes, usageTracker.allTimeBgMinutes,
                    ]
                    ProgressRingsOverlay(
                        progresses:     [
                            achievementManager.progress(for: .daily,    currentMinutes: effectiveMinutes[0]),
                            achievementManager.progress(for: .weekly,   currentMinutes: effectiveMinutes[1]),
                            achievementManager.progress(for: .monthly,  currentMinutes: effectiveMinutes[2]),
                            achievementManager.progress(for: .lifetime, currentMinutes: effectiveMinutes[3]),
                        ],
                        currentMinutes: effectiveMinutes,
                        activeMinutes:  activeMins,
                        passiveMinutes: passiveMins,
                        targetMinutes:  [
                            achievementManager.nextThreshold(for: .daily,    currentMinutes: effectiveMinutes[0]),
                            achievementManager.nextThreshold(for: .weekly,   currentMinutes: effectiveMinutes[1]),
                            achievementManager.nextThreshold(for: .monthly,  currentMinutes: effectiveMinutes[2]),
                            achievementManager.nextThreshold(for: .lifetime, currentMinutes: effectiveMinutes[3]),
                        ],
                        nativeLanguage:    session.nativeLanguage,
                        achievementManager: achievementManager,
                        onDismiss:         { withAnimation(.easeOut(duration: 0.18)) { showRingsOverlay = false } }
                    )
                    .transition(.opacity)
                }

                // ── Placement test (first launch, big-enough libraries) ─────────
                if let pm = placementModel {
                    PlacementTestView(
                        model: pm,
                        onSkip: {
                            session.seedPool(allocation: session.defaultBeginnerAllocation())
                            session.ensurePoolFilled()
                            session.markPlacementShown()
                            placementModel = nil
                            session.isActive = true   // didSet → startFresh()
                        },
                        onConfirm: { result in
                            session.seedPool(allocation: result.allocation)
                            session.ensurePoolFilled()
                            session.markPlacementShown()
                            placementModel = nil
                            session.isActive = true   // didSet → startFresh()
                        }
                    )
                    .transition(.opacity)
                    .zIndex(300)
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
            // Re-fires both when the active language switches AND when onboarding
            // completes — the second case is what lets us defer placement / TTS
            // activation until the user has actually finished picking languages.
            .onChange(of: session.didHitBudgetLimit) { hit in
                guard hit else { return }
                showRefillMenu = true
                session.didHitBudgetLimit = false
            }
            .task(id: "\(session.id)-\(onboardingCompleted)") {
                placementModel = nil

                // Don't run any of this while the welcome/language-picker overlay
                // is still up: ContentView is mounted underneath it, but we don't
                // want to seed pools, show placement, or activate playback yet.
                guard onboardingCompleted else { return }

                // Placement test only triggers if (a) never offered before AND
                // (b) library is big enough to actually need calibration. For tiny
                // libraries (size <= capacity) cascade-fill already gives them
                // the whole library, no point asking levels.
                let needsPlacement = !session.wasPlacementShown
                    && session.mainSentences.count > session.poolCapacity
                let qs: [PlacementQuestion] = needsPlacement
                    ? SentenceLibrary.loadPlacementQuestions(language: session.config.id)
                    : []

                if needsPlacement, !qs.isEmpty {
                    // Don't ensurePoolFilled here — that uses the proportional
                    // unlock selector, which has a floor weight for every CEFR
                    // level and would inject C1/C2 sentences into a fresh pool
                    // *before* placement gets to seed it properly. Placement's
                    // onConfirm / onSkip seeds the pool from scratch.
                    placementModel = PlacementTestModel(
                        questions: qs,
                        nativeLanguage: session.nativeLanguage,
                        levelOrder: session.config.levelOrder
                    )
                } else {
                    if needsPlacement { session.markPlacementShown() }
                    // Self-heal: top up to capacity for returning users (no-op if
                    // already filled). Safe here because the user's placement-driven
                    // allocation is already represented in the existing pool.
                    session.ensurePoolFilled()
                    session.isActive = true   // didSet → startFresh()
                }
            }
        }
        .sheet(isPresented: $showSpeedPopover)   { speedSheet }
        .sheet(isPresented: $showRepeatsPopover) { repeatsSheet }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            coffeeCupButton
            streakLabel
            CandyBalanceLabel(balance: candyBalance)
            Spacer()
            Button {
                Haptics.light()
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
                Button {
                    guard current > 1 else { return }
                    Haptics.light()
                    session.repeatsBeforeAdvance = current - 1
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(current > 1 ? Color.lllbAccent : Color.secondary.opacity(0.4))
                }
                .disabled(current <= 1).buttonStyle(.plain)

                Text("\(current)")
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .frame(minWidth: 60)

                Button {
                    guard current < 10 else { return }
                    Haptics.light()
                    session.repeatsBeforeAdvance = current + 1
                } label: {
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
        guard next != idx else { return }
        Haptics.light()
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
    /// Bare number without unit, for the inline "速度 N" button label.
    private static func formatSpeedNumber(_ v: Double) -> String {
        let r = (v * 4).rounded() / 4
        if abs(r - 1) < 0.001 { return "1" }
        if abs(r - 2) < 0.001 { return "2" }
        return abs(r * 2 - floor(r * 2 + 0.0001)) < 0.001
            ? String(format: "%.1f", r)
            : String(format: "%.2f", r)
    }
    /// Number with `×` suffix, for the speed-picker popover's big readout.
    private static func formatSpeedDisplay(_ v: Double) -> String {
        formatSpeedNumber(v) + "×"
    }

    // MARK: - Left controls

    private var leftControls: some View {
        let nl = session.nativeLanguage
        return VStack(spacing: 10) {

            // Play mode (shuffle / sequential / single-loop)
            Button { Haptics.light(); session.cyclePlayMode() } label: {
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
            Button {
                Haptics.light()
                withAnimation(.easeOut(duration: 0.18)) { showLibraryPicker = true }
            } label: {
                controlCell(icon: "books.vertical", label: L("库", "Library", nativeLanguage: nl))
            }
            .buttonStyle(.plain)

            // Favorites mode
            Button {
                Haptics.medium()
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

            // Speed — number on left, fixed speedometer icon on right.
            // Width is language-agnostic since both are non-text glyphs.
            Button { Haptics.light(); showSpeedPopover = true } label: {
                HStack(spacing: 4) {
                    Text(Self.formatSpeedNumber(Self.snappedSpeedStep(session.speedMultiplier)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Image(systemName: "speedometer")
                        .font(.footnote)
                        .foregroundStyle(Color.lllbSecondaryText)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lllbCellStroke, lineWidth: 0.5))
                .accessibilityLabel(L("速度", "Speed", nativeLanguage: nl))
            }
            .buttonStyle(.plain)

            // Repeats — number on left, circular-arrow icon on right.
            // Using `arrow.clockwise` (single ↻) instead of `repeat` so it
            // doesn't visually clash with the play-mode sequential icon.
            Button { Haptics.light(); showRepeatsPopover = true } label: {
                HStack(spacing: 4) {
                    Text("\(session.repeatsBeforeAdvance)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Image(systemName: "arrow.clockwise")
                        .font(.footnote)
                        .foregroundStyle(Color.lllbSecondaryText)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lllbCellStroke, lineWidth: 0.5))
                .accessibilityLabel(L("遍数", "Repeats", nativeLanguage: nl))
            }
            .buttonStyle(.plain)

            // Play / Pause
            Button {
                Haptics.medium()
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
            toggleCell(L("文字", "Text", nativeLanguage: nl), icon: "textformat.abc",  on: $session.showSpelling)
            toggleTextCell(L("音标", "IPA",  nativeLanguage: nl), on: $session.showIPA)
            toggleCell(L("翻译", "Tr.",  nativeLanguage: nl), icon: "globe",           on: $session.showTranslation)
            translationModeCell(nativeLanguage: nl)

            if session.config.id != "zh" {
                let isSingle = session.currentSentence.text.split(separator: " ").count == 1
                ZStack(alignment: .topTrailing) {
                    toggleTextCell(L("拼写", "Spell", nativeLanguage: nl), on: $session.spellMode)
                    if isSingle {
                        Circle()
                            .fill(session.spellMode ? Color.lllbSelectedFg : Color.lllbSecondaryText)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                            .padding(.trailing, 6)
                    }
                }
            } else if StrokeWriterFeature.shouldShowButton(isChinese: true) {
                let canRender = StrokeWriterFeature.canRender(
                    text: session.currentSentence.tokens.first?.text ?? "",
                    tokenCount: session.currentSentence.tokens.count,
                    isChinese: true
                )
                toggleTextCell(L("书写", "Write", nativeLanguage: nl), on: $session.writeMode)
                    .opacity(canRender ? 1.0 : 0.4)
                    .allowsHitTesting(canRender)
            }

            let isFav      = session.favoritedIDs.contains(session.currentSentence.id)
            let isFamiliar = session.familiarIDs.contains(session.currentSentence.id)

            LikeButton(
                isFav: isFav,
                label: L("喜欢", "Like", nativeLanguage: nl),
                onTap: {
                    Haptics.success()
                    session.toggleFavorite(for: session.currentSentence.id)
                }
            )

            Button { Haptics.success(); session.toggleFamiliar() } label: {
                controlCell(
                    icon:        isFamiliar ? "checkmark.circle.fill" : "checkmark.circle",
                    label:       L("熟悉", "Familiar", nativeLanguage: nl),
                    showLabel:   true,
                    isActive:    isFamiliar,
                    activeColor: .green
                )
            }
            .buttonStyle(.plain)

            Button {
                Haptics.light()
                withAnimation(.spring(response: 0.28)) { archiveExpanded.toggle() }
            } label: {
                controlCell(icon: "archivebox", label: L("存档", "Archive", nativeLanguage: nl), showLabel: true, isActive: archiveExpanded)
            }
            .buttonStyle(.plain)
            .frame(width: 56)
            .overlay(alignment: .leading) {
                if archiveExpanded {
                    VStack(spacing: 6) {
                        Button {
                            Haptics.success()
                            session.archiveCurrentSentence(as: .mastered)
                            withAnimation(.spring(response: 0.28)) { archiveExpanded = false }
                        } label: {
                            controlCell(icon: "checkmark.seal", label: L("学会了", "Known", nativeLanguage: nl), showLabel: true)
                        }
                        .buttonStyle(.plain)

                        Button {
                            Haptics.success()
                            session.archiveCurrentSentence(as: .later)
                            withAnimation(.spring(response: 0.28)) { archiveExpanded = false }
                        } label: {
                            controlCell(icon: "clock", label: L("稍后学", "Later", nativeLanguage: nl), showLabel: true)
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
        showLabel:   Bool  = false,
        isActive:    Bool  = false,
        activeColor: Color = .lllbAccent
    ) -> some View {
        Group {
            if showLabel {
                VStack(spacing: 3) {
                    Image(systemName: icon).font(.title3)
                    Text(label).font(.caption2)
                }
            } else {
                Image(systemName: icon).font(.title3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, showLabel ? 6 : 12)
        .foregroundStyle(isActive ? activeColor : Color.lllbSecondaryText)
        .background(isActive ? activeColor.opacity(0.10) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? activeColor.opacity(0.30) : Color.lllbCellStroke, lineWidth: 0.5)
        )
        .accessibilityLabel(label)
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
            Haptics.soft()
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
        Button { Haptics.soft(); on.wrappedValue.toggle() } label: {
            Image(systemName: icon)
                .font(.title3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(on.wrappedValue ? Color.lllbSelectedFg : Color.lllbSecondaryText)
                .background(on.wrappedValue ? Color.lllbSelectedBg : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(on.wrappedValue ? Color.lllbSelectedStroke : Color.lllbCellStroke, lineWidth: 0.5)
                )
                .accessibilityLabel(label)
        }
        .buttonStyle(.plain)
    }

    /// Text-only toggle (for buttons where a word is clearer than an icon).
    /// Same shape/active-state visuals as `toggleCell` so the columns stay
    /// uniform.
    @ViewBuilder
    private func toggleTextCell(_ text: String, on: Binding<Bool>) -> some View {
        Button { Haptics.soft(); on.wrappedValue.toggle() } label: {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
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

        let isMultiWord = display.contains(" ")
        VStack(alignment: .center, spacing: 6 * scale) {
            if showEmoji {
                Text(token.emoji).font(.system(size: 44 * scale))
            }
            if showFallbackText && !showSpell {
                if isMultiWord {
                    Text(display).font(.system(size: 44 * scale))
                        .foregroundStyle(Color.lllbSecondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(display).font(.system(size: 44 * scale))
                        .foregroundStyle(Color.lllbSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            if showSpell {
                if isMultiWord {
                    Text(display)
                        .font(.system(size: dynSize(.title3) * scale, weight: .medium))
                        .foregroundStyle(spellingColor)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(display)
                        .font(.system(size: dynSize(.title3) * scale, weight: .medium))
                        .foregroundStyle(spellingColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            if session.config.id == "zh"
                && session.writeMode
                && !familiar
                && session.currentSentence.tokens.count == 1
                && StrokeWriterFeature.canRender(text: display, tokenCount: 1, isChinese: true) {
                let trText = session.currentSentence.tokens
                    .map { $0.translation.resolvedTranslation(nativeLanguage: session.nativeLanguage) }
                    .joined()
                let mode = StrokeWriterFeature.mode(
                    text: display,
                    tokenCount: 1,
                    repeats: session.repeatsBeforeAdvance,
                    hasTranslation: session.translationPlaybackMode != .off,
                    translationCharCount: trText.count,
                    speedMultiplier: session.speedMultiplier,
                    isSingleLoopMode: session.playMode == .singleLoop
                )
                HanziStrokeView(text: display, mode: mode)
                    .frame(height: 140 * scale)
                    .id("\(session.currentSentence.id)-\(display)")
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
        // Subtle pulse on each TTS highlight — chip nudges up to 1.05 then settles.
        // Spring with low damping gives that "tapped on the beat" feel synced to playback.
        .scaleEffect(highlighted ? 1.05 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.55), value: highlighted)
        .simultaneousGesture(
            TapGesture().onEnded {
                Haptics.light()
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
            Haptics.light()
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

    // MARK: - Refill menu

    @ViewBuilder
    private var refillMenuOverlay: some View {
        CoffeeRefillMenu(
            nativeLanguage: session.nativeLanguage,
            candyBalance:   candyBalance,
            cupMinutes:     playbackBudget.cupMinutes,
            canRefillSingle: playbackBudget.canRefillSingle,
            canTopUp:        playbackBudget.canTopUp,
            topUpCost:       playbackBudget.topUpCost,
            isPremium:       playbackBudget.isPremium,
            onUseCandy: {
                Haptics.success()
                onUseCandyForRefill()
                showRefillMenu = false
            },
            onTopUp: {
                Haptics.success()
                onTopUpForRefill(playbackBudget.topUpCost)
                showRefillMenu = false
            },
            onWatchAd: {
                Haptics.medium()
                onWatchAdForRefill()
                showRefillMenu = false
            },
            onSubscribe: {
                Haptics.medium()
                showRefillMenu = false
                onOpenSubscribe()
            },
            onClose: { showRefillMenu = false }
        )
    }

    // MARK: - Coffee cup (playback budget)

    private var coffeeCupButton: some View {
        return CoffeeCupView(progress: playbackBudget.progress(), isPremium: playbackBudget.isPremium, size: 26)
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.light()
                showRefillMenu = true
            }
    }

    // MARK: - Streak label (tiered)

    @ViewBuilder
    private var streakLabel: some View {
        // Visual reward grows with streak length: bigger / hotter / glowing.
        let tier: (size: CGFloat, color: Color, glow: CGFloat) = {
            switch usageTracker.streakDays {
            case 0:        return (13, Color.lllbSecondaryText,  0)
            case 1...6:    return (13, Color.lllbRingColors[0],  0)   // orange
            case 7...29:   return (15, Color.lllbRingColors[0],  0)
            case 30...99:  return (16, Color(red: 0.95, green: 0.40, blue: 0.20), 3)
            default:       return (17, Color(red: 0.95, green: 0.25, blue: 0.10), 5)
            }
        }()
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: tier.size, weight: .semibold))
                .foregroundStyle(tier.color)
                .shadow(color: tier.glow > 0 ? tier.color.opacity(0.55) : .clear,
                        radius: tier.glow)
            Text("\(usageTracker.streakDays)")
                .font(.system(size: tier.size - 1, weight: .semibold))
                .foregroundStyle(tier.color)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.45, dampingFraction: 0.7), value: usageTracker.streakDays)
        }
    }
}

// MARK: - Milestone celebration burst

/// 12 small dots in the brand ring colors radiate from screen center, drift
/// outward, and fade. ~0.55s total. A single accent ring expands underneath.
private struct MilestoneBurst: View {
    @State private var dotProgress:  CGFloat = 0
    @State private var ringScale:    CGFloat = 0.4
    @State private var ringOpacity:  Double  = 0

    private static let particles: [(angle: Double, radius: CGFloat, color: Color)] = {
        let colors = Color.lllbRingColors
        return (0..<14).map { i in
            let angle = Double(i) * (360.0 / 14.0) + Double.random(in: -8...8)
            let radius = CGFloat.random(in: 95...140)
            let color = colors[i % colors.count]
            return (angle, radius, color)
        }
    }()

    var body: some View {
        ZStack {
            // Expanding accent ring underneath
            Circle()
                .stroke(Color.lllbAccent.opacity(ringOpacity), lineWidth: 3)
                .frame(width: 80, height: 80)
                .scaleEffect(ringScale)

            // Particle dots
            ForEach(Self.particles.indices, id: \.self) { i in
                let p = Self.particles[i]
                Circle()
                    .fill(p.color)
                    .frame(width: 8, height: 8)
                    .offset(
                        x: cos(p.angle * .pi / 180) * p.radius * dotProgress,
                        y: sin(p.angle * .pi / 180) * p.radius * dotProgress
                    )
                    .opacity(Double(1 - dotProgress))
                    .scaleEffect(1 - dotProgress * 0.4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            ringOpacity = 0.55
            withAnimation(.easeOut(duration: 0.5)) {
                dotProgress = 1
                ringScale   = 2.6
                ringOpacity = 0
            }
        }
    }
}

// MARK: - Like button with heart burst

private struct LikeButton: View {
    let isFav: Bool
    let label: String
    let onTap: () -> Void

    @State private var heartScale: CGFloat = 1.0
    @State private var ringScale:  CGFloat = 0.6
    @State private var ringOpacity: Double = 0

    var body: some View {
        Button {
            let willFav = !isFav
            onTap()
            if willFav { burst() }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isFav ? "heart.fill" : "heart")
                    .font(.title3)
                    .scaleEffect(heartScale)
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(ringOpacity), lineWidth: 2)
                            .frame(width: 28, height: 28)
                            .scaleEffect(ringScale)
                            .allowsHitTesting(false)
                    )
                Text(label).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(isFav ? Color.red : Color.lllbSecondaryText)
            .background(isFav ? Color.red.opacity(0.10) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isFav ? Color.red.opacity(0.30) : Color.lllbCellStroke, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func burst() {
        // Heart pulses up then settles.
        withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) { heartScale = 1.4 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) { heartScale = 1.0 }
        }
        // Ring expands outward and fades.
        ringScale   = 0.6
        ringOpacity = 0.55
        withAnimation(.easeOut(duration: 0.55)) {
            ringScale   = 2.4
            ringOpacity = 0
        }
    }
}

// MARK: - Candy balance with digit roll + "+N" floating delta

private struct CandyBalanceLabel: View {
    let balance: Int

    @State private var lastSeen: Int? = nil
    @State private var floats:   [FloatingDelta] = []

    private struct FloatingDelta: Identifiable {
        let id = UUID()
        let amount: Int
        let createdAt: Date
    }

    var body: some View {
        HStack(spacing: 3) {
            Text("🍬").font(.system(size: 13))
            Text("\(balance)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.lllbSecondaryText)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.4), value: balance)
        }
        .overlay(alignment: .topTrailing) {
            ZStack(alignment: .topTrailing) {
                ForEach(floats) { f in
                    DeltaPlume(amount: f.amount)
                        .id(f.id)
                }
            }
            .allowsHitTesting(false)
            .offset(x: 18, y: -4)
        }
        .onAppear { lastSeen = balance }
        .onChange(of: balance) { newValue in
            defer { lastSeen = newValue }
            guard let prev = lastSeen, newValue > prev else { return }
            let delta = newValue - prev
            let f = FloatingDelta(amount: delta, createdAt: Date())
            floats.append(f)
            // Cleanup after the animation finishes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                floats.removeAll { $0.id == f.id }
            }
        }
    }
}

private struct DeltaPlume: View {
    let amount: Int
    @State private var rise:    CGFloat = 0
    @State private var opacity: Double  = 0

    var body: some View {
        Text("+\(amount)")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Color.lllbRingColors[3])    // gold from brand palette
            .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
            .offset(y: rise)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.18)) { opacity = 1 }
                withAnimation(.easeOut(duration: 1.1))  { rise = -28 }
                withAnimation(.easeIn(duration: 0.45).delay(0.7)) { opacity = 0 }
            }
    }
}

// MARK: - Unlock picker overlay

private struct UnlockPickerView: View {
    let groups:         [[LessonSentence]]   // each entry is one tappable card (1 sentence or full tag-group)
    let remaining:      Int                  // how many more cards user must tap before close
    let nativeLanguage: String
    let onPick:         (Int) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text(L("挑 \(remaining) 个加进句子池",
                       "Pick \(remaining) for your pool",
                       nativeLanguage: nativeLanguage))
                    .font(.headline)
                    .padding(.top, 22)
                Text(L("点一下即加入，未选中的本次丢弃",
                       "Tap to add — unpicked ones are discarded this round",
                       nativeLanguage: nativeLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                    .padding(.bottom, 14)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(groups.indices, id: \.self) { i in
                            Button {
                                onPick(i)
                            } label: {
                                cardContent(group: groups[i])
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                }
                .frame(maxHeight: 360)
                .padding(.bottom, 22)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 28)
        }
    }

    @ViewBuilder
    private func cardContent(group: [LessonSentence]) -> some View {
        let isGroup = group.count > 1
        let head    = group.first
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                if let s = head {
                    Text(s.text)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                }
                Spacer()
                if let s = head {
                    Text(s.cefr)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.lllbTagBg)
                        .clipShape(Capsule())
                }
            }
            if let s = head {
                let tr = s.translation.resolvedTranslation(nativeLanguage: nativeLanguage)
                if !tr.isEmpty {
                    Text(tr)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if isGroup {
                let tagName = head?.tags.first(where: { $0.index != nil })?.name
                              ?? L("整组", "Group", nativeLanguage: nativeLanguage)
                Text(L("\(tagName) · \(group.count) 句一组",
                       "\(tagName) · \(group.count)-piece group",
                       nativeLanguage: nativeLanguage))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.lllbAccent)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.lllbCellStroke, lineWidth: 0.5)
        )
    }
}
