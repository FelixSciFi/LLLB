import Foundation
import SwiftUI

/// In-memory store of stroke geometry for the top-3000 most common simplified
/// Chinese characters. Source: Make Me a Hanzi (MIT-licensed AR PL UKai
/// derivative), filtered + slimmed to a flat dictionary.
///
/// JSON shape: `{ "字": { "s": [<svg-path>...], "m": [[[x,y],...], ...] } }`
/// where `s` is per-stroke filled outlines and `m` is per-stroke median
/// polylines (used as animation guide path).
///
/// Coordinate system: 0..1024 with origin at bottom-left, Y axis up — must be
/// flipped when rendered in SwiftUI's top-left coordinate space.
final class HanziStrokeData {

    static let shared = HanziStrokeData()

    struct Glyph {
        let strokes: [Path]   // filled outlines
        let medians: [Path]   // polyline through stroke center
        let strokeCount: Int
    }

    private var raw: [Character: RawGlyph]?
    private var cache: [Character: Glyph] = [:]
    private let queue = DispatchQueue(label: "hanzi.parse", qos: .userInitiated)

    private init() {}

    /// True if we have stroke data for this character (i.e. it is in the
    /// 3000-char pack). Triggers lazy load on first call.
    func contains(_ ch: Character) -> Bool {
        ensureLoaded()
        return raw?[ch] != nil
    }

    /// Parsed glyph (cached). Returns nil for chars outside the pack.
    func glyph(for ch: Character) -> Glyph? {
        ensureLoaded()
        if let g = cache[ch] { return g }
        guard let r = raw?[ch] else { return nil }
        let g = Glyph(
            strokes: r.s.map { Self.parseSVGPath($0) },
            medians: r.m.map { Self.medianPath(from: $0) },
            strokeCount: r.s.count
        )
        cache[ch] = g
        return g
    }

    // MARK: - Loading

    private struct RawGlyph: Decodable {
        let s: [String]
        let m: [[[CGFloat]]]
    }

    private func ensureLoaded() {
        guard raw == nil else { return }
        guard let url = Bundle.main.url(forResource: "hanzi-3000", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: RawGlyph].self, from: data) else {
            raw = [:]
            return
        }
        var byChar: [Character: RawGlyph] = [:]
        byChar.reserveCapacity(decoded.count)
        for (k, v) in decoded {
            if let c = k.first { byChar[c] = v }
        }
        raw = byChar
    }

    // MARK: - SVG path parser
    // Make Me a Hanzi uses only absolute M, L, Q, C, Z commands. This parser
    // assumes that contract; extending to relative or other commands isn't
    // needed for this dataset.

    private static func parseSVGPath(_ s: String) -> Path {
        var path = Path()
        let scanner = Scanner(string: s)
        scanner.charactersToBeSkipped = .whitespacesAndNewlines

        var current = CGPoint.zero

        while !scanner.isAtEnd {
            guard let cmd = scanner.scanCharacter() else { break }
            switch cmd {
            case "M":
                if let p = readPoint(scanner) {
                    path.move(to: p); current = p
                }
            case "L":
                if let p = readPoint(scanner) {
                    path.addLine(to: p); current = p
                }
            case "Q":
                if let c = readPoint(scanner), let p = readPoint(scanner) {
                    path.addQuadCurve(to: p, control: c); current = p
                }
            case "C":
                if let c1 = readPoint(scanner), let c2 = readPoint(scanner), let p = readPoint(scanner) {
                    path.addCurve(to: p, control1: c1, control2: c2); current = p
                }
            case "Z", "z":
                path.closeSubpath()
            default:
                continue
            }
            _ = current
        }
        return path
    }

    private static func readPoint(_ s: Scanner) -> CGPoint? {
        // Allow optional commas between numbers
        _ = s.scanCharacters(from: CharacterSet(charactersIn: ", "))
        guard let x = s.scanDouble() else { return nil }
        _ = s.scanCharacters(from: CharacterSet(charactersIn: ", "))
        guard let y = s.scanDouble() else { return nil }
        return CGPoint(x: x, y: y)
    }

    private static func medianPath(from pts: [[CGFloat]]) -> Path {
        var p = Path()
        guard let first = pts.first, first.count >= 2 else { return p }
        p.move(to: CGPoint(x: first[0], y: first[1]))
        for pt in pts.dropFirst() where pt.count >= 2 {
            p.addLine(to: CGPoint(x: pt[0], y: pt[1]))
        }
        return p
    }
}
