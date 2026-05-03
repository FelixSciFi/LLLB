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
    /// When non-nil, the arc is rendered two-tone: full-color from 0 to
    /// `activeProgress`, lighter from there to `progress`. Used by the 2×2
    /// overlay to encode 主动 vs 被动/3 within the same ring.
    var activeProgress: Double? = nil

    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(trackOpacity), lineWidth: lineWidth)

            // Total arc — lighter when two-tone (so the active overlay reads
            // as "the deeper part") otherwise full color.
            Circle()
                .trim(from: 0, to: CGFloat(progress.clamped(to: 0...1)))
                .stroke(
                    activeProgress != nil ? color.opacity(0.45) : color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: isAchieved ? .butt : .round)
                )
                .rotationEffect(.degrees(startAngle - 90))
                .shadow(
                    color: isAchieved ? color.opacity(pulse ? 0.85 : 0.25) : .clear,
                    radius: isAchieved ? (pulse ? max(4, diameter * 0.10) : 1) : 0
                )

            // Two-tone overlay: 主动 portion on top
            if let active = activeProgress {
                Circle()
                    .trim(from: 0, to: CGFloat(active.clamped(to: 0...1)))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: isAchieved ? .butt : .round))
                    .rotationEffect(.degrees(startAngle - 90))
            }

            if isAchieved {
                Circle()
                    .trim(from: 0, to: 1.0)
                    .stroke(
                        Color.white.opacity(pulse ? 0.92 : 0.18),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                    )
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(
            isAchieved
                ? .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
                : .default,
            value: pulse
        )
        .onAppear { if isAchieved { pulse = true } }
        .onChange(of: isAchieved) { if $0 { pulse = true } else { pulse = false } }
    }
}

// MARK: - Threshold formatting helper

enum MilestoneFormat {
    /// Compact human-readable threshold (e.g., 30 → "30", 90 → "1.5h", 600 → "10h").
    static func threshold(_ minutes: Int, nativeLanguage nl: String) -> String {
        let minLabel = L("分", "m", nativeLanguage: nl)
        if minutes < 60 { return "\(minutes)\(minLabel)" }
        let hours = Double(minutes) / 60.0
        if minutes < 600 { return String(format: "%.1fh", hours) }
        return "\(minutes / 60)h"
    }

    /// Current-value formatting matching the rings UI.
    static func currentValue(_ minutes: Int) -> String {
        if minutes <= 0  { return "0" }
        if minutes < 60  { return "\(minutes)" }
        let hours = Double(minutes) / 60.0
        if minutes < 600 { return String(format: "%.1f", hours) }
        return "\(minutes / 60)"
    }
}

// MARK: - Single milestone badge (ring style)

struct MilestoneBadge: View {
    let milestone: MilestoneDefinition
    let achieved:  Bool
    /// Diameter of the badge ring in points.
    var diameter:  CGFloat = 90
    var nativeLanguage: String

    private var color: Color {
        switch milestone.dimension {
        case .daily:    return Color.lllbRingColors[0]
        case .weekly:   return Color.lllbRingColors[1]
        case .monthly:  return Color.lllbRingColors[2]
        case .lifetime: return Color.lllbRingColors[3]
        }
    }

    private var ringWidth: CGFloat { max(3, diameter * 0.06) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Outer ring — solid continuous stroke either way; "locked"
                // is conveyed purely via desaturation, not dash pattern.
                Circle()
                    .stroke(
                        achieved ? color : Color.secondary.opacity(0.22),
                        lineWidth: ringWidth
                    )
                    .frame(width: diameter, height: diameter)

                // Inner fill
                Circle()
                    .fill(achieved ? color.opacity(0.10) : Color.secondary.opacity(0.04))
                    .frame(width: diameter - ringWidth * 2, height: diameter - ringWidth * 2)

                // Threshold label
                Text(MilestoneFormat.threshold(milestone.thresholdMinutes, nativeLanguage: nativeLanguage))
                    .font(.system(size: diameter * 0.24, weight: .bold, design: .rounded))
                    .foregroundStyle(achieved ? color : Color.secondary.opacity(0.50))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
            }

