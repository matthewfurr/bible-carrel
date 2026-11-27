import Foundation
import Testing
@testable import ScriptureUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The two verse panels' names and symbols, and the request that asks for one.
@Suite struct VersePanelTests {
    @Test func theTwoPanelsAreNamedAndTheirSymbolsAreInTheSystemSet() {
        #expect(VersePanelKind.compare.title == "Compare Translations" && VersePanelKind.crossReferences.title == "Cross-References")
        #expect(VersePanelKind.compare.symbolName == "rectangle.split.2x1" && VersePanelKind.crossReferences.symbolName == "arrow.triangle.branch")
        for kind in [VersePanelKind.compare, .crossReferences] {
            #if os(macOS)
            #expect(NSImage(systemSymbolName: kind.symbolName, accessibilityDescription: nil) != nil, "\(kind.symbolName)")
            #else
            #expect(UIImage(systemName: kind.symbolName) != nil, "\(kind.symbolName)")
            #endif
        }
    }

    @Test func aRequestCarriesTheSelectionAndNamesItsFirstVerse() {
        let selection = TextSelection(book: "MAT", chapter: 5, verse: 3, endVerse: 4, startOffset: 0, endOffset: 5, quotedText: "Blessed")
        let report = SelectionReport(selection: selection, range: NSRange(location: 10, length: 20), highlightIDs: [])
        let request = VersePanelRequest(kind: .crossReferences, report: report)
        #expect(request.kind == .crossReferences && request.selection == selection && request.range == NSRange(location: 10, length: 20))
        #expect(request.verse.book == "MAT" && request.verse.chapter == 5 && request.verse.verse == 3)
        #expect(request != VersePanelRequest(kind: .crossReferences, report: report))     // each asking is its own
    }
}
