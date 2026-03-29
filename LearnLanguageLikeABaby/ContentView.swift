import AVFoundation
import Combine
import SwiftUI

@MainActor
final class LessonSessionModel: ObservableObject {
    let narration = NarrationEngine()
    let voice = VoiceInputController()

    @Published var mainSentences: [LessonSentence] = []
    @Published var exampleBank: [String: [LessonSentence]] = [:]
    @Published private(set) var bankKeySet: Set<String> = []

    @Published var mainIndex: Int = 0
    @Published var mainIndexBeforeVoice: Int = 0

    @Published var examplePlaylist: [LessonSentence]?
    @Published var exampleIndex: Int = 0

    @Published var loopCurrent: Bool = false
    @Published var speedMultiplier: Double = 1.0
    @Published var repeatsBeforeAdvance: Int = 1

    @Published var showImage: Bool = true
    @Published var showSpelling: Bool = true
    @Published var showIPA: Bool = true
    @Published var showTranslation: Bool = true

    @Published var candidates: [RecognitionCandidate] = []
    @Published var loadError: String?
    @Published var voiceHint: String?

    private var playsOnCurrent: Int = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        narration.onUtteranceFinished = { [weak self] in
            Task { @MainActor in
                self?.handleUtteranceFinished()
            }
        }
        narration.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        voice.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var currentSentence: LessonSentence {
        if let ex = examplePlaylist, exampleIndex < ex.count {
            return ex[exampleIndex]
        }
        guard !mainSentences.isEmpty else {
            return LessonSentence(id: "0", text: "", ipa: "", translation: "", tokens: [])
        }
        return mainSentences[mainIndex % mainSentences.count]
    }

    var isVoiceExampleMode: Bool { examplePlaylist != nil }

    func loadLibrary() {
        do {
            mainSentences = try SentenceLibrary.loadMainSentences()
            exampleBank = try SentenceLibrary.loadExampleBank()
            bankKeySet = Set(exampleBank.keys)
            loadError = nil
            startAutoPlayIfNeeded()
        } catch {
            loadError = error.localizedDescription
        }
    }

    func startAutoPlayIfNeeded() {
        guard loadError == nil, !mainSentences.isEmpty else { return }
        playsOnCurrent = 0
        narration.rateMultiplier = speedMultiplier
        narration.speak(currentSentence)
    }

    func applySpeed(_ value: Double) {
        speedMultiplier = value
        narration.rateMultiplier = value
        if narration.isSpeaking {
            let s = currentSentence
            narration.stop()
            narration.speak(s)
        }
    }

    func toggleLoop() {
        loopCurrent.toggle()
    }

    private func handleUtteranceFinished() {
        let sentence = currentSentence
        if loopCurrent {
            narration.speak(sentence)
            return
        }
        playsOnCurrent += 1
        if playsOnCurrent < max(1, repeatsBeforeAdvance) {
            narration.speak(sentence)
            return
        }
        playsOnCurrent = 0

        if let ex = examplePlaylist {
            if exampleIndex + 1 < ex.count {
                exampleIndex += 1
                narration.speak(ex[exampleIndex])
            } else {
                examplePlaylist = nil
                exampleIndex = 0
                candidates = []
                voiceHint = nil
                mainIndex = mainIndexBeforeVoice
                narration.speak(mainSentences[mainIndex % mainSentences.count])
            }
        } else {
            mainIndex = (mainIndex + 1) % mainSentences.count
            narration.speak(mainSentences[mainIndex])
        }
    }

    func goPreviousSentence() {
        narration.stop()
        playsOnCurrent = 0
        if let ex = examplePlaylist {
            if exampleIndex > 0 {
                exampleIndex -= 1
            } else {
                exampleIndex = ex.count - 1
            }
            narration.speak(ex[exampleIndex])
        } else {
            mainIndex = (mainIndex - 1 + mainSentences.count) % mainSentences.count
            narration.speak(mainSentences[mainIndex])
        }
    }

    func goNextSentence() {
        narration.stop()
        playsOnCurrent = 0
        if let ex = examplePlaylist {
            if exampleIndex + 1 < ex.count {
                exampleIndex += 1
            } else {
                exampleIndex = 0
            }
            narration.speak(ex[exampleIndex])
        } else {
            mainIndex = (mainIndex + 1) % mainSentences.count
            narration.speak(mainSentences[mainIndex])
        }
    }

