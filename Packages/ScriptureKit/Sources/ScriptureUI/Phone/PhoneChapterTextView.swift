#if os(iOS)
import ScriptureData
import SwiftUI
import UIKit

/// SwiftUI wrapper around `PhoneChapterTextController`'s text view, as `ChapterTextView` is on the
/// Mac: one chapter as one scroll. The footer (the chapter's links) is a SwiftUI view hosted
/// inside the text view, below the chapter's text, so it scrolls with it.
struct PhoneChapterTextView: UIViewRepresentable {
    let layout: BookLayout?
    let typography: ReaderTypography
    let scrollTarget: ScrollTarget?
    let decorations: BookDecorations
    let marginMarks: [MarginMark]
    /// The reading position, as the controller measures it.
    let onReadingPositionChange: (VerseLocation) -> Void
    /// The navigation bar's bottom below the text view's top; nil takes the text view's top inset.
    var headLineY: CGFloat?
    /// The controller's running head (the open chapter, its progress, the head's opacity).
    var onRunningHeadChange: (RunningHeadState) -> Void = { _ in }
    /// The controller's scroll since the last jump, in lines, for `NavigationModel`.
    var onScrollSinceJump: (Double, ScrollTarget) -> Void = { _, _ in }
    var onSelectionChange: (SelectionReport?) -> Void = { _ in }
    /// The selection went away with its text (`PhoneChapterTextController.onSelectionDropped`).
    var onSelectionDropped: () -> Void = {}
    var onMarginMarkTap: (MarginMark) -> Void = { _ in }
    /// A tap on a highlight that has a note: the note, to read.
    var onOpenNote: (UUID) -> Void = { _ in }
    /// The chapter's number of chapter notes, by chapter, for the mark on the opening line.
    var chapterNoteCounts: [Int: Int] = [:]
    /// A tap on a chapter's note mark, with its chapter.
    var onShowChapterNotes: (Int) -> Void = { _ in }
    /// The markup the selection menu acts on; without it a selection offers only the system's actions.
    var markup: MarkupModel?
    /// The pen; with it on, one finger paints (Ruling 2) and a mark carries handles and its menu.
    var pen: PenModel?
    var footer: AnyView?
    /// The book thumb's press at the page's right edge, its height in the page's coordinates.
    var onThumb: (ThumbGesture) -> Void = { _ in }
    /// The chapter switcher: its cards are hosted inside the text view, past the chapter's ends,
    /// and the controller writes its state as the page is pulled. Nil for none.
    var switcher: ChapterSwitcherModel?
    /// Where the thumb's loupe asks for the page behind it; the controller draws it.
    var backdrop: PageBackdrop?

    @MainActor final class Coordinator {
        let controller: PhoneChapterTextController
        var footer: UIHostingController<AnyView>?
        var switcherCards: UIHostingController<ChapterSwitcherDeckView>?

        init(controller: PhoneChapterTextController) {
            self.controller = controller
        }

        /// The hosted footer for `content`, made once and given the new content on every update.
        func hostFooter(_ content: AnyView?) -> UIView? {
            guard let content else {
                footer = nil
                return nil
            }
            if let hosting = footer {
                hosting.rootView = content
                hosting.view.invalidateIntrinsicContentSize()
                return hosting.view
            }
            let hosting = UIHostingController(rootView: content)
            // Inside the scroll view: no safe-area padding of its own, and no fill over the page.
            hosting.safeAreaRegions = []
            hosting.view.backgroundColor = .clear
            footer = hosting
            return hosting.view
        }
    }

    /// The hosted cards of `model`'s switcher, made once and given the typography on every update.
    static func hostSwitcher(_ model: ChapterSwitcherModel?, typography: ReaderTypography, in coordinator: Coordinator) -> UIView? {
        guard let model else {
            coordinator.switcherCards = nil
            return nil
        }
        let cards = ChapterSwitcherDeckView(model: model, typography: typography)
        if let hosting = coordinator.switcherCards, hosting.rootView.model === model {
            hosting.rootView = cards
            return hosting.view
        }
        let hosting = UIHostingController(rootView: cards)
        // Inside the scroll view: no safe-area padding of its own, and no fill over the page.
        hosting.safeAreaRegions = []
        hosting.view.backgroundColor = .clear
        coordinator.switcherCards = hosting
        return hosting.view
    }

