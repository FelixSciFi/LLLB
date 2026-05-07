import Foundation
import SwiftUI

enum PlacementAnswer: Equatable {
    case option(Int)   // user picked option at index
    case unknown       // user clicked "不知道"
}

struct PlacementResult: Equatable {
    /// Per-level correctness rate (0...1). Levels reached but not answered count as 0.
    /// Levels skipped due to early termination also count as 0.
    let competence: [String: Double]
    /// Highest level walked up to with ≥50% correctness; "A1" by default.
    let mainLevel: String
    /// Whether the user actually passed `mainLevel` (vs. defaulting to it as a fallback).
    let mainPassed: Bool
    /// Sentence pool allocation per level — sums to 100.
    let allocation: [String: Int]
}

@MainActor
final class PlacementTestModel: ObservableObject {
    /// Levels actually present in this test, sorted easiest → hardest.
    /// Derived from the question bank — supports any level system (CEFR, HSK, JLPT, …).
    let levels: [String]
    let questions: [PlacementQuestion]   // ordered by `levels`
    let nativeLanguage: String

    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var answers: [String: PlacementAnswer] = [:]
    @Published private(set) var isFinished: Bool = false
    @Published private(set) var earlyTerminated: Bool = false

    init(questions: [PlacementQuestion], nativeLanguage: String, levelOrder: [String]) {
        let presentLevels = Array(Set(questions.map(\.level)))
        let sortedLevels  = LevelSystem.sorted(presentLevels, using: levelOrder)
        self.levels = sortedLevels
        // Shuffle each question's options so the correct answer isn't always
        // at the same index (JSON banks are authored with correctIndex=0 for
        // ease of editing). Re-derive correctIndex from the new order.
        let shuffled = questions.map { q -> PlacementQuestion in
            var idxs = Array(q.options.indices)
            idxs.shuffle()
            let reordered    = idxs.map { q.options[$0] }
            let newCorrectAt = idxs.firstIndex(of: q.correctIndex) ?? 0
            return PlacementQuestion(
                id: q.id, level: q.level, kind: q.kind, prompt: q.prompt,
                options: reordered, correctIndex: newCorrectAt
            )
        }
        self.questions = shuffled.sorted { a, b in
            (sortedLevels.firstIndex(of: a.level) ?? 99) < (sortedLevels.firstIndex(of: b.level) ?? 99)
        }
        self.nativeLanguage = nativeLanguage
    }

    var currentQuestion: PlacementQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var totalAnswered: Int { answers.count }
    var totalQuestions: Int { questions.count }

    /// Records the user's answer to the current question. May trigger early
    /// termination if the just-completed level produced 0 correct answers,
    /// or natural completion if no questions remain.
    func answer(_ choice: PlacementAnswer) {
        guard let q = currentQuestion else { return }
        answers[q.id] = choice

        let nextIdx = currentIndex + 1
        if nextIdx >= questions.count {
            isFinished = true
            return
        }

        // Crossing into a new level? If the level just completed had 0 correct, terminate.
        let nextLevel = questions[nextIdx].level
        if q.level != nextLevel {
            let levelQs = questions.filter { $0.level == q.level }
            let correct = levelQs.filter(wasCorrect).count
            if correct == 0 {
                earlyTerminated = true
                isFinished = true
                return
            }
        }

        currentIndex = nextIdx
    }

    private func wasCorrect(_ q: PlacementQuestion) -> Bool {
        if case .option(let idx) = answers[q.id], idx == q.correctIndex { return true }
        return false
    }

    /// Compute the placement result. Safe to call once `isFinished == true`.
    func computeResult() -> PlacementResult {
        let lowestLevel = levels.first ?? "A1"

        // Per-level competence
        var competence: [String: Double] = [:]
        for level in levels {
            let levelQs = questions.filter { $0.level == level }
            guard !levelQs.isEmpty else { competence[level] = 0; continue }
            let correctCount = levelQs.filter(wasCorrect).count
            competence[level] = Double(correctCount) / Double(levelQs.count)
        }

        // Walk up to find main level: stop at first level below 50%
        var mainIdx: Int? = nil
        for (i, level) in levels.enumerated() {
            if (competence[level] ?? 0) >= 0.5 {
                mainIdx = i
            } else {
                break
            }
        }

        // No level passed → total beginner: 100 of the lowest level
        guard let passedIdx = mainIdx else {
            return PlacementResult(
                competence: competence,
                mainLevel: lowestLevel,
                mainPassed: false,
                allocation: [lowestLevel: 100]
            )
        }

        let mainLevel = levels[passedIdx]

        // Decay weights by distance from main level (review-mass below, challenge above)
        let decayByDistance: [Int: Double] = [0: 1.0, 1: 0.7, 2: 0.4, 3: 0.2, 4: 0.1]
        let allowedUpper = min(passedIdx + 1, levels.count - 1)
        var weights: [String: Double] = [:]
        for i in 0...allowedUpper {
            let level = levels[i]
            let distance = passedIdx - i
            if distance >= 0 {
                let decay = decayByDistance[distance] ?? 0.1
                weights[level] = (competence[level] ?? 0) * decay
            } else {
                // Challenge level (main + 1) — 20% exposure floor regardless of competence
                weights[level] = 0.20
            }
        }
        // Lowest-level floor — always at least 20% weight so review baseline persists
        if (weights[lowestLevel] ?? 0) < 0.20 { weights[lowestLevel] = 0.20 }

        // Normalize → allocate 100 slots, give rounding remainder to mainLevel
        let total = weights.values.reduce(0, +)
        var alloc: [String: Int] = [:]
        if total > 0 {
            for (level, w) in weights {
                alloc[level] = Int(w / total * 100)
            }
            let assigned = alloc.values.reduce(0, +)
            if assigned < 100 {
                alloc[mainLevel, default: 0] += (100 - assigned)
            }
        } else {
            alloc[lowestLevel] = 100
        }

        return PlacementResult(
            competence: competence,
            mainLevel: mainLevel,
            mainPassed: true,
            allocation: alloc
        )
    }
}