    func dismissVoiceBranch() {
        narration.stop()
        examplePlaylist = nil
        exampleIndex = 0
        candidates = []
        voiceHint = nil
        playsOnCurrent = 0
        narration.speak(mainSentences[mainIndex % mainSentences.count])
    }

    func beginHoldToTalk() {
        voiceHint = nil
        voice.beginListening()
    }

    func endHoldToTalk() {
        voice.endListeningTopCandidates(maxCount: 3) { [weak self] cands in
            Task { @MainActor in
                self?.processVoiceCandidates(cands)
            }
        }
    }

    private func processVoiceCandidates(_ cands: [RecognitionCandidate]) {
        candidates = cands
        guard let first = cands.first?.text.trimmingCharacters(in: .whitespacesAndNewlines), !first.isEmpty else {
            voiceHint = "没有听清，请再试一次。"
            return
        }
        applyRecognition(first)
    }

    func selectCandidate(_ c: RecognitionCandidate) {
        applyRecognition(c.text)
    }

    private func applyRecognition(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let key = FrenchLemmaSearch.lookupLemmaKey(for: text, bankKeys: bankKeySet),
              let examples = exampleBank[key], !examples.isEmpty
        else {
            voiceHint = "例句库未找到相关词根。"
            return
        }
        voiceHint = nil
        narration.stop()
        playsOnCurrent = 0
        if examplePlaylist == nil {
            mainIndexBeforeVoice = mainIndex
        }
        examplePlaylist = examples
        exampleIndex = 0
        narration.speak(examples[0])
    }
}

// MARK: - View