            VStack(spacing: 2) {
                Text(L(milestone.titleZh, milestone.titleEn, nativeLanguage: nativeLanguage))
                    .font(.system(size: diameter * 0.13, weight: .semibold))
                    .foregroundStyle(achieved ? Color.primary : Color.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("+\(milestone.candyReward) 🍬")
                    .font(.system(size: diameter * 0.11, weight: .medium, design: .rounded))
                    .foregroundStyle(achieved ? Color.lllbRingColors[3] : Color.secondary.opacity(0.55))
            }
            .frame(width: diameter * 1.15)
        }
    }
}

// MARK: - Overlay (original 2×2 layout — tapping a ring drills into its catalog)

struct ProgressRingsOverlay: View {
    let progresses:     [Double]   // [today, week, month, lifetime] effective (active + passive/3) / target
    let currentMinutes: [Int]      // effective minutes (matches ring big number)
    let activeMinutes:  [Int]      // raw active per dimension
    let passiveMinutes: [Int]      // raw passive per dimension
    let targetMinutes:  [Int?]     // nil = maxed out
    let nativeLanguage: String
    @ObservedObject var achievementManager: AchievementManager
    let onDismiss:      () -> Void

    private let diameter:     CGFloat = 126
    private let lineWidth:    CGFloat = 10
    private let trackOpacity: Double  = 0.18

    @State private var selected: Int? = nil   // 0…3 = dimension index, nil = grid

    private var labels: [String] {[
        L("今天", "Today",    nativeLanguage: nativeLanguage),
        L("本周", "Week",     nativeLanguage: nativeLanguage),
        L("本月", "Month",    nativeLanguage: nativeLanguage),
        L("全部", "All time", nativeLanguage: nativeLanguage),
    ]}

