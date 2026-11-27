import Foundation
import ScriptureData
import ScriptureModel
import Testing
@testable import ScriptureUI

@Suite struct ColorReorderTests {
    private let a = UUID(), b = UUID(), c = UUID(), d = UUID()

    @Test func movesTheDraggedItemToTheTargetIndex() {
        let order = [a, b, c, d]
        #expect(ColorReorder.move(order, dragged: a, toIndex: 2) == [b, c, a, d])
        #expect(ColorReorder.move(order, dragged: d, toIndex: 0) == [d, a, b, c])
        #expect(ColorReorder.move(order, dragged: b, toIndex: 1) == order)
        #expect(ColorReorder.move(order, dragged: UUID(), toIndex: 1) == order)
        #expect(ColorReorder.move(order, dragged: c, toIndex: 99) == [a, b, d, c])
    }
}

@MainActor @Suite struct ColorOrderPersistenceTests {
    @Test func settingTheOrderRewritesSortOrderInTheStoreAndTheSettingsModel() throws {
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        let store = MarkupStore(container: container)
        var changes = 0
        let model = ColorSettingsModel(store: store) { changes += 1 }
        let ids = model.rows.map(\.id)
        model.reorder(to: [ids[4], ids[0], ids[1], ids[2], ids[3]])
        #expect(model.rows.map(\.name) == ["Orange", "Yellow", "Green", "Blue", "Rose"])
        #expect(try store.colors().map(\.sortOrder) == [0, 1, 2, 3, 4])
        #expect(changes == 1)
    }
}
