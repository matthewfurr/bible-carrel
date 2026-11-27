import Foundation
import Testing
@testable import ScriptureUI

/// The one list of the app's keyboard shortcuts: its groups, the reader's single keys it resolves,
/// and (on the Mac) that every menu shortcut in the source is in it.
@Suite struct ShortcutCatalogTests {
    @Test func theGroupsAreTheFiveInOrder() {
        #expect(ShortcutCatalog.groups.map(\.title) == ["Go", "View", "Verses", "Notes Column", "Assistant"])
    }

    @Test func everyReaderKeyActionIsListedAndNoKeyTwice() {
        let pairs = ShortcutCatalog.groups.flatMap(\.shortcuts).flatMap { Array($0.readerKeys) }
        #expect(Set(pairs.map(\.value)) == Set(ReaderKeyAction.allCases))
        #expect(Set(pairs.map(\.key)).count == pairs.count)
        #expect(ReaderKeyAction.allCases.count == 22)
        let chords = ShortcutCatalog.groups.flatMap(\.shortcuts).flatMap(\.chords)
        #expect(Set(chords).count == chords.count)
    }

    @Test func aRowSpeaksItsLabelThenItsKeysByName() {
        let rows = ShortcutCatalog.groups.flatMap(\.shortcuts)
        #expect(rows.first { $0.id == "nextPreviousVerse" }?.accessibilityLabel == "Next, previous verse: J, K")
        #expect(rows.first { $0.id == "goToAnything" }?.accessibilityLabel == "Go to anything: Command K")
    }

    @Test func theFilterNarrowsRowsByTheirLabel() {
        let verse = ShortcutCatalog.filtered("  VERSE ")
        #expect(verse.map(\.title) == ["Verses"])
        #expect(verse[0].shortcuts.map(\.label) == ["Next, previous verse", "Extend by a verse"])
        #expect(ShortcutCatalog.filtered("") == ShortcutCatalog.groups)
        #expect(ShortcutCatalog.filtered("zebra").isEmpty)
        let chapter = ShortcutCatalog.filtered("chapter")
        #expect(chapter.map(\.title) == ["Go"])
        #expect(chapter.first?.shortcuts.map(\.id) == ["chapters", "chaptersAnywhere"])
        #expect(chapter.first?.shortcuts.map(\.label) == ["Previous, next chapter", "Chapters, from anywhere"])
    }

    @Test func theGroupsFallIntoThreeColumns() {
        #expect(ShortcutCatalog.columns(ShortcutCatalog.groups).map { $0.map(\.id) }
                == [["go", "view"], ["verses"], ["notesColumn", "assistant"]])
        #expect(ShortcutCatalog.columns(ShortcutCatalog.filtered("verse")).map { $0.map(\.id) } == [["verses"]])
    }

    @Test func theReadersKeysResolveThroughTheCatalogue() {
        func action(_ key: ReaderKeyStroke.Key, shift: Bool = false) -> ReaderKeyAction? {
            ShortcutCatalog.readerAction(for: ReaderKeyStroke(key, shift: shift))
        }
        #expect(action(.character("j")) == .nextVerse && action(.character("k"), shift: true) == .extendUp)
        #expect(action(.character("7")) == .color(7) && action(.character("0")) == .noColor)
        #expect(action(.leftArrow) == .previousChapter && action(.escape) == .clearSelection)
        #expect(action(.character("?")) == .showShortcuts)
        #expect(action(.character("c")) == .compareTranslations && action(.character("r")) == .crossReferences)
        #expect(action(.character("c"), shift: true) == nil && action(.character("r"), shift: true) == nil)
        let verses = ShortcutCatalog.groups.first { $0.id == "verses" }?.shortcuts ?? []
        #expect(verses.map(\.id).contains(["bookmark", "compareTranslations", "crossReferences", "copy"]))
        #expect(verses.first { $0.id == "crossReferences" }?.accessibilityLabel == "Cross-references: R")
        // Left to AppKit as today: a shifted arrow, and Space (as ↑, ↓ and the Page keys, which make no stroke).
        #expect(action(.leftArrow, shift: true) == nil && action(.character(" ")) == nil)
    }

    #if os(macOS)
    /// Section 6: every shortcut in the app is in a group, the menus' existing ones included.
    @Test func everyMenuShortcutInTheMacAppIsListed() throws {
        let listed = Set(ShortcutCatalog.groups.flatMap(\.shortcuts).flatMap(\.chords))
        let (found, unread) = try Self.menuChordsInSource()
        #expect(found.count >= 15)
        for chord in found { #expect(listed.contains(chord), "\(chord) is in a menu but not in the catalogue") }
        // A shortcut written another way (`.keyboardShortcut("x")`, a `KeyboardShortcut` value)
        // would slip past the pattern: there must be none.
        #expect(unread.isEmpty, "shortcuts this test cannot read: \(unread)")
    }

    /// Every `.keyboardShortcut("x", modifiers: …)` and `.keyboardShortcut(.leftArrow, modifiers: …)`
    /// in the Mac app and the shared UI (not the phone's folder), as chords: modifiers in the order
    /// ⌃⌥⇧⌘, the key upper-cased, the arrows as ← and →. `.defaultAction` and `.cancelAction` are
    /// not chords. `unread` names each file with a `.keyboardShortcut(` or `KeyboardShortcut(`
    /// that is neither.
    private static func menuChordsInSource() throws -> (chords: Set<String>, unread: [String]) {
        let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let roots = [package.appending(path: "Sources/ScriptureUI"), package.appending(path: "../../Apps/Mac").standardized]
        let pattern = #/\.keyboardShortcut\((?:"(?<character>[^"]+)"|\.(?<named>leftArrow|rightArrow|upArrow|downArrow))\s*,\s*modifiers:\s*(?<modifiers>\[[^\]]*\]|\.\w+)\s*\)/#
        let named = ["leftArrow": "←", "rightArrow": "→", "upArrow": "↑", "downArrow": "↓"]
        let order: [(name: String, symbol: String)] = [("control", "⌃"), ("option", "⌥"), ("shift", "⇧"), ("command", "⌘")]
        var chords: Set<String> = []
        var unread: [String] = []
        for root in roots {
            let files = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
            for case let file as URL in files where file.pathExtension == "swift" && !file.pathComponents.contains("Phone") {
                let source = try String(contentsOf: file, encoding: .utf8)
                let matches = source.matches(of: pattern)
                for match in matches {
                    let modifiers = String(match.output.modifiers)
                    let prefix = order.filter { modifiers.contains(".\($0.name)") }.map(\.symbol).joined()
                    let key = match.output.character.map { $0.uppercased() } ?? match.output.named.flatMap { named[String($0)] } ?? ""
                    chords.insert(prefix + key)
                }
                let every = source.matches(of: /\.keyboardShortcut\(|\bKeyboardShortcut\(/).count
                let actions = source.matches(of: /\.keyboardShortcut\(\s*\.(?:defaultAction|cancelAction)\s*\)/).count
                if every != matches.count + actions { unread.append(file.lastPathComponent) }
            }
        }
        return (chords, unread)
    }
    #endif
}
