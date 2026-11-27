import Testing
@testable import ScriptureUI

/// When the reader's text takes keyboard focus back (spec 5.2).
@Suite struct ReaderFocusRuleTests {
    @Test func theReaderTakesFocusOnlyWhereTheSpecSays() {
        typealias R = ReaderFocusRule
        for reason in R.Reason.allCases {
            #expect(R.takes(for: reason, from: .reader) == false)      // it has it already
            #expect(R.takes(for: reason, from: .other) == true)
            #expect(R.takes(for: reason, from: .typing) == false)      // never from a field being typed in
        }
        #expect(R.takes(for: .noteEditFinished, from: .fieldBeingLeft))
        #expect(R.takes(for: .paletteClosed, from: .fieldBeingLeft))
        #expect(!R.takes(for: .chapterOpened, from: .fieldBeingLeft))
        #expect(!R.takes(for: .shortcutsClosed, from: .fieldBeingLeft))
        #expect(!R.takes(for: .versePanelClosed, from: .fieldBeingLeft))   // the composer Ask focused, a note's editor
    }
}
