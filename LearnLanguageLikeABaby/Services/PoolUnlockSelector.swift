import Foundation

/// Picks the next sentence to unlock when the pool drops below capacity.
/// One call per quota slot; tag-group expansion happens at the call site.
protocol PoolUnlockSelector {
    func pickNext(pool: [LessonSentence], candidates: [LessonSentence]) -> LessonSentence?
}

/// Distribution-aware selector with floor + look-ahead.
///
/// Algorithm:
///   1. Build a probability per available level from current pool proportions.
///   2. Apply per-level floor so a present-but-rare level isn't starved.
///   3. Give the next CEFR level above the pool's highest a `lookaheadFloor`
///      bonus, exposing the user to slightly harder material gradually.
///   4. Optional ceiling caps any single level (prevents one level dominating).
///   5. Renormalize, sample a level, then pick a uniform random sentence at
///      that level. Falls back to uniform across all candidates if levels
///      can't be resolved (defensive — shouldn't happen in practice).
struct ProportionalUnlockSelector: PoolUnlockSelector {
    static let levelOrder = ["A1", "A2", "B1", "B2", "C1", "C2"]

    var floorByLevel:   [String: Double]
    var lookaheadFloor: Double
    var ceiling:        Double?

    static let `default` = ProportionalUnlockSelector(
        floorByLevel: [
            "A1": 0.10,
            "A2": 0.07,
            "B1": 0.05,
            "B2": 0.03,
            "C1": 0.02,
            "C2": 0.01,
        ],
        lookaheadFloor: 0.10,
        ceiling: 0.65
    )

    func pickNext(pool: [LessonSentence], candidates: [LessonSentence]) -> LessonSentence? {
        guard !candidates.isEmpty else { return nil }

        let candByLevel = Dictionary(grouping: candidates, by: \.cefr)
        let availableLevels = candByLevel.keys

        let poolByLevel = Dictionary(grouping: pool, by: \.cefr).mapValues { Double($0.count) }
        let poolTotal   = max(poolByLevel.values.reduce(0, +), 1)

        var prob: [String: Double] = [:]
        for level in availableLevels {
            let raw   = (poolByLevel[level] ?? 0) / poolTotal
            let floor = floorByLevel[level] ?? 0
            prob[level] = max(raw, floor)
        }

        let presentLevels = poolByLevel.keys.filter { (poolByLevel[$0] ?? 0) > 0 }
        if let maxIdx = Self.levelOrder.lastIndex(where: { presentLevels.contains($0) }),
           maxIdx + 1 < Self.levelOrder.count {
            let nextLevel = Self.levelOrder[maxIdx + 1]
            if candByLevel[nextLevel] != nil {
                prob[nextLevel] = max(prob[nextLevel] ?? 0, lookaheadFloor)
            }
        }

        if let cap = ceiling {
            for k in prob.keys { prob[k] = min(prob[k]!, cap) }
        }

        let total = prob.values.reduce(0, +)
        guard total > 0 else { return candidates.randomElement() }

        var pick = Double.random(in: 0..<total)
        var chosenLevel: String?
        for level in prob.keys.sorted() {
            pick -= prob[level]!
            if pick <= 0 { chosenLevel = level; break }
        }
        let level = chosenLevel ?? prob.keys.sorted().last!

        return candByLevel[level]?.randomElement() ?? candidates.randomElement()
    }
}
