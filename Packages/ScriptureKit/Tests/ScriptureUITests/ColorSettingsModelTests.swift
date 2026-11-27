import Foundation
import ScriptureData
import ScriptureModel
import Testing
@testable import ScriptureUI

@MainActor @Suite struct ColorSettingsModelTests {
    private final class Counter { var changes = 0 }

    private func makeModel() throws -> (ColorSettingsModel, MarkupStore, Counter) {
        let container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        let store = MarkupStore(container: container)
        let counter = Counter()
        let model = ColorSettingsModel(store: store) { counter.changes += 1 }
        return (model, store, counter)
    }

    @Test func rowsListDefaultsInOrderWithUsageCounts() throws {
        let (model, store, _) = try makeModel()
        let yellow = model.rows[0].id
        try store.addHighlight(book: "MAT", chapter: 5, verse: 1, endVerse: 1, startOffset: 0, endOffset: 3, translationID: "ESV", colorID: yellow, quotedText: "Ble")
        model.reload()
        #expect(model.rows.map(\.name) == ["Yellow", "Green", "Blue", "Rose", "Orange"])
        #expect(model.rows[0].highlightCount == 1 && model.rows[1].highlightCount == 0)
    }

    @Test func addRenameMoveDeleteNotifyTheReader() throws {
        let (model, _, counter) = try makeModel()
        model.add()
        #expect(model.rows.last?.name == "New Color" && model.rows.count == 6)
        #expect(model.rows.last?.lightHex == ColorSettingsModel.newColorLightHex)
        #expect(MarkLightness.isInBand(hex: ColorSettingsModel.newColorLightHex, dark: false))
        #expect(MarkLightness.isInBand(hex: ColorSettingsModel.newColorDarkHex, dark: true))
        let id = model.rows.last!.id
        model.rename(id: id, to: "Teal")
        // #A0E0E0 sits just under the light band, so the row shows the conformed value.
        model.setHex(id: id, lightHex: "#A0E0E0", darkHex: "#104040")
        model.move(fromOffsets: IndexSet(integer: 5), toOffset: 0)
        #expect(model.rows.first?.name == "Teal" && model.rows.first?.lightHex == MarkLightness.conformed(hex: "#A0E0E0", dark: false))
        #expect(model.rows.first?.darkHex == MarkLightness.conformed(hex: "#104040", dark: true))
        model.delete(id: id)
        #expect(model.rows.count == 5)
        #expect(counter.changes == 5)
    }
}