struct ContentView: View {
    @StateObject private var session = LessonSessionModel()
    @State private var micHoldStarted = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                HStack(alignment: .top, spacing: 0) {
                    leftControls
                        .frame(width: 56)
                        .padding(.top, 72)

                    Spacer(minLength: 0)

                    VStack(spacing: 0) {
                        Spacer(minLength: 24)

                        sentenceArea
                            .padding(.horizontal, 12)

                        Spacer()

                        if !session.candidates.isEmpty, session.candidates.count > 1 {
                            candidateStrip
                                .padding(.bottom, 8)
                        }

                        micArea
                            .padding(.bottom, 28)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.trailing, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    toolbarToggles
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if session.isVoiceExampleMode {
                        Button {
                            session.dismissVoiceBranch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .font(.title2)
                        }
                        .accessibilityLabel("关闭识别结果")
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                        let dx = value.translation.width
                        if dx > 60 {
                            session.goPreviousSentence()
                        } else if dx < -60 {
                            session.goNextSentence()
                        }
                    }
            )
        }
        .task {
            session.voice.requestAuthorization()
            session.loadLibrary()
        }
    }

    private var toolbarToggles: some View {
        HStack(spacing: 10) {
            toggleChip("图片", on: $session.showImage)
            toggleChip("拼写", on: $session.showSpelling)
            toggleChip("音标", on: $session.showIPA)
            toggleChip("翻译", on: $session.showTranslation)
        }
    }

    private func toggleChip(_ title: String, on: Binding<Bool>) -> some View {
        Button {
            on.wrappedValue.toggle()
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(on.wrappedValue ? Color.accentColor.opacity(0.2) : Color(.secondarySystemFill))
                .foregroundStyle(on.wrappedValue ? Color.accentColor : .secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var leftControls: some View {
        VStack(spacing: 14) {
            Button {
                session.toggleLoop()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: session.loopCurrent ? "repeat.1.circle.fill" : "repeat.circle")
                        .font(.title2)
                    Text("循环")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(session.loopCurrent ? Color.accentColor : .primary)

            Menu {
                Button("0.5×") { session.applySpeed(0.5) }
                Button("0.75×") { session.applySpeed(0.75) }
                Button("1×") { session.applySpeed(1.0) }
                Button("1.25×") { session.applySpeed(1.25) }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.title2)
                    Text("速度")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Menu {
                Button("读 1 遍后下一句") { session.repeatsBeforeAdvance = 1 }
                Button("读 2 遍后下一句") { session.repeatsBeforeAdvance = 2 }
                Button("读 3 遍后下一句") { session.repeatsBeforeAdvance = 3 }
                Button("读 5 遍后下一句") { session.repeatsBeforeAdvance = 5 }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "text.badge.checkmark")
                        .font(.title2)
                    Text("遍数")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var sentenceArea: some View {
        let s = session.currentSentence
        return VStack(spacing: 16) {
            if let err = session.loadError {
                Text("无法加载句库：\(err)")
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            if session.showIPA, !s.ipa.isEmpty {
                Text("/ \(s.ipa) /")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if session.showTranslation, !s.translation.isEmpty {
                Text(s.translation)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TokenFlowLayout(spacing: 10, runSpacing: 14) {
                ForEach(Array(s.tokens.enumerated()), id: \.offset) { idx, token in
                    tokenChip(token: token, index: idx, highlighted: idx == session.narration.highlightedTokenIndex)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func tokenChip(token: TokenChunk, index: Int, highlighted: Bool) -> some View {
        let display = token.text.trimmingCharacters(in: .whitespaces)
        let showEmoji = token.hasImage && session.showImage && !token.emoji.isEmpty
        let showSpell = session.showSpelling && !display.isEmpty
        let showTokIPA = session.showIPA && (token.ipa?.isEmpty == false)
        let showTokTr = session.showTranslation && (token.translation?.isEmpty == false)

        VStack(alignment: .center, spacing: 6) {
            if showEmoji {
                Text(token.emoji)
                    .font(.system(size: 44))
            }
            if showSpell {
                Text(display)
                    .font(.title3.weight(highlighted ? .bold : .regular))
                    .multilineTextAlignment(.center)
            }
            if showTokIPA, let ipa = token.ipa {
                Text("/\(ipa)/")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if showTokTr, let tr = token.translation {
                Text(tr)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(highlighted ? Color.accentColor.opacity(0.22) : Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(highlighted ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }

    private var candidateStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("其它识别候选")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(Array(session.candidates.enumerated()), id: \.element.id) { i, c in
                Button {
                    session.selectCandidate(c)
                } label: {
                    Text(c.text)
                        .font(.system(size: i == 0 ? 17 : (i == 1 ? 15 : 14), weight: i == 0 ? .semibold : .regular))
                        .foregroundStyle(.primary)
                        .opacity(Double(0.35 + CGFloat(c.confidence) * 0.65))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private var micArea: some View {
        VStack(spacing: 10) {
            if let auth = session.voice.authorizationMessage, !auth.isEmpty {
                Text(auth)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else if let hint = session.voiceHint, !hint.isEmpty {
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if !session.voice.debugState.isEmpty {
                Text(session.voice.debugState)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Text(session.voice.isListening ? "松开结束" : "按住说法语")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(session.voice.isListening ? Color.accentColor : Color.accentColor.opacity(0.85))
                    .frame(width: 88, height: 88)
                    .overlay {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.white)
                    }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !micHoldStarted else { return }
                        micHoldStarted = true
                        session.beginHoldToTalk()
                    }
                    .onEnded { _ in
                        micHoldStarted = false
                        if session.voice.isListening {
                            session.endHoldToTalk()
                        }
                    }
            )
            .accessibilityLabel("按住说话")
        }
    }
}

// MARK: - Flow layout (iOS 16+)

private struct TokenFlowLayout: Layout {
    var spacing: CGFloat
    var runSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let dims = proposal.replacingUnspecifiedDimensions()
        let w = max(0, dims.width)
        let rows = arrange(w, subviews: subviews)
        let h = rows.map { $0.y + $0.height }.max() ?? 0
        return CGSize(width: w, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(bounds.width, subviews: subviews)
        for (i, sub) in subviews.enumerated() {
            guard i < rows.count else { continue }
            let p = rows[i]
            sub.place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: ProposedViewSize(p.size))
        }
    }

    private func arrange(_ maxWidth: CGFloat, subviews: Subviews) -> [RowItem] {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var items: [RowItem] = []

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth, maxWidth > 0 {
                x = 0
                y += rowHeight + runSpacing
                rowHeight = 0
            }
            items.append(RowItem(x: x, y: y, size: size, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return items
    }

    private struct RowItem {
        var x: CGFloat
        var y: CGFloat
        var size: CGSize
        var height: CGFloat
    }
}

#Preview {
    ContentView()
}
