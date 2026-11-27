import Foundation

/// Live reordering for the color list: the dragged row moves to the index of the row under
/// the pointer while the drag is in flight; the drop persists the order.
public enum ColorReorder {
    public static func move(_ order: [UUID], dragged: UUID, toIndex: Int) -> [UUID] {
        guard let from = order.firstIndex(of: dragged) else { return order }
        var result = order
        result.remove(at: from)
        result.insert(dragged, at: min(max(toIndex, 0), result.count))
        return result
    }
}
