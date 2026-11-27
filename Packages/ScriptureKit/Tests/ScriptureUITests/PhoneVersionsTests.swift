import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

/// The Notes tab's kinds and the mark on its rows (keeping data safe 4.1, 4.2).
@Suite struct PhoneVersionsTests {
    private func entry(_ kind: NotesBrowserEntry.Kind, versions: Int = 1) -> NotesBrowserEntry {
        NotesBrowserEntry(
            id: UUID(), kind: kind, book: "JHN", bookOrder: 42, chapter: 15, verse: 5, endVerse: 5,
            referenceString: "John 15:5", translationID: "WEB", color: nil, quotedText: "", body: "N",
            modifiedAt: Date(timeIntervalSince1970: 0), versionCount: versions)
    }

    @Test func keptVersionsIsOfferedOnlyWhileThereIsOne() {
        let five: [NotesBrowserFilter] = [.all, .notes, .highlights, .bookmarks, .threads]
        #expect(PhoneNotesKinds.offered(hasKeptVersions: false, current: .all) == five)
        #expect(PhoneNotesKinds.offered(hasKeptVersions: true, current: .all) == five + [.keptVersions])
        #expect(PhoneNotesKinds.offered(hasKeptVersions: false, current: .keptVersions) == five + [.keptVersions])
        #expect(PhoneNotesKinds.title(for: .keptVersions) == "Kept versions")
        #expect(PhoneNotesKinds.title(for: .threads) == "Conversations")
        #expect(PhoneNotesKinds.title(for: .all) == "Everything")
    }

    @Test func aRowsMarkIsItsCountOrKeptVersion() {
        let note = NotesBrowserEntry.Kind.note(noteID: UUID(), highlightID: UUID())
        #expect(PhoneNotesKinds.mark(for: entry(note)) == nil)
        #expect(PhoneNotesKinds.mark(for: entry(note, versions: 2)) == "2 versions")
        #expect(PhoneNotesKinds.mark(for: entry(.keptVersion(id: UUID()))) == "Kept version")
        #expect(PhoneNotesKinds.mark(for: entry(.bookmark(id: UUID()))) == nil)
        #expect(PhoneNotesKinds.mark(for: entry(.highlight(id: UUID()))) == nil)
    }
}

#if os(iOS)
import ScriptureModel
import SwiftData
import SwiftUI
import UIKit

/// A made-up store for the phone's versions screens: a note on John 15:5 with a kept version from a
/// Mac (and, optionally, a second kept one), a plain note on 15:2, and a kept version whose note is
/// gone, with a `MarkupModel`, a `NotesBrowserModel` and the versions model wired as the app wires them.
@MainActor final class PhoneVersionsFixture {
    let container: ModelContainer
    let store: MarkupStore
    let markup: MarkupModel
    let notesBrowser: NotesBrowserModel
    let versions: NoteVersionsModel
    let noteID: UUID
    let keptID: UUID
    let plainID: UUID
    let orphanID: UUID
    private let defaultsName = "PhoneVersionsFixture-\(UUID().uuidString)"

    init(thirdText: String? = nil, current: String = "Abide in me, and I in you. Apart from me you can do nothing.",
         kept: String = "Remain in me, as I also remain in you.", quote: String = "I am the vine. You are the branches.") throws {
        container = try MarkupContainer.make(inMemory: true)
        try MarkupContainer.seedDefaultColorsIfNeeded(in: container.mainContext)
        store = MarkupStore(container: container, deviceKind: "iPhone")
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        let colors = try store.colors()
        let store = store
        func highlight(verse: Int, quote: String) throws -> Highlight {
            try store.addHighlight(book: "JHN", chapter: 15, verse: verse, endVerse: verse, startOffset: 0, endOffset: quote.count,
                                   translationID: "WEB", colorID: colors.first?.uuid, quotedText: quote)
        }
        let note = try store.addNote(to: highlight(verse: 5, quote: quote), body: current)
        noteID = note.uuid
        keptID = Self.keep(kept, of: noteID, at: 1_000, in: store)
        if let thirdText { Self.keep(thirdText, of: noteID, at: 2_000, in: store) }
        plainID = try store.addNote(to: highlight(verse: 2, quote: "Every branch in me that doesn't bear fruit"),
                                    body: "A plain note, with one version.").uuid
        orphanID = Self.keep("The words of a note that was deleted on another device.", of: UUID(), at: 3_000, in: store)
        try store.context.save()
        let markupModel = MarkupModel(store: store, defaults: defaults)
        markup = markupModel
        markupModel.load(book: "JHN", chapters: 15...15, chapterInView: ChapterLocation(book: "JHN", chapter: 15), translationID: "WEB")
        let browser = NotesBrowserModel(store: store, defaults: defaults)
        notesBrowser = browser
        versions = NoteVersionsModel(store: store) {
            markupModel.reload()
            browser.reload()
        } onNoteChange: { markupModel.reloadEditor(noteID: $0) }
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: defaultsName)
    }

    @discardableResult
    static func keep(_ body: String, of noteID: UUID, at seconds: TimeInterval, in store: MarkupStore) -> UUID {
        let version = KeptVersion()
        version.noteID = noteID
        version.body = body
        version.writtenAt = Date(timeIntervalSinceNow: -seconds * 100)
        version.deviceKind = "Mac"
        version.book = "JHN"
        version.chapter = 15
        version.verse = 5
        version.endVerse = 5
        version.translationID = "WEB"
        version.quotedText = "I am the vine. You are the branches."
        store.context.insert(version)
        return version.uuid
    }
}

