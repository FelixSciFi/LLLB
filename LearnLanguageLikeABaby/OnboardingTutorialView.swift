import SwiftUI
import AVFoundation

// MARK: - Voice quality detection

/// One-shot per-language advice on the TTS voice the user is currently
/// going to hear. Used by the home top-bar "音质不佳" hint button — see
/// VoiceUpgradeHintButton (added in step C).
enum VoiceUpgradeAdvice: Equatable {
    case none
    case selectInApp
    case downloadFromSettings

    var needsHint: Bool { self != .none }
}

enum VoiceQualityCheck {
    static func advice(for ttsLocale: String) -> VoiceUpgradeAdvice {
        let code = String(ttsLocale.prefix(2))
        if let dict = UserDefaults.standard.dictionary(forKey: "voiceByLanguage") as? [String: String],
           dict[code] != nil {
            return .none
        }
        let fallback = AVSpeechSynthesisVoice(language: ttsLocale)
                    ?? AVSpeechSynthesisVoice(language: code)
        if (fallback?.quality ?? .default) != .default {
            return .none
        }
        let hasBetter = AVSpeechSynthesisVoice.speechVoices()
            .contains { $0.language.hasPrefix(code) && $0.quality != .default }
        return hasBetter ? .selectInApp : .downloadFromSettings
    }
}

// MARK: - Voice hint sheet (user-triggered from home top bar)

/// Shown when the user taps the "音质" pill in ContentView's top bar.
/// Two paths depending on `advice`:
///   .selectInApp        → CTA opens Profile so user can pick a voice
///   .downloadFromSettings → CTA closes; copy explains the system-Settings
///                           trail (no public deep link to that screen)
struct VoiceHintSheet: View {
    let advice: VoiceUpgradeAdvice
    let nativeLanguage: String
    let onOpenProfile: () -> Void
    let onSilence: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.lllbBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                header
                Divider()
                detailBlock
                Spacer()
                primaryCTA
                Button(action: onSilence) {
                    Text(L("不再提醒", "Don't show again",
                           nativeLanguage: nativeLanguage))
                        .font(.system(size: 14))
                        .foregroundStyle(Color.lllbSecondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("音质可以更好", "Better voice available",
                       nativeLanguage: nativeLanguage))
                    .font(.system(size: 20, weight: .bold))
                Text(L("LLLB 听感非常依赖发音质量",
                       "Listening quality really matters for LLLB",
                       nativeLanguage: nativeLanguage))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lllbSecondaryText)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.lllbChipStroke)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var detailBlock: some View {
        switch advice {
        case .selectInApp:
            VStack(alignment: .leading, spacing: 10) {
                Text(L("当前播放用的是系统标准语音，比较机械。",
                       "You're playing with the standard system voice — it sounds robotic.",
                       nativeLanguage: nativeLanguage))
                    .font(.system(size: 15))
                Text(L("你的设备里已经有更自然的发音，去「我的 → 语音」选一个就好。",
                       "Your device already has more natural voices — pick one in Profile → Voices.",
                       nativeLanguage: nativeLanguage))
                    .font(.system(size: 15))
                    .foregroundStyle(Color.lllbSecondaryText)
            }
        case .downloadFromSettings:
            VStack(alignment: .leading, spacing: 10) {
                Text(L("当前没有可用的高品质语音包，需要先到系统下载。",
                       "No higher-quality voice is installed yet — you have to download one in system Settings first.",
                       nativeLanguage: nativeLanguage))
                    .font(.system(size: 15))
                VStack(alignment: .leading, spacing: 8) {
                    stepLine("1", L("打开「设置」", "Open Settings", nativeLanguage: nativeLanguage))
                    stepLine("2", L("辅助功能", "Accessibility", nativeLanguage: nativeLanguage))
                    stepLine("3", L("朗读内容 → 声音", "Spoken Content → Voices", nativeLanguage: nativeLanguage))
                    stepLine("4", L("选「增强」或「高品质」下载（约 100 MB）",
                                    "Tap Enhanced or Premium to download (~100 MB)",
                                    nativeLanguage: nativeLanguage))
                }
                .padding(12)
                .background(Color.lllbChipBg.opacity(0.6),
                            in: RoundedRectangle(cornerRadius: 12))
            }
        case .none:
            EmptyView()
        }
    }

    private func stepLine(_ num: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(num)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Color.lllbAccent, in: Circle())
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color.primary)
        }
    }

    @ViewBuilder
    private var primaryCTA: some View {
        switch advice {
        case .selectInApp:
            Button(action: onOpenProfile) {
                Text(L("去选语音", "Pick a voice", nativeLanguage: nativeLanguage))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.lllbAccent, in: Capsule())
            }
            .buttonStyle(.plain)
        case .downloadFromSettings:
            Button(action: onClose) {
                Text(L("我知道了", "Got it", nativeLanguage: nativeLanguage))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.lllbAccent, in: Capsule())
            }
            .buttonStyle(.plain)
        case .none:
            EmptyView()
        }
    }
}

