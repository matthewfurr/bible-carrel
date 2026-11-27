import SwiftUI

/// Rows of fixed-size children that wrap at the proposed width, each row centred (or, with
/// `isCentered` false, at the leading edge: a place's chips at the same spot).
struct FlowLayout: Layout {
    var spacing: CGFloat
    var isCentered = true

    /// The children's sizes, read once, and the rows for the width last asked.
    struct Cache {
        var sizes: [CGSize]
        var width: CGFloat?
        var rows: [[Int]] = []
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(sizes: subviews.map { $0.sizeThatFits(.unspecified) })
    }

    /// The rows at `width`, worked out once however many times the layout asks.
    private func rows(_ cache: inout Cache, width: CGFloat) -> [[Int]] {
        if cache.width == width { return cache.rows }
        var rows: [[Int]] = [[]]
        var used: CGFloat = 0
        for index in cache.sizes.indices {
            let size = cache.sizes[index]
            let needed = used == 0 ? size.width : used + spacing + size.width
            if needed > width, !rows[rows.count - 1].isEmpty {
                rows.append([index])
                used = size.width
            } else {
                rows[rows.count - 1].append(index)
                used = needed
            }
        }
        cache.width = width
        cache.rows = rows
        return rows
    }

    private func rowSize(_ row: [Int], _ cache: Cache) -> CGSize {
        let sizes = row.map { cache.sizes[$0] }
        return CGSize(width: sizes.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(row.count - 1, 0)),
                      height: sizes.map(\.height).max() ?? 0)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews _: Subviews, cache: inout Cache) -> CGSize {
        let rows = rows(&cache, width: proposal.width ?? .infinity)
        let sizes = rows.map { rowSize($0, cache) }
        return CGSize(width: proposal.width ?? (sizes.map(\.width).max() ?? 0),
                      height: sizes.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0)))
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        var y = bounds.minY
        for row in rows(&cache, width: bounds.width) {
            let size = rowSize(row, cache)
            var x = bounds.minX + (isCentered ? (bounds.width - size.width) / 2 : 0)
            for index in row {
                let item = cache.sizes[index]
                subviews[index].place(at: CGPoint(x: x, y: y + (size.height - item.height) / 2), proposal: ProposedViewSize(item))
                x += item.width + spacing
            }
            y += size.height + spacing
        }
    }
}