    private static let dimensionByIndex: [MilestoneDimension] =
        [.daily, .weekly, .monthly, .lifetime]

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    if selected != nil {
                        Haptics.soft()
                        selected = nil
                    } else {
                        onDismiss()
                    }
                }

            // Plain instant swap — no transition, no animation.
            if let i = selected {
                detailCard(for: i)
            } else {
                gridCard
            }
        }
    }

    // MARK: 2×2 grid

    private var gridCard: some View {
        VStack(spacing: 14) {
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
            // Footer: explains the deep / light arc encoding.
            Text(L("学习时间 = 主动 + 被动 ÷ 3",
                   "Learning time = active + passive ÷ 3",
                   nativeLanguage: nativeLanguage))
                .font(.system(size: 10))
                .foregroundStyle(.secondary.opacity(0.75))
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .onTapGesture {}   // swallow so background tap-to-dismiss doesn't fire
    }

    /// active / threshold for the two-tone arc. Falls back to total progress
    /// when threshold is unknown (max-out state).
    private func activeProgressForRing(_ i: Int) -> Double {
        guard let target = targetMinutes[i], target > 0 else { return progresses[i] }
        return min(progresses[i], Double(activeMinutes[i]) / Double(target))
    }

    @ViewBuilder
    private func ringCell(_ i: Int) -> some View {
        Button {
            Haptics.light()
            selected = i
        } label: {
            ZStack {
                ProgressRing(
                    progress:       progresses[i],
                    color:          Color.lllbRingColors[i],
                    startAngle:     0,
                    diameter:       diameter,
                    lineWidth:      lineWidth,
                    trackOpacity:   trackOpacity,
                    activeProgress: activeProgressForRing(i)
                )
                VStack(spacing: 2) {
                    Text(labels[i])
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                    Text(formatValue(currentMinutes[i]))
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.lllbRingColors[i])
                    Text(formatTarget(targetMinutes[i]))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary.opacity(0.7))
                    // Per-ring active / passive breakdown — small, annotation-only.
                    Text("\(L("主", "A", nativeLanguage: nativeLanguage)) \(activeMinutes[i]) · \(L("被", "P", nativeLanguage: nativeLanguage)) \(passiveMinutes[i])")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .monospacedDigit()
                        .padding(.top, 1)
                }
            }
            .frame(width: diameter, height: diameter)
        }
        .buttonStyle(.plain)
    }

    // MARK: Drill-down catalog for one dimension

    @ViewBuilder
    private func detailCard(for i: Int) -> some View {
        let dim   = Self.dimensionByIndex[i]
        let color = Color.lllbRingColors[i]
        let items = AchievementManager.allMilestones
            .filter { $0.dimension == dim }
            .sorted { $0.thresholdMinutes < $1.thresholdMinutes }
        let earned = items.filter { achievementManager.isEverAchieved($0.id) }.count

        VStack(spacing: 0) {
            // Header: back chevron + label + count
            HStack(spacing: 10) {
                Button {
                    Haptics.soft()
                    selected = nil
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.lllbAccent)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Circle().fill(color).frame(width: 9, height: 9)
                Text(labels[i])
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Spacer()
                Text("\(earned) / \(items.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView(showsIndicators: false) {
                let cols = [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)]
                LazyVGrid(columns: cols, spacing: 22) {
                    ForEach(items) { m in
                        MilestoneBadge(
                            milestone:      m,
                            achieved:       achievementManager.isEverAchieved(m.id),
                            diameter:       96,
                            nativeLanguage: nativeLanguage
                        )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: 540)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding(.horizontal, 16)
        .onTapGesture {}
    }

    // MARK: Formatters (unchanged)

    private func formatValue(_ minutes: Int) -> String {
        let minLabel = L("分", "min", nativeLanguage: nativeLanguage)
        if minutes <= 0  { return "0 \(minLabel)" }
        if minutes < 60  { return "\(minutes) \(minLabel)" }
        let hours = Double(minutes) / 60.0
        if minutes < 600 { return String(format: "%.1f h", hours) }
        return "\(minutes / 60) h"
    }

    private func formatTarget(_ minutes: Int?) -> String {
        guard let minutes else { return L("最高", "Max", nativeLanguage: nativeLanguage) }
        let minLabel = L("分", "min", nativeLanguage: nativeLanguage)
        if minutes < 60 { return "/\(minutes) \(minLabel)" }
        return "/\(minutes / 60) h"
    }
}

// MARK: - Milestone collect card (badge style, non-dismissible)

struct MilestoneCollectCard: View {
    let milestones:     [MilestoneDefinition]
    let nativeLanguage: String
    let onCollect:      () -> Void

    private var totalCandy: Int { milestones.reduce(0) { $0 + $1.candyReward } }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
            // No tap-to-dismiss — user must tap collect

            VStack(spacing: 22) {
                Text(milestones.count == 1
                     ? L("里程碑达成", "Milestone Reached",  nativeLanguage: nativeLanguage)
                     : L("解锁了 \(milestones.count) 个里程碑",
                         "\(milestones.count) Milestones Reached",
                         nativeLanguage: nativeLanguage))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .padding(.top, 26)

                badgeArea

                // Subtitle for the single-milestone case (since user has space)
                if milestones.count == 1, let m = milestones.first {
                    Text(L(m.subtitleZh, m.subtitleEn, nativeLanguage: nativeLanguage))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Button {
                    onCollect()
                } label: {
                    HStack(spacing: 8) {
                        Text(L("收取", "Collect", nativeLanguage: nativeLanguage))
                            .font(.system(size: 16, weight: .semibold))
                        Text("+\(totalCandy) 🍬")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color.lllbAccent, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 26)
            }
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var badgeArea: some View {
        if milestones.count == 1, let m = milestones.first {
            // Single big badge
            MilestoneBadge(
                milestone:      m,
                achieved:       true,
                diameter:       150,
                nativeLanguage: nativeLanguage
            )
            .padding(.horizontal, 24)
        } else if milestones.count <= 4 {
            // 2-4: grid (2 columns)
            let cols = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
            LazyVGrid(columns: cols, spacing: 18) {
                ForEach(milestones) { m in
                    MilestoneBadge(
                        milestone:      m,
                        achieved:       true,
                        diameter:       96,
                        nativeLanguage: nativeLanguage
                    )
                }
            }
            .padding(.horizontal, 24)
        } else {
            // 5+: scrollable grid
            ScrollView(showsIndicators: false) {
                let cols = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
                LazyVGrid(columns: cols, spacing: 18) {
                    ForEach(milestones) { m in
                        MilestoneBadge(
                            milestone:      m,
                            achieved:       true,
                            diameter:       90,
                            nativeLanguage: nativeLanguage
                        )
                    }
                }
                .padding(.horizontal, 24)
            }
            .frame(maxHeight: 360)
        }
    }
}

// MARK: - Double extension

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