/// Every phone hit area is at least 44 pt at every text size: scaling only ever makes it taller.
@MainActor @Suite(.serialized) struct PhoneHitAreaTests {
    private func height<V: View>(of view: V, size: DynamicTypeSize) -> CGFloat {
        let host = UIHostingController(rootView: view.environment(\.dynamicTypeSize, size).frame(width: 370))
        return host.sizeThatFits(in: CGSize(width: 370, height: 2000)).height
    }

    private func block(_ choices: [VersionChoice]) -> VersionBlock {
        VersionBlock(
            block: NoteVersionsView.Block(id: UUID(), keptID: UUID(), name: "Kept version · Mac", time: "Today", spoken: "",
                                          body: "Words.", choices: choices, prominent: nil),
            book: nil, onChoose: { _ in })
    }

    private static let sizes: [DynamicTypeSize] = [.xSmall, .small, .medium, .large, .xxxLarge]

    @Test func aChoiceIsAtLeast44ptAtEveryTextSize() {
        for size in Self.sizes {
            // The block with a choice, less the same block without, less the gap before it.
            let button = height(of: block([.discard]), size: size) - height(of: block([]), size: size) - AppSpacing.xs
            #expect(button >= 44, "a choice is \(button) pt at \(size)")
        }
    }

    @Test func theMarkButtonIsAtLeast44ptAtEveryTextSize() {
        for size in Self.sizes {
            let mark = height(of: PhoneVersionsMarkButton(text: "2 versions") {}, size: size)
            #expect(mark >= 44, "the mark is \(mark) pt at \(size)")
        }
    }
}

/// The phone's note sheet and its mark: a choice on the pushed page leaves the sheet showing the
/// chosen text. The sheet reads its note from `PhoneNoteSheet.card`, so that is what is asserted; a
/// window cannot be asked what a SwiftUI `Text` says without VoiceOver running.
@MainActor @Suite(.serialized) struct PhoneNoteSheetVersionsTests {
    static func pump(_ window: UIWindow, turns: Int = 8) {
        for _ in 0..<turns {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
            window.layoutIfNeeded()
        }
    }

    private func host(_ fixture: PhoneVersionsFixture, startsEditing: Bool) -> UIWindow {
        let sheet = PhoneNoteSheet(noteID: fixture.noteID, markup: fixture.markup, startsEditing: startsEditing)
            .environment(\.noteVersions, fixture.versions)
        let window = TestWindow.make(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = UIHostingController(rootView: sheet)
        window.isHidden = false
        Self.pump(window)
        return window
    }

    @Test func theSheetsCardCountsTheNotesVersions() throws {
        let fixture = try PhoneVersionsFixture()
        #expect(PhoneNoteSheet.card(fixture.noteID, in: fixture.markup)?.versionCount == 2)
        #expect(PhoneNoteSheet.card(fixture.plainID, in: fixture.markup)?.versionCount == 1)
    }

    @Test func aChoiceMadeOnThePushedPageLeavesTheSheetOnTheChosenText() throws {
        for choice in [VersionChoice.use, .keepBoth] {
            let fixture = try PhoneVersionsFixture()
            let window = host(fixture, startsEditing: false)
            #expect(PhoneNoteSheet.card(fixture.noteID, in: fixture.markup)?.body.hasPrefix("Abide in me") == true)

            fixture.versions.perform(choice, on: fixture.keptID, undoManager: nil)
            Self.pump(window)

            let chosen = choice == .use ? "Remain in me, as I also remain in you."
                : "Abide in me, and I in you. Apart from me you can do nothing.\n\nRemain in me, as I also remain in you."
            #expect(PhoneNoteSheet.card(fixture.noteID, in: fixture.markup)?.body == chosen)
            // Not editing, so no editor reload was needed: the sheet reads the note's card as it is.
            #expect(fixture.markup.editingNoteID == nil)
            // Use This One keeps the other text as the kept version, so the mark stays; Keep Both leaves none.
            #expect(PhoneNoteSheet.card(fixture.noteID, in: fixture.markup)?.versionCount == (choice == .use ? 2 : 1))
            #expect(try fixture.store.note(id: fixture.noteID)?.body == chosen)
            window.isHidden = true
            window.rootViewController = nil
        }
    }
}
#endif
