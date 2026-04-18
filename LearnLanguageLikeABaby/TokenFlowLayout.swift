import SwiftUI

// MARK: - Flow layout (iOS 16+)

struct TokenFlowLayout: Layout {
    var spacing: CGFloat
    var runSpacing: CGFloat
    var trailingAligned: Bool = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let dims = proposal.replacingUnspecifiedDimensions()
        let w = max(0, dims.width)
        let rows = arrange(w, subviews: subviews)
        let h = rows.map { $0.y + $0.height }.max() ?? 0
        return CGSize(width: w, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(bounds.width, subviews: subviews)
        if trailingAligned {
            var rowGroups: [[Int]] = []
            var currentY: CGFloat = -1
            for (i, p) in rows.enumerated() {
                guard i < subviews.count else { continue }
                if p.y != currentY {
                    rowGroups.append([i])
                    currentY = p.y
                } else {
                    rowGroups[rowGroups.count - 1].append(i)
                }
            }
            for group in rowGroups {
                let rowWidth = group.reduce(CGFloat(0)) { acc, i in
                    acc + rows[i].size.width + (acc > 0 ? spacing : 0)
                }
                var xOffset = bounds.width - rowWidth
                for i in group {
                    let p = rows[i]
                    subviews[i].place(
                        at: CGPoint(x: bounds.minX + xOffset, y: bounds.minY + p.y),
                        proposal: ProposedViewSize(p.size)
                    )
                    xOffset += p.size.width + spacing
                }
            }
        } else {
            for (i, sub) in subviews.enumerated() {
                guard i < rows.count else { continue }
                let p = rows[i]
                sub.place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: ProposedViewSize(p.size))
            }
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
