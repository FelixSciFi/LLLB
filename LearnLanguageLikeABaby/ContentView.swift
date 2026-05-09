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
    @ObservedObject var entitlementStore:   EntitlementStore
    @ObservedObject var streakRescueStore:  StreakRescueStore
    @ObservedObject var shareTriggerStore:  ShareTriggerStore
    var candyStore: CandyStore
    var onboardingCompleted: Bool = true
    var onCollectMilestones: () -> Void = {}
    var onUseCandyForRefill: () -> Void = {}
    var onTopUpForRefill:    (Int) -> Void = { _ in }
    var onWatchAdForRefill:  () -> Void = {}
    var onOpenSubscribe:     () -> Void = {}
    /// Driven by RootView. When true, ContentView paints the spotlight
    /// tutorial as a non-blocking overlay above its own UI.
    @Binding var showTutorial: Bool
    /// Called when the user finishes or skips the tutorial. RootView is
    /// expected to set tutorialCompleted_v1 = true and clear `showTutorial`.
    var onTutorialDone: (Bool) -> Void = { _ in }
    @State private var tutorialAnchors: [TutorialAnchorID: CGRect] = [:]
    /// User-triggered voice-quality hint shown in the top bar. Recomputed
    /// on appear, on learning-language switch, and after any sheet that
    /// might have changed the voice selection (Profile / hint sheet).
    @State private var voiceAdvice: VoiceUpgradeAdvice = .none
    @State private var showVoiceHintSheet = false
    @AppStorage("voice_hint_dismissed_v1") private var voiceHintDismissed = false
    /// Collapsed state for the right display-toggle column. When true a
    /// 12pt tab sits at the right edge instead; tap or left-swipe restores
    /// the full column. Persisted per-device (UI preference).
    @AppStorage("rightColumnCollapsed_v1") private var rightColumnCollapsed = false
    /// Same pattern for the left playback-controls column. Independent
    /// state — both can be collapsed simultaneously to hand the entire
    /// horizontal space to the sentence.
    @AppStorage("leftColumnCollapsed_v1") private var leftColumnCollapsed = false
    /// Brief brand-color flash on Later/Known cells when tapped. The
    /// underlying archive action runs immediately; this just lets the
    /// user see "yep, that registered" before the sentence advances.
    @State private var laterFlashed = false
    @State private var knownFlashed = false
    @State private var showLibraryPicker  = false
    @State private var showSpeedPopover   = false
    @State private var showRepeatsPopover = false
    @State private var showRingsOverlay   = false
    @State private var showCollectCard    = false
    @State private var showCelebration    = false
    @State private var showRefillMenu     = false
    @State private var showRescueSheet    = false
    @State private var showShareSheet     = false
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

                // ── Three-column layout ───────────────────────────────────────
                VStack(spacing: 0) {
                    topBar

                    HStack(alignment: .top, spacing: 0) {
                        leftSide
                            .padding(.top, 16)

                        VStack(spacing: 0) {
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
                            .tutorialAnchor(.sentenceArea)
                            // Reserved for the bottom cluster: action row at
                            // ~90pt, tag chips at ~150pt, plus padding.
                            Spacer(minLength: 200)
                        }
                        .frame(maxWidth: .infinity)

                        rightSide
                            .padding(.top, 16)
                    }
                    .padding(.horizontal, 4)
                }

                // ── Exit pill (focus / favorite / tag mode) ───────────────────
                if session.focusedLemma != nil || session.isFavoriteMode || session.activatedTag != nil {
                    VStack {
                        Spacer()
                        exitPillButton
                            .padding(.horizontal, 16)
                            .padding(.bottom, 90)
                    }
                }

                // Profile is now a cell inside the bottom action toolbar
                // (`actionRow`); it's no longer rendered as a standalone
                // bottom-right overlay.

                // ── Add-to-pool button (focus mode, when current example is not in pool) ──
                // restoreSentence also lifts the sentence out of mastered/later if
                // archived — letting users "re-pick up" a known sentence from focus mode.
                // Bottom-right corner, 56pt wide to match rightColumn cells and sit
                // in the empty band beneath them (avoids covering Like/Familiar/etc.).
                if (session.focusedLemma != nil || session.activatedTag != nil || session.isFavoriteMode)
                    && !session.pool.contains(session.currentSentence.id) {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                Haptics.success()
                                session.restoreSentence(id: session.currentSentence.id)
                            } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                    Text(L("加入", "Add",
                                           nativeLanguage: session.nativeLanguage))
                                        .font(.caption2)
                                }
                                .foregroundStyle(Color.lllbAccent)
                                .frame(width: 56)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lllbAccent.opacity(0.6), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 20)
                            .padding(.bottom, 90)
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
                        // Tag chips above the action row (32pt) and the
                        // secondary cluster (Profile/exit/playcount at 90pt).
                        .padding(.bottom, 150)
                    }
                }

                // ── Left column collapsed expand-tab (floating overlay) ───────
                if leftColumnCollapsed {
                    HStack {
                        collapsedExpandLeftTab
                        Spacer()
                    }
                }

                // ── Right column collapsed expand-tab (floating overlay) ──────
                // Lives outside the HStack so it doesn't take layout space —
                // when collapsed the sentence area extends to the right edge,
                // and this small chevron hovers on top.
                if rightColumnCollapsed {
                    HStack {
                        Spacer()
                        collapsedExpandTab
                    }
                }

                // ── Per-sentence action row (very bottom, anchored) ───────────
                // Sits at the screen-bottom safe-area band so it reads as
                // "fixed footer" rather than floating mid-air. The earlier
                // bottom-corner items (Profile / play-count / exit pill) are
                // bumped up to 90pt to clear it.
                VStack {
                    Spacer()
                    actionRow
                        .padding(.bottom, 32)
                }

                // Play count is now displayed inline inside the Play cell of
                // `actionRow` (▶ N with the original 4-tier color), so the
                // standalone bottom-left badge overlay is removed.

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

                // ── Spotlight tutorial (zIndex 50: below user-driven overlays) ──
                if showTutorial {
                    TutorialSpotlightOverlay(
                        nativeLanguage: session.nativeLanguage,
                        anchors:        tutorialAnchors,
                        onDone:         { skipped in onTutorialDone(skipped) }
                    )
                    .transition(.opacity)
                    .zIndex(50)
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
            .onPreferenceChange(TutorialAnchorKey.self) { dict in
                tutorialAnchors = dict
            }
            .onAppear { recomputeVoiceAdvice() }
            .onChange(of: session.config.id) { _ in recomputeVoiceAdvice() }
            .onChange(of: showProfile) { wasShown in
                // Profile may contain VoiceHub edits — re-check on close.
                if !wasShown { recomputeVoiceAdvice() }
            }
            .sheet(isPresented: $showVoiceHintSheet, onDismiss: { recomputeVoiceAdvice() }) {
                VoiceHintSheet(
                    advice:         voiceAdvice,
                    nativeLanguage: session.nativeLanguage,
                    onOpenProfile: {
                        showVoiceHintSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showProfile = true
                        }
                    },
                    onSilence: {
                        voiceHintDismissed = true
                        showVoiceHintSheet = false
                    },
                    onClose: { showVoiceHintSheet = false }
                )
            }
            .toolbar(.hidden, for: .navigationBar)
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                        let screenH = UIScreen.main.bounds.height
                        // Bottom dead-zone has to clear the iOS home-gesture
                        // grab area + a bit above it — users start their
                        // swipe-up-to-close anywhere in the bottom ~120pt,
                        // not just the 34pt home-indicator strip.
                        guard value.startLocation.y < screenH - 120 else { return }
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
        .sheet(isPresented: $showRescueSheet) {
            StreakRescueSheet(
                rescueStore:       streakRescueStore,
                usageTracker:      usageTracker,
                candyStore:        candyStore,
                shareTriggerStore: shareTriggerStore,
                nativeLanguage:    candyStore.nativeLanguage,
                onRequestShare: {
                    // RescueSheet has already dismissed itself. Wait briefly
                    // so SwiftUI finishes closing it before we present the
                    // share sheet on top.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showShareSheet = true
                    }
                }
            )
        }
        .sheet(isPresented: $showShareSheet) {
            // trigger is nil for manual entries (streak hub / Profile).
            // The sheet handles both modes — only the heading copy differs;
            // reward path shares the same daily/monthly cap.
            StreakShareSheet(
                trigger:           shareTriggerStore.pending,
                triggerStore:      shareTriggerStore,
                candyStore:        candyStore,
                streakDays:        usageTracker.streakDays,
                learningLanguage:  session.config,
                totalHours:        (usageTracker.allTimeMinutes + usageTracker.allTimeBgMinutes / 3) / 60,
                nativeLanguage:    candyStore.nativeLanguage
            )
        }
        // Promo expiry reminder: the first time the user enters ContentView
        // with daysRemaining == 2 (and again at 1), pop the cup menu so the
        // countdown is unmissable. Per-threshold flag in UserDefaults keeps
        // it to a single popup per remaining-day count.
        .onAppear {
            checkPromoExpiryWarning()
            checkRescueAutoPrompt()
        }
        .onReceive(usageTracker.$todayMinutes) { _ in checkPromoExpiryWarning() }
        .onReceive(shareTriggerStore.$pending) { trigger in
            // A streak milestone fired — pop the share sheet (unless the
            // rescue sheet is already up; share trigger waits its turn).
            guard trigger != nil, !showRescueSheet else { return }
            showShareSheet = true
        }
    }

    private func checkRescueAutoPrompt() {
        // Only auto-prompt once per day; manual taps always work via streakLabel.
        guard !streakRescueStore.hasShownAutoPromptToday() else { return }
        guard rescueWindowOpen else { return }
        streakRescueStore.markAutoPromptShown()
        // Defer slightly so it doesn't collide with onboarding / promo
        // popups racing on first launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showRescueSheet = true
        }
    }

    private func checkPromoExpiryWarning() {
        guard entitlementStore.isPromoActive,
              let days = entitlementStore.promoDaysRemaining,
              days == 1 || days == 2
        else { return }
        let key = "promo_warned_at_\(days)d_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        showRefillMenu = true
        Haptics.medium()
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            coffeeCupButton
            streakLabel
            CandyBalanceLabel(balance: candyBalance)
            Spacer()
            if voiceAdvice.needsHint && !voiceHintDismissed {
                voiceHintButton
            }
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

    private var voiceHintButton: some View {
        Button {
            Haptics.light()
            showVoiceHintSheet = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "speaker.wave.2.bubble.left")
                    .font(.system(size: 12, weight: .semibold))
                Text(L("音质", "Voice", nativeLanguage: session.nativeLanguage))
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(Color.orange.opacity(0.35), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func recomputeVoiceAdvice() {
        voiceAdvice = VoiceQualityCheck.advice(for: session.config.ttsLocale)
    }

    // MARK: - Left side (column + swipe-handle pedestal)

    @ViewBuilder
    private var leftSide: some View {
        if !leftColumnCollapsed {
            VStack(spacing: 0) {
                leftSideSwipeHandle
                    .padding(.bottom, 12)
                leftControls
                    .tutorialAnchor(.leftColumn)
                Spacer(minLength: 0)
            }
            .frame(width: 56)
        }
    }

    private var leftSideSwipeHandle: some View {
        Image(systemName: "chevron.left")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(Color.lllbCellStroke.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(Self.columnSpring) { leftColumnCollapsed = true }
            }
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        let dx = value.translation.width
                        guard abs(dx) > abs(value.translation.height) else { return }
                        if dx < -20 {
                            withAnimation(Self.columnSpring) { leftColumnCollapsed = true }
                        }
                    }
            )
    }

    /// Floating chevron-tab shown when the left column is collapsed —
    /// mirror of `collapsedExpandTab` for the right side. Sits at the top
    /// of the screen (just below topBar) so it's out of the sentence area
    /// and lines up symmetrically with its right-side counterpart.
    private var collapsedExpandLeftTab: some View {
        VStack {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 36)
                .background(Color.lllbCellStroke.opacity(0.22),
                            in: RoundedRectangle(cornerRadius: 6))
                .padding(8)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(Self.columnSpring) { leftColumnCollapsed = false }
                }
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            let dx = value.translation.width
                            guard abs(dx) > abs(value.translation.height) else { return }
                            if dx > 20 {
                                withAnimation(Self.columnSpring) { leftColumnCollapsed = false }
                            }
                        }
                )
            Spacer(minLength: 0)
        }
        // Clears the 36pt topBar plus a small cushion. Same value used on
        // the right-side tab so the two chevrons sit at identical y.
        .padding(.top, 52)
        .padding(.leading, 2)
    }

    // MARK: - Right side (column + swipe-handle pedestal)

    /// Wraps the right display-toggle column with a dedicated swipe-handle
    /// pedestal underneath. The pedestal is the *only* part that listens
    /// for horizontal drags — the toggle buttons themselves stay click-only,
    /// so a swipe meant to collapse never accidentally fires a toggle.
    /// When collapsed the buttons are hidden and the pedestal stays at
    /// roughly the same vertical position so the user knows where to grab
    /// it back.
    /// Spring used for both collapse and expand transitions — gives the
    /// sheet-like "snap with a tiny bounce" feel rather than a flat ease.
    private static let columnSpring: Animation =
        .spring(response: 0.35, dampingFraction: 0.85)

    @ViewBuilder
    private var rightSide: some View {
        // When collapsed, this view is empty — the floating chevron lives
        // as a ZStack overlay so the sentence area can extend all the way
        // to the right edge instead of paying for a 24pt strip.
        if !rightColumnCollapsed {
            VStack(spacing: 0) {
                rightSideSwipeHandle
                    .padding(.bottom, 12)
                rightColumn
                    .tutorialAnchor(.rightColumn)
                Spacer(minLength: 0)
            }
            .frame(width: 56)
        }
    }

    /// Pedestal below the toggle column (expanded state). Tap or right-swipe
    /// to collapse. The `abs(width) > abs(height)` guard keeps the parent's
    /// up/down sentence-swipe gesture working when the user drags
    /// vertically across this region.
    private var rightSideSwipeHandle: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(Color.lllbCellStroke.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(Self.columnSpring) { rightColumnCollapsed = true }
            }
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        let dx = value.translation.width
                        guard abs(dx) > abs(value.translation.height) else { return }
                        if dx > 20 {
                            withAnimation(Self.columnSpring) { rightColumnCollapsed = true }
                        }
                    }
            )
    }

    /// Floating chevron-tab shown when the right column is collapsed —
    /// sits as a ZStack overlay so it can hover on top of the sentence
    /// area without claiming layout space. Tap or left-swipe to expand.
    /// Anchored at the top of the screen, mirroring the left-side tab's y.
    private var collapsedExpandTab: some View {
        VStack {
            Image(systemName: "chevron.left")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 36)
                .background(Color.lllbCellStroke.opacity(0.22),
                            in: RoundedRectangle(cornerRadius: 6))
                // Larger transparent hit area so the small visible tab is
                // still comfortable to tap.
                .padding(8)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(Self.columnSpring) { rightColumnCollapsed = false }
                }
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            let dx = value.translation.width
                            guard abs(dx) > abs(value.translation.height) else { return }
                            if dx < -20 {
                                withAnimation(Self.columnSpring) { rightColumnCollapsed = false }
                            }
                        }
                )
            Spacer(minLength: 0)
        }
        .padding(.top, 52)
        .padding(.trailing, 2)
    }

    // MARK: - Bottom action row

    /// Brief flash duration (s) used by the one-shot archive cells (Later,
    /// Known) to acknowledge a tap with a short brand-color pulse before
    /// the sentence advances and the cell visually resets.
    private static let archiveFlashSeconds: Double = 0.32

    /// Bottom-anchored toolbar: Play / Like / Familiar / Later / Known /
    /// Profile, evenly distributed across the available width via
    /// `frame(maxWidth: .infinity)`. Labels use `minimumScaleFactor(0.7)`
    /// so iPhone SE shrinks "Familiar" to fit instead of truncating.
    /// Active-state colors map to the four brand ring colors.
    @ViewBuilder
    private var actionRow: some View {
        let nl         = session.nativeLanguage
        let isFav      = session.favoritedIDs.contains(session.currentSentence.id)
        let isFamiliar = session.familiarIDs.contains(session.currentSentence.id)

        HStack(spacing: 6) {
            playCell(nl: nl)

            LikeButton(
                isFav: isFav,
                label: L("喜欢", "Like", nativeLanguage: nl),
                onTap: {
                    Haptics.success()
                    session.toggleFavorite(for: session.currentSentence.id)
                }
            )

            Button { Haptics.success(); session.toggleFamiliar() } label: {
                actionCell(
                    icon:        isFamiliar ? "checkmark.circle.fill" : "checkmark.circle",
                    label:       L("熟悉", "Familiar", nativeLanguage: nl),
                    isActive:    isFamiliar,
                    activeColor: Color.lllbRingColors[1]
                )
            }
            .buttonStyle(.plain)

            archiveCell(
                icon:  "clock",
                label: L("稍后学", "Later", nativeLanguage: nl),
                color: Color.lllbRingColors[2],
                flashed: $laterFlashed
            ) {
                session.archiveCurrentSentence(as: .later)
            }

            archiveCell(
                icon:  "checkmark.seal",
                label: L("学会了", "Known", nativeLanguage: nl),
                color: Color.lllbRingColors[3],
                flashed: $knownFlashed
            ) {
                session.archiveCurrentSentence(as: .mastered)
            }

            Button { showProfile = true } label: {
                actionCell(
                    icon:        "person",
                    label:       L("我", "Profile", nativeLanguage: nl),
                    isActive:    false,
                    activeColor: Color.lllbAccent
                )
            }
            .buttonStyle(.plain)
            .tutorialAnchor(.profileButton)
        }
        .padding(.horizontal, 12)
    }

    /// Combined Play/Pause + play-count cell. Top icon toggles playback;
    /// bottom shows `▶ N` in the same 4-tier color logic as the original
    /// floating playCountBadge (orange < 20, green < 50, blue < 100,
    /// gold ≥ 100). When count == 0 the bottom is empty — matches the
    /// pre-existing "hide badge at zero" rule.
    @ViewBuilder
    private func playCell(nl: String) -> some View {
        let count = session.currentSentencePlayCount
        Button {
            Haptics.medium()
            if session.isAutoPlaying { session.pause() } else { session.resume() }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: session.isAutoPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(Color.lllbSecondaryText)
                if count > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9, weight: .semibold))
                        Text("\(count)")
                            .font(.caption2.monospacedDigit())
                    }
                    .foregroundStyle(Self.playCountTierColor(count))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                } else {
                    // Reserve label height so the cell doesn't jitter as
                    // count flips from 0 → 1 mid-playback.
                    Text(" ")
                        .font(.caption2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color.lllbCellStroke, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(session.isAutoPlaying
                            ? L("暂停", "Pause", nativeLanguage: nl)
                            : L("播放", "Play",  nativeLanguage: nl))
    }

    /// Tier color for the play-count display — copied from the previous
    /// playCountBadge so the visual language stays identical.
    private static func playCountTierColor(_ n: Int) -> Color {
        if n < 20  { return Color.lllbRingColors[0] }
        if n < 50  { return Color.lllbRingColors[1] }
        if n < 100 { return Color.lllbRingColors[2] }
        return Color.lllbRingColors[3]
    }

    /// Generic toolbar cell with icon + label, equal-width via
    /// `frame(maxWidth: .infinity)`. Used by Familiar and Profile.
    private func actionCell(
        icon:        String,
        label:       String,
        isActive:    Bool,
        activeColor: Color
    ) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.title3)
            Text(label)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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

    /// One-shot archive cell (Later, Known). No persistent active state —
    /// instead briefly flashes brand color on tap so the user gets visual
    /// feedback before the sentence advances.
    private func archiveCell(
        icon:    String,
        label:   String,
        color:   Color,
        flashed: Binding<Bool>,
        action:  @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.success()
            flashed.wrappedValue = true
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.archiveFlashSeconds) {
                flashed.wrappedValue = false
            }
            action()
        } label: {
            actionCell(icon: icon, label: label,
                       isActive: flashed.wrappedValue, activeColor: color)
        }
        .buttonStyle(.plain)
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

            // Play mode (sequential / single-loop / shuffle / favorites)
            Button { Haptics.light(); session.cyclePlayMode() } label: {
                let (icon, label): (String, String) = {
                    switch session.playMode {
                    case .sequential: return ("repeat",     L("顺序", "Order",   nativeLanguage: nl))
                    case .singleLoop: return ("repeat.1",   L("单曲", "Loop 1", nativeLanguage: nl))
                    case .shuffle:    return ("shuffle",    L("随机", "Shuffle", nativeLanguage: nl))
                    case .favorites:  return ("heart.fill", L("收藏", "Fav",     nativeLanguage: nl))
                    }
                }()
                controlCell(
                    icon:        icon,
                    label:       label,
                    isActive:    session.playMode != .shuffle,
                    activeColor: session.playMode == .favorites ? .red : .lllbAccent
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

            // Play/Pause moved to the bottom action toolbar so playback
            // control sits at thumb height alongside the per-sentence
            // judgment buttons. Leftcolumn is now {PlayMode, Library,
            // Speed, Repeats} — 4 cells.
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

            // Per-sentence action buttons (Like/Familiar/Known/Later)
            // moved out of this column into a bottom-row cluster — see
            // `actionRow` overlay. Right column is now display-toggles only.
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

    /// Bottom-centered pill that doubles as the mode indicator and exit
    /// affordance for focus / favorite / tag modes. Combines what was
    /// previously split between a top header (lemma + counter) and a small
    /// floating xmark — new users couldn't connect the two.
    @ViewBuilder
    private var exitPillButton: some View {
        let nl = session.nativeLanguage
        Button { session.dismissVoiceBranch() } label: {
            VStack(spacing: 3) {
                // Line 1: mode label + the key entity (lemma / favorites / tag name)
                HStack(spacing: 5) {
                    if let lemma = session.focusedLemma {
                        Text(L("练习", "Practicing", nativeLanguage: nl))
                            .foregroundStyle(Color.lllbAccent.opacity(0.65))
                        Text(lemma)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.lllbAccent)
                    } else if session.isFavoriteMode {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.lllbAccent)
                        Text(L("收藏", "Favorites", nativeLanguage: nl))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.lllbAccent)
                    } else if let tag = session.activatedTag {
                        Text(tag)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.lllbAccent)
                    }
                }
                // Line 2: tap-to-exit + optional playlist counter
                HStack(spacing: 5) {
                    Text(L("点击退出", "tap to exit", nativeLanguage: nl))
                        .foregroundStyle(Color.lllbAccent.opacity(0.65))
                    if let playlist = session.examplePlaylist {
                        Text("· \(session.exampleIndex + 1)/\(playlist.count)")
                            .foregroundStyle(Color.lllbAccent.opacity(0.45))
                            .monospacedDigit()
                    }
                }
                .font(.system(size: 12))
            }
            .font(.system(size: 13))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lllbAccent.opacity(0.6), lineWidth: 1))
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

        // Outline-only active states: keep chip bg, boost stroke, leave text primary
        let chipBg     = Color.lllbChipBg
        let chipStroke: Color = highlighted ? Color.lllbAccent.opacity(0.75) : Color.lllbChipStroke
        let chipStrokeWidth: CGFloat = highlighted ? 1.5 : 0.5
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
            isPremium:       entitlementStore.isUnlimited,
            // Only surface the promo countdown / subscribe affordance when the
            // user is in promo *and* hasn't subscribed yet. Subscribers see the
            // plain "thanks" card.
            promoDaysRemaining: (entitlementStore.isPromoActive
                                 && !entitlementStore.isSubscribed)
                                ? entitlementStore.promoDaysRemaining : nil,
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
        return CoffeeCupView(progress: playbackBudget.progress(), isPremium: entitlementStore.isUnlimited, size: 26)
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.light()
                showRefillMenu = true
            }
    }

    // MARK: - Streak label (tiered + rescue-aware)

    /// True iff yesterday is recoverable (rescue window open) AND today's
    /// 5-min threshold hasn't been crossed yet. Drives the blue-grey breathing
    /// visual + makes the rescue sheet open via the streak tap target.
    private var rescueWindowOpen: Bool {
        streakRescueStore.currentOffer(
            streakLastDateKey: usageTracker.streakLastDateString,
            streakDays:        usageTracker.streakDays
        ) != nil
    }

    @ViewBuilder
    private var streakLabel: some View {
        let inRescue = rescueWindowOpen
        // Visual reward grows with streak length: bigger / hotter / glowing.
        // During the rescue window we override colors with a cool blue-grey
        // and let the breathing-modifier pulse opacity to draw the eye.
        let tier: (size: CGFloat, color: Color, glow: CGFloat) = {
            switch usageTracker.streakDays {
            case 0:        return (13, Color.lllbSecondaryText,  0)
            case 1...6:    return (13, Color.lllbRingColors[0],  0)   // orange
            case 7...29:   return (15, Color.lllbRingColors[0],  0)
            case 30...99:  return (16, Color(red: 0.95, green: 0.40, blue: 0.20), 3)
            default:       return (17, Color(red: 0.95, green: 0.25, blue: 0.10), 5)
            }
        }()
        let blueGrey = Color(red: 0.42, green: 0.50, blue: 0.62)
        let activeColor = inRescue ? blueGrey : tier.color
        let activeGlow:  CGFloat = inRescue ? 0 : tier.glow
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: tier.size, weight: .semibold))
                .foregroundStyle(activeColor)
                .shadow(color: activeGlow > 0 ? activeColor.opacity(0.55) : .clear,
                        radius: activeGlow)
            Text("\(usageTracker.streakDays)")
                .font(.system(size: tier.size - 1, weight: .semibold))
                .foregroundStyle(activeColor)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.45, dampingFraction: 0.7), value: usageTracker.streakDays)
        }
        .modifier(StreakRescueBreathing(active: inRescue))
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.light()
            showRescueSheet = true
        }
    }
}

