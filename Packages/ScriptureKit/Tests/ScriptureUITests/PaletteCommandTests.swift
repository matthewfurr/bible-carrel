import Foundation
import Testing
@testable import ScriptureUI

@Suite struct PaletteCommandTests {
    @Test func everyCommandWithAShortcutShowsTheCataloguesKeys() {
        let rows = Dictionary(uniqueKeysWithValues: ShortcutCatalog.groups.flatMap(\.shortcuts).map { ($0.id, $0) })
        for command in PaletteCommand.all {
            guard let shortcut = command.shortcut else { #expect(command.keycaps == nil, "\(command.id)"); continue }
            guard let row = rows[shortcut.row], row.chords.indices.contains(shortcut.chord) else { Issue.record("\(command.id) names no chord"); continue }
            #expect(command.keycaps == ShortcutCatalog.keycaps(forChord: row.chords[shortcut.chord]), "\(command.id)")
        }
        #expect(PaletteCommand.back.keycaps == ["⌘", "["] && PaletteCommand.nextChapter.keycaps == ["⌥", "⌘", "→"])
        #expect(PaletteCommand.smallerText.keycaps == ["⌘", "−"] && PaletteCommand.toggleAssistant.keycaps == ["⇧", "⌘", "A"])
        #expect(PaletteCommand.all.count == 35 && Set(PaletteCommand.all.map(\.id)).count == 35)
        // Export All Data and Import Data: no key, and Import waits with the sync.
        #expect(PaletteCommand.exportAllData.title == "Export All Data…" && PaletteCommand.exportAllData.symbolName == "square.and.arrow.up")
        #expect(PaletteCommand.importData.title == "Import Data…" && PaletteCommand.importData.symbolName == "square.and.arrow.down")
        #expect(PaletteCommand.exportAllData.keycaps == nil && PaletteCommand.importData.keycaps == nil)
        var waiting = PaletteState()
        #expect(PaletteState().canImportData && PaletteCommand.exportAllData.isAvailable(in: waiting) && PaletteCommand.importData.isAvailable(in: waiting))
        waiting.canImportData = false
        #expect(PaletteCommand.exportAllData.isAvailable(in: waiting) && !PaletteCommand.importData.isAvailable(in: waiting))
        #expect(PaletteCommand.readingPlan.title == "Reading Plan" && PaletteCommand.readingPlan.symbolName == "calendar" && PaletteCommand.readingPlan.keycaps == ["⌥", "⌘", "P"] && PaletteCommand.readingPlan.isAvailable(in: PaletteState()))
        // The catalogue's new row, and the size's step.
        let row = rows["textSize"]
        #expect(row?.label == "Larger, smaller text" && row?.keys == ["⌘", "+", "−"] && row?.chords == ["⌘+", "⌘-"])
        #expect(ReaderSettings.steppedFontSize(18, by: 1) == 19 && ReaderSettings.steppedFontSize(28, by: 1) == 28 && ReaderSettings.steppedFontSize(14, by: -1) == 14)
    }

    @Test func aCommandThatCannotRunIsAbsent() {
        var state = PaletteState()                      // the front page: nothing open, nowhere to go back to
        #expect(Set(PaletteCommand.all.filter { $0.isAvailable(in: state) }) == Set(
            [.notesBrowser, .readingPlan, .showShortcuts, .settings, .largerText, .smallerText, .exportNotes, .exportAllData, .importData]
            + PageStyle.allCases.map(PaletteCommand.pageStyle) + AppearanceChoice.allCases.map(PaletteCommand.appearance)))
        state.isReading = true
        let switches: [(PaletteCommand, WritableKeyPath<PaletteState, Bool>)] = [
            (.back, \.canGoBack), (.forward, \.canGoForward), (.previousChapter, \.hasPreviousChapter), (.nextChapter, \.hasNextChapter),
            (.readFromHere, \.isLookingUp), (.clearRecents, \.hasRecents), (.tryAgain, \.canRetry), (.copyLastReply, \.hasLastReply),
            (.addLastReplyAsNote, \.hasLastReply), (.stopAnswering, \.isResponding)]
        for (command, flag) in switches {
            var on = state
            on[keyPath: flag] = true
            #expect(!command.isAvailable(in: state) && command.isAvailable(in: on), "\(command.id)")
        }
        #expect(PaletteCommand.hideNotesColumn.isAvailable(in: state) && !PaletteCommand.showNotesColumn.isAvailable(in: state))
        state.hasLastReply = true
        state.lastReplyIsSaved = true
        state.fontSize = 28
        state.otherTranslations = 1
        #expect(!PaletteCommand.addLastReplyAsNote.isAvailable(in: state) && !PaletteCommand.largerText.isAvailable(in: state))
        #expect(PaletteCommand.smallerText.isAvailable(in: state) && PaletteCommand.switchTranslation.isAvailable(in: state))
        state.pageStyle = .lectern
        #expect(PaletteCommand.pageStyle(.lectern).isCurrent(in: state) && !PaletteCommand.pageStyle(.study).isCurrent(in: state))
    }
}
