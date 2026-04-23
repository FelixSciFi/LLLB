import SwiftUI


// MARK: - View

struct ContentView: View {
    @ObservedObject var session: LessonSessionModel
    @Binding var showProfile: Bool
    var streakDays:   Int = 0
    var candyBalance: Int = 0
    @State private var showLibraryPicker  = false
    @State private var showSpeedPopover   = false
    @State private var showRepeatsPopover = false
    @State private var archiveExpanded    = false

    private static let playbackSpeedSteps: [Double] = Array(stride(from: 0.5, through: 2.0, by: 0.25))

    var body: some View {
        NavigationStack {
            ZStack {
                // ── Background ────────────────────────────────────────────────
                Group {
                    if session.isFavoriteMode          { Color.green.opacity(0.12) }
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
                        leftControls
                            .frame(width: 56)
                            .padding(.top, 16)

                        VStack(spacing: 0) {
                            peekArrow(systemName: "chevron.up")
                            Spacer(minLength: 0)
                            sentenceArea
                                .padding(.horizontal, 12)
                            Spacer()
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
                                .foregroundStyle(session.isFavoriteMode ? Color.green : Color.lllbAccent)
                                .padding(14)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(.bottom, 32)
                    }
                }

                // ── Floating menu button (normal mode) ────────────────────────
                if session.focusedLemma == nil && !session.isFavoriteMode && session.activatedTag == nil {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button { showProfile = true } label: {
                                Image(systemName: "line.3.horizontal")
                                    .font(.title2)
                                    .padding(14)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 28)
                        }
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
        HStack {
            Label("\(streakDays)", systemImage: "flame.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(streakDays > 0
                    ? Color(red: 1, green: 149/255, blue: 0)   // #FF9500
                    : Color.lllbSecondaryText)
            Spacer()
            HStack(spacing: 3) {
                Text("🍬").font(.system(size: 13))
                Text("\(candyBalance)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.lllbSecondaryText)
            }
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

            // Loop
            Button { session.toggleLoop() } label: {
                controlCell(
                    icon:     session.loopCurrent ? "repeat.1.circle.fill" : "repeat.circle",
                    label:    L("循环", "Loop", nativeLanguage: nl),
                    isActive: session.loopCurrent
                )
            }
            .buttonStyle(.plain)

            // Library
            Button { showLibraryPicker = true } label: {
                controlCell(icon: "books.vertical", label: L("库", "Library", nativeLanguage: nl))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showLibraryPicker) { LibraryPickerView(session: session) }

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
                    label:       L("熟悉", "Known", nativeLanguage: nl),
                    isActive:    isFamiliar,
                    activeColor: .green
                )
            }
            .buttonStyle(.plain)

            if archiveExpanded {
                Button {
                    session.archiveCurrentSentence(as: .mastered)
                    withAnimation { archiveExpanded = false }
                } label: {
                    controlCell(icon: "checkmark.seal", label: L("学会了", "Done", nativeLanguage: nl))
                }
                .buttonStyle(.plain)
                Button {
                    session.archiveCurrentSentence(as: .later)
                    withAnimation { archiveExpanded = false }
                } label: {
                    controlCell(icon: "clock", label: L("稍后学", "Later", nativeLanguage: nl))
                }
                .buttonStyle(.plain)
            } else {
                Button { withAnimation { archiveExpanded = true } } label: {
                    controlCell(icon: "archivebox", label: L("存档", "Archive", nativeLanguage: nl))
                }
                .buttonStyle(.plain)
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
            let color: Color = count < 20 ? .orange : (count < 50 ? .green : (count < 100 ? .blue : .yellow))
            Text("▶ \(count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(color)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(color.opacity(0.1))
                .clipShape(Capsule())
        }
    }

    // MARK: - Sentence area

    private var sentenceArea: some View {
        let s  = session.currentSentence
        let nl = session.nativeLanguage
        return VStack(spacing: 16) {
            // Tag row
            let currentTags = s.tags
            if !currentTags.isEmpty {
                TokenFlowLayout(spacing: 4, runSpacing: 4, trailingAligned: true) {
                    ForEach(currentTags, id: \.name) { tag in
                        tagChip(tag)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Favorite mode indicator
            if session.isFavoriteMode, let playlist = session.examplePlaylist {
                HStack {
                    Image(systemName: "heart.fill").foregroundStyle(.green)
                    Text("\(session.exampleIndex + 1)/\(playlist.count)")
                        .font(.caption.weight(.semibold)).foregroundStyle(.green.opacity(0.7))
                    Spacer()
                }
                .padding(.bottom, 4)
            }

            // Focus mode header
            if let lemma = session.focusedLemma {
                HStack(spacing: 8) {
                    Text(session.focusedTokenText)
                        .font(.title.weight(.bold)).foregroundStyle(Color.lllbAccent)
                    Text("·").foregroundStyle(Color.lllbAccent.opacity(0.5))
                    Text(lemma).font(.title3).foregroundStyle(Color.lllbAccent.opacity(0.7))
                    Spacer()
                    if let playlist = session.examplePlaylist {
                        Text("\(session.exampleIndex + 1)/\(playlist.count)")
                            .font(.caption.weight(.semibold)).foregroundStyle(Color.lllbAccent.opacity(0.7))
                    }
                }
                .padding(.bottom, 4)
            }

            if let err = session.loadError {
                Text(L("无法加载句库：", "Could not load sentences: ", nativeLanguage: nl) + err)
                    .foregroundStyle(.red).multilineTextAlignment(.center)
            }

            if session.showIPA, !session.isFamiliarSuppressed, !s.ipa.isEmpty {
                Text("/ \(s.ipa) /")
                    .font(.subheadline)
                    .foregroundStyle(Color.lllbSecondaryText)
                    .multilineTextAlignment(.center)
            }

            let sentenceTr = s.translation.resolvedTranslation(nativeLanguage: session.nativeLanguage)
            if session.showTranslation, !session.isFamiliarSuppressed, !sentenceTr.isEmpty {
                Text(sentenceTr)
                    .font(.headline)
                    .foregroundStyle(Color.lllbSecondaryText)
                    .multilineTextAlignment(.center)
            }

            TokenFlowLayout(spacing: 10, runSpacing: 14) {
                ForEach(Array(s.tokens.enumerated()), id: \.offset) { idx, token in
                    tokenChip(token: token, index: idx,
                              highlighted: idx == session.narration.highlightedTokenIndex)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Token chip

    @ViewBuilder
    private func tokenChip(token: TokenChunk, index: Int, highlighted: Bool) -> some View {
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

        VStack(alignment: .center, spacing: 6) {
            if showEmoji {
                Text(token.emoji).font(.system(size: 44))
            }
            if showFallbackText && !showSpell {
                Text(display).font(.system(size: 44))
                    .foregroundStyle(Color.lllbSecondaryText)
            }
            if showSpell {
                Text(display)
                    .font(.title3.weight(.medium))                  // §3: medium weight
                    .foregroundStyle(spellingColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            if showTokIPA, let ipa = token.ipa {
                Text("/\(ipa)/")
                    .font(.caption).italic()                        // §3: italic IPA
                    .foregroundStyle(Color.lllbSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if showTokTr {
                Text(token.translation.resolvedTranslation(nativeLanguage: session.nativeLanguage))
                    .font(.caption)
                    .foregroundStyle(Color.lllbSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
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
