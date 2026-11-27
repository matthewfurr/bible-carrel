import Foundation
import Testing
@testable import ScriptureUI

@Suite struct MarkdownFormattingTests {
    @Test func boldWrapsTheSelectionAndUnwrapsItAgain() {
        let once = MarkdownFormatting.apply(.bold, to: "make this strong", selection: NSRange(location: 5, length: 4))
        #expect(once.text == "make **this** strong")
        #expect(once.selection == NSRange(location: 7, length: 4))
        let twice = MarkdownFormatting.apply(.bold, to: once.text, selection: once.selection)
        #expect(twice.text == "make this strong" && twice.selection == NSRange(location: 5, length: 4))
    }

    @Test func italicUnwrapsWhenTheSelectionIncludesTheMarkers() {
        let once = MarkdownFormatting.apply(.italic, to: "a *word* b", selection: NSRange(location: 2, length: 6))
        #expect(once.text == "a word b" && once.selection == NSRange(location: 2, length: 4))
    }

    @Test func italicWithACaretAtTheEndOfTheOnlyWordFormatsIt() {
        let result = MarkdownFormatting.apply(.italic, to: "ab", selection: NSRange(location: 2, length: 0))
        #expect(result.text == "*ab*")
        #expect(result.selection == NSRange(location: 3, length: 0))
    }

    @Test func headingTogglesOnTheCurrentLine() {
        let on = MarkdownFormatting.apply(.heading, to: "first\nsecond", selection: NSRange(location: 8, length: 0))
        #expect(on.text == "first\n# second" && on.selection == NSRange(location: 10, length: 0))
        let off = MarkdownFormatting.apply(.heading, to: on.text, selection: on.selection)
        #expect(off.text == "first\nsecond" && off.selection == NSRange(location: 8, length: 0))
    }

    @Test func bulletsToggleOnEverySelectedLine() {
        let on = MarkdownFormatting.apply(.bulletedList, to: "one\ntwo\nthree", selection: NSRange(location: 1, length: 5))   // "ne\ntw"
        #expect(on.text == "- one\n- two\nthree" && on.selection == NSRange(location: 3, length: 7))
        let off = MarkdownFormatting.apply(.bulletedList, to: on.text, selection: on.selection)
        #expect(off.text == "one\ntwo\nthree" && off.selection == NSRange(location: 1, length: 5))
    }

    @Test func linkSelectsTheURLPlaceholder() {
        let result = MarkdownFormatting.apply(.link, to: "read ESV", selection: NSRange(location: 5, length: 3))
        #expect(result.text == "read [ESV](url)")
        #expect(result.selection == NSRange(location: 11, length: 3))
    }

    @Test func returnInsertsANewlineAndCommandReturnCommitsByDefault() {
        #expect(NoteEditingKeys.action(command: false, shift: false, finishWithReturn: false) == .newline)
        #expect(NoteEditingKeys.action(command: true, shift: false, finishWithReturn: false) == .finish)
        #expect(NoteEditingKeys.action(command: false, shift: true, finishWithReturn: false) == .newline)
        // The setting makes Return commit and Shift-Return insert a newline; ⌘Return still commits.
        #expect(NoteEditingKeys.action(command: false, shift: false, finishWithReturn: true) == .finish)
        #expect(NoteEditingKeys.action(command: false, shift: true, finishWithReturn: true) == .newline)
        #expect(NoteEditingKeys.action(command: true, shift: false, finishWithReturn: true) == .finish)
    }

    @Test func boldWithACaretInsideAWordFormatsTheWordAndKeepsTheCaret() {
        let on = MarkdownFormatting.apply(.bold, to: "make this strong", selection: NSRange(location: 7, length: 0))
        #expect(on.text == "make **this** strong" && on.selection == NSRange(location: 9, length: 0))
        let off = MarkdownFormatting.apply(.bold, to: on.text, selection: on.selection)
        #expect(off.text == "make this strong" && off.selection == NSRange(location: 7, length: 0))
    }

    @Test func italicWithACaretInsideAnItalicWordUnwrapsIt() {
        let off = MarkdownFormatting.apply(.italic, to: "a *word* b", selection: NSRange(location: 5, length: 0))
        #expect(off.text == "a word b" && off.selection == NSRange(location: 4, length: 0))
    }

    @Test func aCaretTouchingOneWordFormatsThatWord() {
        #expect(MarkdownFormatting.wordRange(in: "make this strong", around: 5) == NSRange(location: 5, length: 4))   // start of "this"
        #expect(MarkdownFormatting.wordRange(in: "make this strong", around: 9) == NSRange(location: 5, length: 4))   // end of "this"
        #expect(MarkdownFormatting.wordRange(in: "make this strong", around: 7) == NSRange(location: 5, length: 4))
        #expect(MarkdownFormatting.wordRange(in: "make  strong", around: 5) == nil)        // between two spaces
        #expect(MarkdownFormatting.wordRange(in: "", around: 0) == nil)
        let atStart = MarkdownFormatting.apply(.bold, to: "make this strong", selection: NSRange(location: 5, length: 0))
        #expect(atStart.text == "make **this** strong" && atStart.selection == NSRange(location: 7, length: 0))
        let atEnd = MarkdownFormatting.apply(.bold, to: "make this strong", selection: NSRange(location: 9, length: 0))
        #expect(atEnd.text == "make **this** strong" && atEnd.selection == NSRange(location: 11, length: 0))
    }

    @Test func aCaretTouchingNoWordInsertsAnEmptyMarkerPair() {
        let between = MarkdownFormatting.apply(.bold, to: "make  strong", selection: NSRange(location: 5, length: 0))
        #expect(between.text == "make **** strong" && between.selection == NSRange(location: 7, length: 0))
        let empty = MarkdownFormatting.apply(.italic, to: "", selection: NSRange(location: 0, length: 0))
        #expect(empty.text == "**" && empty.selection == NSRange(location: 1, length: 0))
    }

    @Test func returnKeyCodesAreRecognised() {
        #expect(NoteEditingKeys.isReturn(keyCode: 36))    // Return
        #expect(NoteEditingKeys.isReturn(keyCode: 76))    // keypad Enter
        #expect(!NoteEditingKeys.isReturn(keyCode: 49))   // space
    }
}
