#if os(macOS)
import AppKit
import ScriptureData
import SwiftUI
import Testing
@testable import ScriptureUI

/// The ⌘K list is as tall as its rows up to 420 pt, the moment results change: laid out as the
/// window lays it out (the panel at the top of a taller container), on the real Bible.
@MainActor @Suite(.serialized) struct PaletteListHeightTests {
    private func host(_ model: NavigationModel) -> (NSWindow, NSHostingView<some View>) {
        let view = ZStack(alignment: .top) {
            Color.paperPage
            CommandPaletteView(model: model).padding(.top, AppSpacing.xxxl + AppSpacing.md)
        }
        .frame(width: 700, height: 900)
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 900), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.frame = NSRect(x: 0, y: 0, width: 700, height: 900)
        return (window, host)
    }

    private func settle() {
        RunLoop.main.run(until: .now + 0.5)
    }

    /// The list's scroll view: its visible height and its content's height.
    private func list(in view: NSView) -> (shown: CGFloat, content: CGFloat)? {
        if let scroll = view as? NSScrollView, let document = scroll.documentView {
            return (scroll.contentView.bounds.height, document.frame.height)
        }
        for sub in view.subviews { if let found = list(in: sub) { return found } }
        return nil
    }

    @Test(.needsRealBible) func theListIsAsTallAsItsRowsTheMomentAQueryChanges() throws {
        let defaults = UserDefaults(suiteName: "PaletteListHeight-\(UUID().uuidString)")!
        let model = try NavigationModel(
            store: try BenchmarkChapter.realStore(), positionStore: ReadingPositionStore(defaults: defaults), defaultTranslationID: "ESV")
        model.open(ChapterLocation(book: "JHN", chapter: 15))
        model.isPaletteShown = true
        model.updatePalette()
        let (window, view) = host(model)
        defer { window.contentView = nil }
        settle()
        let opened = try #require(list(in: view), "no scroll view on open")
        #expect(abs(opened.shown - min(opened.content, 420)) <= 1, "on open: the list shows \(opened.shown) pt of \(opened.content) pt")
        for query in ["remain fruit", "lord", "abide in me"] {
            model.paletteQuery = query
            model.updatePalette()
            settle()
            let measured = try #require(list(in: view), "no scroll view for \(query)")
            #expect(abs(measured.shown - min(measured.content, 420)) <= 1,
                    "\(query): the list shows \(measured.shown) pt of \(measured.content) pt")
        }
    }
}
#endif
