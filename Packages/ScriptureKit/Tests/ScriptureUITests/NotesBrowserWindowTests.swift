#if os(macOS)
import AppKit
import Foundation
import ScriptureData
import SwiftUI
import Testing
@testable import ScriptureUI

/// The Notes window hosted offscreen on `NotesBrowserFixture`, driven by key events as AppKit
/// delivers them: ↑ ↓ walk the rows in the order shown, Return shows the selected row in the
/// reader, Delete asks first. Its first four tests (the walk, Return, Delete and the kept versions)
/// were pinned on the window as it was before project 5 of milestone 11 redesigned it and never
/// edited since; the redesign added the two day-heading tests (`downCrossesFromOneDayToTheNext`,
/// `theKeysStillWalkAcrossHeadingsAndRules`).
///
/// A click and a double-click are not driven here: offscreen, the hosting view lists no row among
/// its accessibility elements (its scroll area has no children), and a left click sent through
/// `window.sendEvent` at a row selects nothing. They rest on `row(_:)`'s gestures being left as
/// they are and on `SecondaryClickHookTests`, with a pointer pass by hand.
@MainActor @Suite(.serialized) struct NotesBrowserWindowTests {
    private let fixture: NotesBrowserFixture
    private let model: NotesBrowserModel
    private let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1_100, height: 760), styleMask: [.titled], backing: .buffered, defer: false)

    init() throws {
        fixture = try NotesBrowserFixture()
        model = fixture.model()
        model.sort = .date
    }

    /// The window at its opening width, laid out and given 0.2 s to settle, the hosting view first responder.
    private func open(onShow: @escaping (MarkupTarget) -> Void) {
        let host = NSHostingView(rootView: NotesBrowserView(model: model, onShow: onShow).frame(width: 1_100, height: 760))
        host.frame = NSRect(x: 0, y: 0, width: 1_100, height: 760)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        window.makeFirstResponder(host)
    }

    private func turn() {
        RunLoop.current.run(until: Date())
        window.contentView?.layoutSubtreeIfNeeded()
        window.contentView?.displayIfNeeded()
    }

    private enum Key {
        static let down = (code: 125, character: String(UnicodeScalar(NSDownArrowFunctionKey)!))
        static let up = (code: 126, character: String(UnicodeScalar(NSUpArrowFunctionKey)!))
        static let returnKey = (code: 36, character: "\r")
        static let delete = (code: 51, character: String(UnicodeScalar(NSDeleteCharacter)!))
    }

    private func keyEvent(_ key: (code: Int, character: String), in target: NSWindow) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: target.windowNumber, context: nil,
                         characters: key.character, charactersIgnoringModifiers: key.character, isARepeat: false, keyCode: UInt16(key.code))!
    }

    /// One key down, sent as `PlanBenchmarkTests.choosingEachWeekInTurn` sends it, then the run loop turned.
    private func press(_ key: (code: Int, character: String)) {
        window.sendEvent(keyEvent(key, in: window))
        turn()
    }

    @Test func downAndUpWalkTheRowsInTheOrderShown() {
        open { _ in }
        let byDate = model.visibleIDs
        #expect(byDate == [fixture.abide, fixture.romans, fixture.stillWaters, fixture.vine, fixture.provide,
                           fixture.ezraChapter, fixture.johnThree, fixture.poorInSpirit, fixture.mark4])
        walk(byDate)

        model.sort = .reference
        turn()
        let byReference = model.visibleIDs
        #expect(byReference == [fixture.provide, fixture.ezraChapter, fixture.stillWaters, fixture.poorInSpirit, fixture.mark4,
                                fixture.johnThree, fixture.abide, fixture.vine, fixture.romans])
        walk(byReference)
    }

    /// From nothing selected ↓ ↓ ↑; then from nothing selected ↑, and ↓ at the last row stays there.
    private func walk(_ ids: [UUID]) {
        model.selectedID = nil
        turn()
        press(Key.down)
        #expect(model.selectedID == ids[0])
        press(Key.down)
        #expect(model.selectedID == ids[1])
        press(Key.up)
        #expect(model.selectedID == ids[0])
        model.selectedID = nil
        turn()
        press(Key.up)
        #expect(model.selectedID == ids.last)
        press(Key.down)
        #expect(model.selectedID == ids.last)
    }

    @Test func returnShowsTheSelectedRowInTheReader() {
        var shown: [MarkupTarget] = []
        open { shown.append($0) }
        press(Key.returnKey)
        #expect(model.selectedID == nil && shown.isEmpty)
        press(Key.down)
        press(Key.down)
        press(Key.returnKey)
        let second = model.visibleIDs[1]
        #expect(model.selectedID == second && second == fixture.romans)
        #expect(shown == [model.target(for: second)].compactMap { $0 })
        #expect(shown.count == 1)
    }

    /// Delete on the first row (John 15:4's note) opens the dialog and removes nothing. Return
    /// does not reach the dialog's Delete: that button has no key equivalent (only Cancel has one,
    /// Esc), so the dialog stays and nothing goes. The delete itself and its undo
    /// are the model's tests (`deletingTheSelectedRowSelectsItsSuccessor` and the rest).
    @Test func deleteAsksBeforeAnythingGoes() throws {
        open { _ in }
        let count = model.entries.count
        press(Key.down)
        #expect(model.selectedID == fixture.abide)
        press(Key.delete)
        // The dialog is attached a turn or two later.
        let deadline = Date().addingTimeInterval(1)
        while window.attachedSheet == nil, Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
        let sheet = try #require(window.attachedSheet)
        #expect(model.entries.count == count && model.entry(id: fixture.abide) != nil)

        sheet.sendEvent(keyEvent(Key.returnKey, in: sheet))
        turn()
        #expect(window.attachedSheet === sheet)
        #expect(model.entries.count == count && model.entry(id: fixture.abide) != nil)
        window.endSheet(sheet)
    }

    /// Sorted by date, ↓ from Today's last row selects Yesterday's first, and ↑ comes back: a day's heading is no stop.
    @Test func downCrossesFromOneDayToTheNext() {
        open { _ in }
        #expect(model.groups.prefix(3).map { $0.entries.map(\.id) } == [[fixture.abide, fixture.romans], [fixture.stillWaters], [fixture.vine]])
        model.selectedID = fixture.romans
        turn()
        press(Key.down)
        #expect(model.selectedID == fixture.stillWaters)
        press(Key.down)
        #expect(model.selectedID == fixture.vine)
        model.selectedID = fixture.stillWaters
        turn()
        press(Key.up)
        #expect(model.selectedID == fixture.romans)
    }

    /// By date and by passage, ↓ from nothing selected walks every row in order, one press each:
    /// a group's heading and the rules between notes and groups are never a stop.
    @Test func theKeysStillWalkAcrossHeadingsAndRules() {
        open { _ in }
        for sort in [NotesBrowserSort.date, .reference] {
            model.sort = sort
            model.selectedID = nil
            turn()
            let ids = model.visibleIDs
            #expect(model.groups.count > 1)
            var selected: [UUID?] = []
            for _ in ids {
                press(Key.down)
                selected.append(model.selectedID)
            }
            #expect(selected == ids.map(Optional.some))
            #expect(model.selectedID == ids.last)
        }
    }

    @Test func keptVersionsListUnderTheirOwnFilter() {
        var shown: [MarkupTarget] = []
        open { shown.append($0) }
        model.filter = .keptVersions
        turn()
        #expect(model.visibleIDs == [fixture.vine, fixture.orphan])
        press(Key.down)
        press(Key.down)
        press(Key.returnKey)
        #expect(model.selectedID == fixture.orphan)
        // Today's target for a kept version whose note is gone: its verse in its translation, no highlight.
        let target = MarkupTarget(location: ChapterLocation(book: "JHN", chapter: 15), verse: 9, translationID: "ESV", highlightID: nil)
        #expect(model.target(for: fixture.orphan) == target)
        #expect(shown == [target])
    }
}
#endif