// MARK: - Streak rescue-window breathing modifier

/// Pulses opacity 0.55 ↔ 1.0 in a slow ~2.4s cycle while `active`. Used to
/// signal that the streak is in a recoverable state.
private struct StreakRescueBreathing: ViewModifier {
    let active: Bool
    @State private var pulse: Bool = false

    func body(content: Content) -> some View {
        content
            .opacity(active ? (pulse ? 1.0 : 0.55) : 1.0)
            .animation(active
                ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                : .default,
                value: pulse)
            .onAppear {
                if active { pulse = true }
            }
            .onChange(of: active) { now in
                pulse = now
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

    /// Brand orange — first of the four ring colors. Replaces the previous
    /// red so Like sits in the same color language as Familiar/Later/Known.
    private static let likeColor: Color = Color.lllbRingColors[0]

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
                            .stroke(Self.likeColor.opacity(ringOpacity), lineWidth: 2)
                            .frame(width: 28, height: 28)
                            .scaleEffect(ringScale)
                            .allowsHitTesting(false)
                    )
                Text(label)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(isFav ? Self.likeColor : Color.lllbSecondaryText)
            .background(isFav ? Self.likeColor.opacity(0.10) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isFav ? Self.likeColor.opacity(0.30) : Color.lllbCellStroke, lineWidth: 0.5)
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
                            CandidateCard(
                                group: groups[i],
                                nativeLanguage: nativeLanguage,
                                onPick: { onPick(i) }
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                }
                .frame(maxHeight: 420)
                .padding(.bottom, 22)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 28)
        }
    }
}