// MARK: - Tutorial anchor preference

/// IDs for the regions of ContentView that the spotlight tutorial wants to
/// highlight. Each region attaches `.tutorialAnchor(.foo)` and ContentView
/// collects the resulting frames into a `[TutorialAnchorID: CGRect]` map.
enum TutorialAnchorID: String {
    case sentenceArea
    case leftColumn
    case rightColumn
    case profileButton
}

struct TutorialAnchorKey: PreferenceKey {
    static var defaultValue: [TutorialAnchorID: CGRect] = [:]
    static func reduce(value: inout [TutorialAnchorID: CGRect],
                       nextValue: () -> [TutorialAnchorID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    /// Reports this view's global frame to TutorialAnchorKey under the
    /// given id. Use on the same view (or wrapper) whose bounds you want
    /// the spotlight to draw around.
    func tutorialAnchor(_ id: TutorialAnchorID) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: TutorialAnchorKey.self,
                    value: [id: proxy.frame(in: .global)]
                )
            }
        )
    }
}

// MARK: - Spotlight overlay

/// Non-blocking spotlight tutorial that lives inside ContentView's ZStack.
/// Behaviour:
/// - Translucent dark mask covers the whole screen but is `.allowsHitTesting(false)`.
/// - A pulsing rounded-rect outline frames the current target region (read
///   from `anchors`).
/// - A copy bubble floats on the opposite side of the target from screen
///   center, so the bubble never covers what it points at.
/// - Bottom-anchored "跳过 / 下一步 / 完成" controls are hit-testable; the
///   user can otherwise interact with the real UI through the mask.
struct TutorialSpotlightOverlay: View {
    let nativeLanguage: String
    let anchors: [TutorialAnchorID: CGRect]
    let onDone: (_ skipped: Bool) -> Void

    @State private var step: Int = 0
    private let totalSteps: Int = 5

    var body: some View {
        GeometryReader { geo in
            // Anchors are reported in global coords (.frame(in: .global));
            // .position() expects this view's local coords. Subtract this
            // GeometryReader's own global origin to convert.
            let originGlobal = geo.frame(in: .global).origin
            let target = currentAnchor.map { rect in
                CGRect(x: rect.minX - originGlobal.x,
                       y: rect.minY - originGlobal.y,
                       width:  rect.width,
                       height: rect.height)
            }
            ZStack(alignment: .topLeading) {
                // Dim mask — visual only, doesn't block touches.
                Color.black.opacity(0.42)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                if let r = target {
                    // Step 0 = global swipe gesture; framing the sentence
                    // area would mislead (you can swipe anywhere). Skip the
                    // outline and just paint the finger demo.
                    if step != 0 {
                        spotlightFrame(for: r, anchorID: currentAnchorID)
                            .allowsHitTesting(false)
                    }
                    gestureDemo(for: r)
                        .allowsHitTesting(false)
                    bubble(for: r, in: geo.size)
                } else {
                    // Anchor hasn't reported yet — fall back to centered bubble.
                    bubble(for: CGRect(x: geo.size.width/2,
                                       y: geo.size.height/2,
                                       width: 0, height: 0),
                           in: geo.size)
                }

                // Bottom cluster: progress dots + skip/next.
                // Lives at the very bottom so it never collides with the
                // ContentView top bar or the floating profile button at
                // bottom-right.
                bottomCluster(width: geo.size.width)
                    .position(x: geo.size.width / 2,
                              y: geo.size.height - 56)
            }
        }
        .transition(.opacity)
    }