    /// A head report queued for `reportedFor` still names the page when it arrives: the same book
    /// is showing.
    static func isCurrent(reportedFor book: String?, showing current: String?) -> Bool {
        book != nil && book == current
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: PhoneChapterTextController(onReadingPositionChange: onReadingPositionChange))
    }

    func makeUIView(context: Context) -> ReaderPageView {
        context.coordinator.controller.pageView
    }

    func updateUIView(_ pageView: ReaderPageView, context: Context) {
        let coordinator = context.coordinator
        let controller = coordinator.controller
        controller.onReadingPositionChange = onReadingPositionChange
        // These are also reported from inside this update (a new layout or size), where SwiftUI
        // state must not change, so they land on the next turn of the main queue; the queue is
        // serial, so the values arrive in order.
        let onRunningHeadChange = onRunningHeadChange
        controller.onRunningHeadChange = { [weak controller] state in
            let book = controller?.layout?.id.book
            DispatchQueue.main.async { [weak controller] in
                // A report from a book replaced since it was queued names that book's chapter.
                guard Self.isCurrent(reportedFor: book, showing: controller?.layout?.id.book) else { return }
                onRunningHeadChange(state)
            }
        }
        // The same: it can end a lookup, which changes observed state.
        let onScrollSinceJump = onScrollSinceJump
        controller.onScrollSinceJump = { lines, target in DispatchQueue.main.async { onScrollSinceJump(lines, target) } }
        controller.onSelectionChange = onSelectionChange
        controller.onSelectionDropped = onSelectionDropped
        controller.onMarginMarkTap = onMarginMarkTap
        controller.onShowChapterNotes = onShowChapterNotes
        controller.noteForHighlight = { [weak markup] in markup?.noteID(forHighlight: $0) }
        controller.onOpenNote = onOpenNote
        controller.onThumb = onThumb
        backdrop?.capture = { [weak controller] frame, scale in controller?.pagePicture(under: frame, scale: scale) }
        controller.switcher = switcher
        controller.setSwitcherView(Self.hostSwitcher(switcher, typography: typography, in: coordinator))
        controller.headLineY = headLineY
        let markup = markup
        let pen = pen
        controller.menuProvider = { [weak controller] report in
            guard let controller, let markup else { return nil }
            return PhoneMarkupMenu.make(for: report, model: markup, penColorID: pen?.colorID,
                                        share: { [weak controller] in controller?.presentShareSheet($0, for: report.range) },
                                        lookUp: { [weak controller] in controller?.presentLookUp($0, for: report.range) },
                                        translate: { [weak controller] in controller?.presentTranslation($0) },
                                        collapse: { [weak controller] in controller?.collapseSelection() },
                                        traits: controller.textView.traitCollection)
        }
        controller.onHighlightTap = { markup?.outlinedHighlightID = $0 }
        controller.sceneUndoManager = context.environment.undoManager
        if let pen, let markup {
            let chip = pen.colorID.flatMap { id in markup.colorChips.first { $0.id == id } }
            controller.setPen(isOn: pen.isOn, color: chip?.color.platformColor ?? Palette.accentWash.platformColor,
                              selectedID: pen.selectedHighlightID)
            controller.onPaint = { _ = pen.paint($0) }
            controller.onPenSelect = { pen.select(highlightID: $0) }
            controller.onResize = { pen.resizeSelected(to: $0) }
            controller.penMenuProvider = { [weak controller] id, report in
                PhoneMarkupMenu.makeUnderMark(highlightID: id, report: report, model: markup,
                                              traits: controller?.textView.traitCollection ?? UITraitCollection.current,
                                              chooseColor: { pen.chooseColor($0) },
                                              deleted: { pen.select(highlightID: nil) })
            }
            // The markup's items for the chapter, wherever the model files them.
            controller.canResize = { id in
                markup.itemsByChapter.values.lazy.flatMap { $0 }.first { $0.id == id }?.translationID == markup.translationID
            }
        }
        controller.update(layout: layout, typography: typography, scrollTarget: scrollTarget, decorations: decorations,
                          marginMarks: marginMarks, footer: coordinator.hostFooter(footer))
        // After the text: the marks are placed on the layout just applied.
        controller.chapterNoteCounts = chapterNoteCounts
    }
}
#endif
