import Foundation

/// Picks the next sentence to unlock when the pool needs more content.
/// One call per slot; tag-group expansion happens at the call site.
/// Receives `levelOrder` so it can apply position-based floors and lookahead
/// without knowing any specific level name (CEFR / HSK / JLPT / custom — all work).
protocol PoolUnlockSelector {
    func pickNext(pool: [LessonSentence],
                  candidates: [LessonSentence],
                  levelOrder: [String]) -> LessonSentence?
}

/// Distribution-aware selector with position-based floor + look-ahead.
///
/// Algorithm (per pick):
///   1. Build a probability per available level from current pool proportions.
///   2. Apply floor by **position in `levelOrder`** (not by level name) so a
///      present-but-rare level isn't starved. Lower positions (easier levels)
///      get higher floors.
///   3. Give the level **one position above** the pool's highest a `lookaheadFloor`
///      bonus — exposes user to slightly harder material gradually.
///   4. Optional ceiling caps any single level (prevents one level dominating).
///   5. Renormalize, sample a level, then pick a uniform random sentence.
struct ProportionalUnlockSelector: PoolUnlockSelector {
    /// Floor by position in `levelOrder`. Index 0 = lowest level, index N = highest.
    /// Levels at positions beyond this array's length get 0 floor.
    var floorByPosition: [Double]
    var lookaheadFloor:  Double
    var ceiling:         Double?

    static let `default` = ProportionalUnlockSelector(
        floorByPosition: [0.10, 0.07, 0.05, 0.03, 0.02, 0.01],
        lookaheadFloor:  0.10,
        ceiling:         0.65
    )

    func pickNext(pool: [LessonSentence],
                  candidates: [LessonSentence],
                  levelOrder: [String]) -> LessonSentence? {
        guard !candidates.isEmpty else { return nil }

        let candByLevel = Dictionary(grouping: candidates, by: \.cefr)
        let poolByLevel = Dictionary(grouping: pool, by: \.cefr).mapValues { Double($0.count) }
        let poolTotal   = max(poolByLevel.values.reduce(0, +), 1)

        // Hard ceiling on position: anything above (max-present-in-pool + 1) gets 0
        // probability. Empty pool ⇒ only position 0 allowed (true beginner). This
        // prevents B2/C2 from leaking when you're at A2 just because they have a floor.
        let presentPositions = poolByLevel.keys.compactMap { levelOrder.firstIndex(of: $0) }
        let allowedMaxPos    = (presentPositions.max() ?? -1) + 1   // pool empty → 0

        var weights: [String: Double] = [:]
        for (level, _) in candByLevel {
            let pos = levelOrder.firstIndex(of: level) ?? Int.max
            guard pos <= allowedMaxPos else { continue }   // hard cap
            let raw   = (poolByLevel[level] ?? 0) / poolTotal
            let floor = pos < floorByPosition.count ? floorByPosition[pos] : 0.0
            weights[level] = max(raw, floor)
        }

        // Lookahead bump for the level at allowedMaxPos (the +1 above pool's max).
        if allowedMaxPos < levelOrder.count {
            let next = levelOrder[allowedMaxPos]
            if candByLevel[next] != nil {
                weights[next] = max(weights[next] ?? 0, lookaheadFloor)
            }
        }

        if let cap = ceiling {
            for k in weights.keys { weights[k] = min(weights[k]!, cap) }
        }

        let total = weights.values.reduce(0, +)
        guard total > 0 else { return candidates.randomElement() }

        var pick = Double.random(in: 0..<total)
        var chosen: String?
        for level in weights.keys.sorted() {
            pick -= weights[level]!
            if pick <= 0 { chosen = level; break }
        }
        let level = chosen ?? weights.keys.sorted().last!

        return candByLevel[level]?.randomElement() ?? candidates.randomElement()
    }
}
