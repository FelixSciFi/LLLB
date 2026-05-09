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
        // Group items by row so we can compute each row's natural width
        // and pick a per-row x-offset (trailing or centering). Single rows
        // that already fill the bounds get offset 0 either way.
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
            let leadingOffset: CGFloat = trailingAligned
                ? bounds.width - rowWidth
                : max(0, (bounds.width - rowWidth) / 2)
            var xOffset = leadingOffset
            for i in group {
                let p = rows[i]
                subviews[i].place(
                    at: CGPoint(x: bounds.minX + xOffset, y: bounds.minY + p.y),
                    proposal: ProposedViewSize(p.size)
                )
                xOffset += p.size.width + spacing
            }
        }
    }

    private func arrange(_ maxWidth: CGFloat, subviews: Subviews) -> [RowItem] {
        let widthProposal: ProposedViewSize = maxWidth > 0
            ? ProposedViewSize(width: maxWidth, height: nil)
            : .unspecified
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var items: [RowItem] = []

        for sub in subviews {
            var size = sub.sizeThatFits(widthProposal)
            if maxWidth > 0, size.width > maxWidth {
                size.width = maxWidth
            }
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