    // MARK: subviews

    private func bottomCluster(width: CGFloat) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 7) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i == step ? Color.lllbAccent : Color.white.opacity(0.55))
                        .frame(width: i == step ? 8 : 6,
                               height: i == step ? 8 : 6)
                        .animation(.easeInOut(duration: 0.2), value: step)
                }
            }
            HStack(spacing: 16) {
                Button(action: { Haptics.light(); onDone(true) }) {
                    Text(L("跳过", "Skip", nativeLanguage: nativeLanguage))
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
                Button(action: advance) {
                    Text(isLastStep
                         ? L("完成", "Done", nativeLanguage: nativeLanguage)
                         : L("下一步", "Next", nativeLanguage: nativeLanguage))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.lllbAccent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: width)
    }

    @ViewBuilder
    private func gestureDemo(for rect: CGRect) -> some View {
        switch step {
        case 0:
            SwipeFingerAnimation()
                .position(x: rect.midX, y: rect.midY)
        case 1:
            TapFingerAnimation()
                .position(x: rect.midX, y: rect.midY)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func spotlightFrame(for rect: CGRect, anchorID: TutorialAnchorID?) -> some View {
        // Profile button is round → outline with a Circle, smaller inset.
        // Other regions are rectangular → rounded-rect outline.
        let isCircular = anchorID == .profileButton
        let inset: CGFloat = isCircular ? 3 : 5
        if isCircular {
            Circle()
                .stroke(Color.lllbAccent, lineWidth: 2.5)
                .frame(width: rect.width + inset * 2,
                       height: rect.height + inset * 2)
                .position(x: rect.midX, y: rect.midY)
                .shadow(color: Color.lllbAccent.opacity(0.5), radius: 5)
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.lllbAccent, lineWidth: 2.5)
                .frame(width: rect.width + inset * 2,
                       height: rect.height + inset * 2)
                .position(x: rect.midX, y: rect.midY)
                .shadow(color: Color.lllbAccent.opacity(0.5), radius: 6)
        }
    }

    @ViewBuilder
    private func bubble(for rect: CGRect, in screen: CGSize) -> some View {
        let bubbleW: CGFloat = min(screen.width - 48, 320)
        // Estimated height — generous so 2-3 line copy fits without clipping.
        let bubbleH: CGFloat = 130
        let gap: CGFloat = 24
        // Reserved zones to keep the bubble out of:
        //   topReserved    — ContentView top bar (~58 incl. safe area)
        //   bottomReserved — our own bottom cluster (~140)
        let topReserved: CGFloat = 70
        let bottomReserved: CGFloat = 140
        let bubbleTopMin = topReserved
        let bubbleTopMax = screen.height - bottomReserved - bubbleH

        // Place above target if target sits in the lower half of the screen,
        // below otherwise. Then clamp into the safe zone so bottom cluster
        // and ContentView top bar are never covered.
        let placeAbove = rect.midY > screen.height * 0.5
        let preferredTopY = placeAbove
            ? rect.minY - gap - bubbleH
            : rect.maxY + gap
        let topY = max(bubbleTopMin, min(bubbleTopMax, preferredTopY))

        VStack(alignment: .leading, spacing: 6) {
            Text(stepTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.primary)
            Text(stepDetail)
                .font(.system(size: 14))
                .foregroundStyle(Color.lllbSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: bubbleW, alignment: .leading)
        .background(.regularMaterial,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.lllbAccent.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 10, y: 3)
        .position(x: screen.width / 2, y: topY + bubbleH / 2)
    }

    // MARK: navigation

    private var isLastStep: Bool { step >= totalSteps - 1 }

    private func advance() {
        Haptics.light()
        if isLastStep { onDone(false) }
        else { withAnimation(.easeInOut(duration: 0.22)) { step += 1 } }
    }

    // MARK: per-step content

    private var currentAnchorID: TutorialAnchorID? {
        switch step {
        case 0: return .sentenceArea
        case 1: return .sentenceArea
        case 2: return .leftColumn
        case 3: return .rightColumn
        case 4: return .profileButton
        default: return nil
        }
    }
    private var currentAnchor: CGRect? {
        guard let id = currentAnchorID else { return nil }
        return anchors[id]
    }

    private var stepTitle: String {
        switch step {
        case 0: return L("上下滑切换句子",
                         "Swipe up or down",
                         nativeLanguage: nativeLanguage)
        case 1: return L("点词专项学习",
                         "Tap to drill a word",
                         nativeLanguage: nativeLanguage)
        case 2: return L("左侧调播放",
                         "Left side: playback",
                         nativeLanguage: nativeLanguage)
        case 3: return L("右侧管显示和收藏",
                         "Right side: display & sort",
                         nativeLanguage: nativeLanguage)
        case 4: return L("「我的」里有更多",
                         "More in Profile",
                         nativeLanguage: nativeLanguage)
        default: return ""
        }
    }

    private var stepDetail: String {
        switch step {
        case 0: return L("上滑下一句，下滑上一句。可以现在试试。",
                         "Swipe up for next, down for previous. Try it now if you like.",
                         nativeLanguage: nativeLanguage)
        case 1: return L("点任何一个词，循环播放含这个词的例句，反复听到学会为止。",
                         "Tap any word to loop sentences that use it — listen until it sticks.",
                         nativeLanguage: nativeLanguage)
        case 2: return L("从上到下：播放模式、词句库、语速、重复次数、播放/暂停。",
                         "Top to bottom: play mode, library, speed, repeats, play/pause.",
                         nativeLanguage: nativeLanguage)
        case 3: return L("上半：图、字、音标、翻译的显示开关。下半：把这句标记为收藏 / 熟悉 / 学会 / 稍后。",
                         "Top: toggle image, text, IPA, translation. Bottom: mark as liked / familiar / mastered / later.",
                         nativeLanguage: nativeLanguage)
        case 4: return L("切换语言、查看词句库、设置睡眠定时——都在这里。重看本指引也在这里。",
                         "Switch language, browse your collection, set the sleep timer — all here. Replay this walkthrough lives here too.",
                         nativeLanguage: nativeLanguage)
        default: return ""
        }
    }
}

// MARK: - Gesture demo overlays

/// Translucent finger that drifts up and down to demonstrate the swipe
/// gesture. Two trailing dots fade behind it as a motion trail. Caller
/// `.position(...)`s this view at the centre of the target region.
private struct SwipeFingerAnimation: View {
    @State private var offsetY: CGFloat = -50

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.lllbAccent.opacity(0.18))
                .frame(width: 22, height: 22)
                .offset(y: offsetY * 0.55)
            Circle()
                .fill(Color.lllbAccent.opacity(0.32))
                .frame(width: 26, height: 26)
                .offset(y: offsetY * 0.78)
            ZStack {
                Circle()
                    .fill(Color.lllbAccent.opacity(0.40))
                    .frame(width: 38, height: 38)
                Circle()
                    .fill(Color.lllbAccent)
                    .frame(width: 18, height: 18)
            }
            .offset(y: offsetY)
        }
        .shadow(color: Color.lllbAccent.opacity(0.4), radius: 6)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                offsetY = 50
            }
        }
    }
}

/// Translucent finger that taps in place; on each tap a ring expands and
/// fades to mimic the focus-mode confirmation feedback.
private struct TapFingerAnimation: View {
    @State private var ringScale: CGFloat = 0.6
    @State private var ringOpacity: Double = 0.0
    @State private var fingerScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.lllbAccent, lineWidth: 2)
                .frame(width: 44, height: 44)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)
            ZStack {
                Circle()
                    .fill(Color.lllbAccent.opacity(0.40))
                    .frame(width: 36, height: 36)
                Circle()
                    .fill(Color.lllbAccent)
                    .frame(width: 16, height: 16)
            }
            .scaleEffect(fingerScale)
        }
        .shadow(color: Color.lllbAccent.opacity(0.4), radius: 6)
        .onAppear {
            withAnimation(.easeOut(duration: 0.85).repeatForever(autoreverses: false)) {
                ringScale = 2.2
                ringOpacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                ringOpacity = 0.95
            }
            withAnimation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true)) {
                fingerScale = 0.82
            }
        }
    }
}