/// One row in the unlock picker. Renders either a single sentence or a tag group
/// preview. For groups the first 3 sentences are shown by default and the rest
/// can be revealed via an inline expand toggle (each card keeps its own state).
/// Tapping anywhere on the card body adds the whole unit to the pool — the
/// toggle is its own button so it doesn't trigger the add action.
private struct CandidateCard: View {
    let group:          [LessonSentence]
    let nativeLanguage: String
    let onPick:         () -> Void

    @State private var expanded = false

    private static let previewCount = 3

    private var isGroup: Bool { group.count > 1 }
    private var visibleCount: Int {
        guard isGroup else { return 1 }
        return expanded ? group.count : min(Self.previewCount, group.count)
    }
    private var hiddenCount: Int { max(0, group.count - Self.previewCount) }
    private var tagName: String? {
        group.first?.tags.first(where: { $0.index != nil })?.name
    }
    private var levelLabel: String { group.first?.cefr ?? "" }

    var body: some View {
        Button(action: onPick) {
            Group {
                if isGroup {
                    groupBody
                } else {
                    singleBody
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
        .buttonStyle(.plain)
    }

    /// Compact single-sentence card: original layout — text + level badge inline,
    /// translation underneath. Kept tight so it doesn't waste vertical space.
    @ViewBuilder
    private var singleBody: some View {
        let s = group[0]
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text(s.text)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                if !levelLabel.isEmpty {
                    Text(levelLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.lllbTagBg)
                        .clipShape(Capsule())
                }
            }
            let tr = s.translation.resolvedTranslation(nativeLanguage: nativeLanguage)
            if !tr.isEmpty {
                Text(tr)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Group preview: tag header + first 3 sentences (numbered), with an expand
    /// toggle to reveal the rest. The toggle is its own button so it doesn't
    /// trigger the outer add tap.
    @ViewBuilder
    private var groupBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                if let tagName {
                    Text(L("\(tagName) · \(group.count) 句一组",
                           "\(tagName) · \(group.count)-piece group",
                           nativeLanguage: nativeLanguage))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.lllbAccent)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if !levelLabel.isEmpty {
                    Text(levelLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.lllbTagBg)
                        .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<visibleCount, id: \.self) { idx in
                    sentenceRow(group[idx], number: idx + 1)
                }
            }

            if hiddenCount > 0 {
                Button {
                    Haptics.medium()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        expanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(expanded
                             ? L("收起", "Collapse", nativeLanguage: nativeLanguage)
                             : L("展开余下 \(hiddenCount) 句",
                                 "Show \(hiddenCount) more",
                                 nativeLanguage: nativeLanguage))
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.lllbAccent)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// One numbered sentence row inside a group preview.
    @ViewBuilder
    private func sentenceRow(_ s: LessonSentence, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(number).")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 18, alignment: .leading)
                Text(s.text)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            let tr = s.translation.resolvedTranslation(nativeLanguage: nativeLanguage)
            if !tr.isEmpty {
                Text(tr)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 24)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
