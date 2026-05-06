import SwiftUI

struct PlacementTestView: View {
    @ObservedObject var model: PlacementTestModel
    let onSkip:    () -> Void
    let onConfirm: (PlacementResult) -> Void

    @State private var showSkipConfirm = false

    var body: some View {
        ZStack {
            Color.lllbBackground.ignoresSafeArea()

            if model.isFinished {
                resultPane
            } else {
                questionPane
            }

            if showSkipConfirm {
                skipConfirmOverlay
            }
        }
    }

    // MARK: - Question pane

    private var questionPane: some View {
        let nl = model.nativeLanguage
        return VStack(spacing: 0) {
            // Top bar: progress + skip
            HStack {
                Text("\(model.currentIndex + 1) / \(model.totalQuestions)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showSkipConfirm = true
                } label: {
                    Text(L("跳过", "Skip", nativeLanguage: nl))
                        .font(.subheadline)
                        .foregroundStyle(Color.lllbAccent)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            Spacer(minLength: 30)

            if let q = model.currentQuestion {
                VStack(spacing: 16) {
                    Text(q.level)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.lllbTagBg)
                        .clipShape(Capsule())

                    Text(q.prompt)
                        .font(.system(size: 30, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 22)
                }

                Spacer(minLength: 28)

                VStack(spacing: 10) {
                    ForEach(q.options.indices, id: \.self) { i in
                        Button {
                            Haptics.light()
                            model.answer(.option(i))
                        } label: {
                            optionRow(text: q.options[i].resolvedTranslation(nativeLanguage: nl))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        Haptics.soft()
                        model.answer(.unknown)
                    } label: {
                        optionRow(text: L("不知道", "Don't know", nativeLanguage: nl))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)

                Spacer(minLength: 36)
            }
        }
    }

    private func optionRow(text: String) -> some View {
        HStack {
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.lllbCellStroke, lineWidth: 0.5)
        )
    }

    // MARK: - Result pane

    private var resultPane: some View {
        let result = model.computeResult()
        let nl = model.nativeLanguage
        return VStack(spacing: 18) {
            Spacer(minLength: 40)

            Text(L("测试完成", "Test Complete", nativeLanguage: nl))
                .font(.title2.weight(.semibold))

            if model.earlyTerminated {
                Text(L("我们已经掌握了你的水平 ✨",
                       "We've got a good read on your level ✨",
                       nativeLanguage: nl))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 22)
            }

            VStack(spacing: 6) {
                Text(L("起步水平", "Starting level", nativeLanguage: nl))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(result.mainLevel)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(Color.lllbAccent)
            }
            .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text(L("你的初始句库分布", "Your initial pool", nativeLanguage: nl))
                    .font(.subheadline.weight(.semibold))
                    .padding(.bottom, 2)
                ForEach(model.levels, id: \.self) { level in
                    if let n = result.allocation[level], n > 0 {
                        HStack {
                            Text(level)
                                .font(.body.weight(.medium))
                                .frame(width: 40, alignment: .leading)
                            ProgressView(value: Double(n) / 100.0)
                                .tint(Color.lllbAccent)
                            Text(L("\(n) 句", "\(n)", nativeLanguage: nl))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 22)

            Spacer()

            Button {
                Haptics.success()
                onConfirm(result)
            } label: {
                Text(L("开始学习", "Start Learning", nativeLanguage: nl))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.lllbAccent, in: RoundedRectangle(cornerRadius: 13))
                    .foregroundStyle(Color.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 22)
            .padding(.bottom, 36)
        }
    }

    // MARK: - Skip confirm

    private var skipConfirmOverlay: some View {
        let nl = model.nativeLanguage
        return ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 0) {
                Text(L("跳过定级测试？", "Skip placement test?", nativeLanguage: nl))
                    .font(.headline)
                    .padding(.top, 22).padding(.bottom, 10)

                Text(L("跳过后将按初学者起步（100 句 A1）。\n你随时可以正常学习并 archive 句子，更高级别会自然出现。",
                       "Skipping starts you as a beginner (100 A1 sentences). You can still learn and archive normally; higher levels will surface over time.",
                       nativeLanguage: nl))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 18)

                HStack(spacing: 10) {
                    Button {
                        showSkipConfirm = false
                    } label: {
                        Text(L("继续测试", "Keep going", nativeLanguage: nl))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.primary.opacity(0.06),
                                        in: RoundedRectangle(cornerRadius: 11))
                    }
                    .buttonStyle(.plain)

                    Button {
                        Haptics.medium()
                        onSkip()
                    } label: {
                        Text(L("跳过", "Skip", nativeLanguage: nl))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.lllbAccent,
                                        in: RoundedRectangle(cornerRadius: 11))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 36)
        }
    }
}
