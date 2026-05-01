import SwiftUI

// MARK: - Small rings (topBar, 20 pt × 4)

struct ProgressRingsSmall: View {
    let progresses: [Double]   // [today, week, month, lifetime], each 0…1
    let achieved:   [Bool]     // which dimensions have pending milestones

    @State private var startAngles: [Double] = [0, 0, 0, 0]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { i in
                ProgressRing(
                    progress:     achieved[i] ? 1.0 : progresses[i],
                    color:        Color.lllbRingColors[i],
                    startAngle:   startAngles[i],
                    diameter:     20,
                    lineWidth:    3,
                    trackOpacity: 0.10,
                    isAchieved:   achieved[i]
                )
            }
        }
        .onAppear {
            startAngles = (0..<4).map { _ in Double.random(in: 0..<360) }
        }
    }
}

// MARK: - Single ring primitive (shared by small and large)

struct ProgressRing: View {
    let progress:     Double
    let color:        Color
    let startAngle:   Double
    let diameter:     CGFloat
    let lineWidth:    CGFloat
    let trackOpacity: Double
    var isAchieved:   Bool = false

    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(trackOpacity), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(progress.clamped(to: 0...1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: isAchieved ? .butt : .round))
                .rotationEffect(.degrees(startAngle - 90))
            if isAchieved {
                Circle()
                    .trim(from: 0, to: 1.0)
                    .stroke(
                        Color.white.opacity(pulse ? 0.62 : 0.18),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                    )
                    .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: pulse)
            }
        }
        .frame(width: diameter, height: diameter)
        .onAppear { if isAchieved { pulse = true } }
        .onChange(of: isAchieved) { if $0 { pulse = true } else { pulse = false } }
    }
}

// MARK: - Overlay (2×2 large rings, shown on tap)

struct ProgressRingsOverlay: View {
    let progresses:     [Double]   // [today, week, month, lifetime]
    let currentMinutes: [Int]
    let targetMinutes:  [Int?]     // nil = maxed out
    let nativeLanguage: String
    let onDismiss:      () -> Void

    private let diameter:     CGFloat = 126
    private let lineWidth:    CGFloat = 10
    private let trackOpacity: Double  = 0.18

    private var labels: [String] {[
        L("今天", "Today",    nativeLanguage: nativeLanguage),
        L("本周", "Week",     nativeLanguage: nativeLanguage),
        L("本月", "Month",    nativeLanguage: nativeLanguage),
        L("全部", "All time", nativeLanguage: nativeLanguage),
    ]}

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ringCell(0)
                    ringCell(1)
                }
                HStack(spacing: 12) {
                    ringCell(2)
                    ringCell(3)
                }
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .onTapGesture {}
        }
    }

    @ViewBuilder
    private func ringCell(_ i: Int) -> some View {
        ZStack {
            ProgressRing(
                progress:     progresses[i],
                color:        Color.lllbRingColors[i],
                startAngle:   0,
                diameter:     diameter,
                lineWidth:    lineWidth,
                trackOpacity: trackOpacity
            )
            VStack(spacing: 3) {
                Text(labels[i])
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
                Text(formatValue(currentMinutes[i]))
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.lllbRingColors[i])
                Text(formatTarget(targetMinutes[i]))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary.opacity(0.7))
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private func formatValue(_ minutes: Int) -> String {
        if minutes <= 0  { return "0" }
        if minutes < 60  { return "\(minutes)" }
        let hours = Double(minutes) / 60.0
        if minutes < 600 { return String(format: "%.1f", hours) }
        return "\(minutes / 60)"
    }

    private func formatTarget(_ minutes: Int?) -> String {
        guard let minutes else { return L("最高", "Max", nativeLanguage: nativeLanguage) }
        let minLabel = L("分", "min", nativeLanguage: nativeLanguage)
        if minutes < 60 { return "/\(minutes) \(minLabel)" }
        return "/\(minutes / 60) h"
    }
}

// MARK: - Milestone collect card (non-dismissible)

struct MilestoneCollectCard: View {
    let milestones:     [MilestoneDefinition]
    let nativeLanguage: String
    let onCollect:      () -> Void

    private var totalCandy: Int { milestones.reduce(0) { $0 + $1.candyReward } }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            // No tap-to-dismiss — user must tap collect

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    Text(L("里程碑达成", "Milestone Reached", nativeLanguage: nativeLanguage))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    Text(L("收取奖励后继续", "Collect your rewards to continue", nativeLanguage: nativeLanguage))
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                }
                .padding(.top, 24)
                .padding(.bottom, 20)

                Divider()

                // Milestone list
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(milestones) { m in
                            milestoneRow(m)
                            if m.id != milestones.last?.id {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                }
                .frame(maxHeight: 340)

                Divider()

                // Total + collect button
                HStack {
                    Text("🍬 ×\(totalCandy)")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.lllbRingColors[3])
                    Spacer()
                    Button {
                        onCollect()
                    } label: {
                        Text(L("收取", "Collect", nativeLanguage: nativeLanguage))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.lllbAccent, in: Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func milestoneRow(_ m: MilestoneDefinition) -> some View {
        HStack(spacing: 12) {
            // Color badge
            Circle()
                .stroke(ringColor(m.dimension), lineWidth: 2.5)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .fill(ringColor(m.dimension).opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(L(m.titleZh, m.titleEn, nativeLanguage: nativeLanguage))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary)
                Text(L(m.subtitleZh, m.subtitleEn, nativeLanguage: nativeLanguage))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text("+\(m.candyReward)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.lllbRingColors[3])
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func ringColor(_ dimension: MilestoneDimension) -> Color {
        switch dimension {
        case .daily:    return Color.lllbRingColors[0]
        case .weekly:   return Color.lllbRingColors[1]
        case .monthly:  return Color.lllbRingColors[2]
        case .lifetime: return Color.lllbRingColors[3]
        }
    }
}

// MARK: - Double extension

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
