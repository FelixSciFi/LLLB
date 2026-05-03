import SwiftUI

/// Animated stroke-by-stroke renderer for 1-4 simplified Chinese characters.
///
/// Pure UI: given a string and a mode, draws each character with its strokes
/// revealed progressively along their median curves. Knows nothing about
/// audio, narration, or session state — the caller decides when to mount
/// this view and what timing to feed it.
///
/// Two timing modes:
/// - `.paced(seconds)`: writes the whole word in `seconds × 0.85`, then holds
///   the completed glyph until the view is removed/rebuilt.
/// - `.natural(strokeSeconds)`: writes each stroke in `strokeSeconds`, pauses
///   1.5s on the completed glyph, then loops from blank.
struct HanziStrokeView: View {

    enum Mode: Hashable {
        case paced(seconds: Double)
        case natural(strokeSeconds: Double)
    }

    let text: String
    let mode: Mode

    var body: some View {
        let chars = Array(text)
        HStack(spacing: 4) {
            ForEach(Array(chars.enumerated()), id: \.offset) { _, ch in
                SingleHanziView(char: ch, mode: mode)
            }
        }
    }
}

private struct SingleHanziView: View {

    let char: Character
    let mode: HanziStrokeView.Mode

    @State private var strokesDrawn: Int = 0
    @State private var currentProgress: Double = 0
    @State private var animationID = UUID()

    var body: some View {
        Group {
            if let g = HanziStrokeData.shared.glyph(for: char) {
                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    HanziCanvas(
                        glyph: g,
                        strokesDrawn: strokesDrawn,
                        currentProgress: currentProgress,
                        side: side
                    )
                    .frame(width: side, height: side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .aspectRatio(1, contentMode: .fit)
                .task(id: AnimKey(char: char, mode: mode, anim: animationID)) {
                    await runAnimation(glyph: g)
                }
            } else {
                Color.clear
            }
        }
    }

    private struct AnimKey: Hashable {
        let char: Character
        let mode: HanziStrokeView.Mode
        let anim: UUID
    }

    @MainActor
    private func runAnimation(glyph g: HanziStrokeData.Glyph) async {
        let totalStrokes = g.strokeCount
        guard totalStrokes > 0 else { return }

        switch mode {
        case .paced(let seconds):
            let writeTime = max(0.4, seconds * 0.85)
            let perStroke = writeTime / Double(totalStrokes)
            await drawAll(strokes: totalStrokes, perStrokeSeconds: perStroke)
            // Hold completed; do nothing more — view sits on the final frame.

        case .natural(let strokeSeconds):
            while !Task.isCancelled {
                strokesDrawn = 0
                currentProgress = 0
                await drawAll(strokes: totalStrokes, perStrokeSeconds: strokeSeconds)
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    @MainActor
    private func drawAll(strokes totalStrokes: Int, perStrokeSeconds: Double) async {
        strokesDrawn = 0
        currentProgress = 0
        let frameSeconds = 1.0 / 60.0
        for i in 0..<totalStrokes {
            if Task.isCancelled { return }
            let steps = max(1, Int(perStrokeSeconds / frameSeconds))
            for step in 1...steps {
                if Task.isCancelled { return }
                currentProgress = Double(step) / Double(steps)
                try? await Task.sleep(nanoseconds: UInt64(frameSeconds * 1_000_000_000))
            }
            strokesDrawn = i + 1
            currentProgress = 0
        }
    }
}

private struct HanziCanvas: View {

    let glyph: HanziStrokeData.Glyph
    let strokesDrawn: Int
    let currentProgress: Double
    let side: CGFloat

    private var transform: CGAffineTransform {
        let s = side / 1024.0
        return CGAffineTransform(translationX: 0, y: side).scaledBy(x: s, y: -s)
    }

    private var maskWidth: CGFloat { 180 * side / 1024.0 }

    var body: some View {
        ZStack {
            // Light gray guides — show all strokes so user previews shape.
            ForEach(0..<glyph.strokes.count, id: \.self) { i in
                glyph.strokes[i].applying(transform)
                    .fill(Color.lllbSecondaryText.opacity(0.15))
            }
            // Already-completed strokes.
            ForEach(0..<min(strokesDrawn, glyph.strokes.count), id: \.self) { i in
                glyph.strokes[i].applying(transform)
                    .fill(Color.primary)
            }
            // Currently animating stroke: full outline filled, masked by the
            // median path stroked thick enough to cover the outline and
            // trimmed to the live progress.
            if strokesDrawn < glyph.strokes.count {
                glyph.strokes[strokesDrawn].applying(transform)
                    .fill(Color.primary)
                    .mask(
                        glyph.medians[strokesDrawn].applying(transform)
                            .trimmedPath(from: 0, to: currentProgress)
                            .stroke(style: StrokeStyle(lineWidth: maskWidth, lineCap: .round, lineJoin: .round))
                    )
            }
        }
    }
}
