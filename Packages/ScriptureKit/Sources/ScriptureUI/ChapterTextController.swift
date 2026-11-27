#if os(macOS)
import AppKit
import os
import ScriptureData

/// Owns the TextKit 2 text view that shows one chapter (a one-chapter `BookLayout`) as a page:
/// replaces the text when the layout changes, scrolls to a requested verse once it is laid out,
/// reports the reading position (the first visible verse, as a `VerseLocation`), the running
/// head's state and how much of the space kept for the footer links is in view as the reader
/// scrolls, draws markup (highlight backgrounds painted behind the text, underlines as storage
/// attributes, bookmark glyphs in a gutter overlay, an outline overlay for the focused
/// highlight) and Lectern's drop numeral, reports selections resolved to verses of the chapter,
/// and supplies the context menu. Testable without a window.
///
/// Loading is deterministic: the attributed text is built with its underlines already in it, the
/// whole chapter is laid out, the controller sets the text view's frame to the exact content
/// height itself (the view never sizes itself), and only then does it scroll. While a scroll
/// target is pending (its chapter's layout not yet shown, or the clip without a size), no reading
/// position is reported, so nothing transient is ever saved.
///
/// Never touch `textView.layoutManager`: doing so silently switches the view to TextKit 1.
@MainActor
public final class ChapterTextController {
    /// The column's starting width, until a typography's measure arrives.
    static let maximumColumnWidth: CGFloat = ReaderTypography.default.measure
    static let horizontalInset: CGFloat = AppSpacing.xxl
    static let verticalInset: CGFloat = AppSpacing.xl
    /// Space kept above the target verse's line when scrolling to it.
    static let scrollLeadIn: CGFloat = 8
    /// Distance from the text column's left edge to the bookmark glyph's left edge.
    static let gutterGlyphOffset: CGFloat = 26
    /// The outline is the background's own rects outset by this much on every side.
    static let outlineMargin: CGFloat = 2

    /// One painted background rect: a highlight's rect on one line, or the blended overlap of two.
    public struct HighlightFill: Equatable {
        public let id: UUID?
        public let rect: NSRect
        public let color: NSColor
    }

    let scrollView: NSScrollView
    /// The scroll view's document: the fills view behind, the (transparent) text view on top.
    let documentView = FlippedView()
    public let fillsView = HighlightFillView()
    public let textView: NSTextView
    public let gutterView = MarkupGutterView()
    public let outlineView = OutlineOverlayView()
    /// The view drawing Lectern's numeral: one small view over the text, in its notch (never an
    /// overlay the height of the page, whose stale backing once showed on screen); nil in the
    /// other styles.
    private(set) var numeralView: DropNumeralView?
    /// Hands TextKit the fragments that cut Lectern's notches (set while a Lectern layout shows).
    private let dropZoneDelegate = DropZoneLayoutDelegate()
    /// The rects the highlight backgrounds are filled with, in text-view coordinates, for the
    /// chapter's highlights. The outline strokes these same rects (outset), so background and
    /// outline cannot disagree.
    public private(set) var backgroundFills: [HighlightFill] = []
    /// The selection's fill, in text-view coordinates, for the lines in or near view
    /// (`refreshSelectionFill`): on each line from the first selected glyph to the last, the
    /// line's full height, joined to the next line's. The system's own fill, which runs on to the
    /// column's edges, never shows.
    public private(set) var selectionFills: [NSRect] = []
    /// The reading position: the first visible verse, reported when it changes.
    var onReadingPositionChange: (VerseLocation) -> Void
    /// The running head's state, reported when its chapter changes or its progress or opacity
    /// has moved at least `ReadingProgress.step` (or reached an end).
    var onRunningHeadChange: (RunningHeadState) -> Void = { _ in }
    /// How far the page has scrolled since the last jump landed, in lines of body text (signed),
    /// for `NavigationModel.reportLinesScrolledSinceJump`. Reported on every scroll the reader makes.
    var onScrollSinceJump: (Double, ScrollTarget) -> Void = { _, _ in }
    /// When the book thumb shows: the pointer near the reader's right edge, or a landing.
    let thumbReveal = ThumbRevealTracker()
    var onSelectionChange: (SelectionReport?) -> Void = { _ in }
    var menuProvider: (SelectionReport) -> NSMenu? = { _ in nil }
    /// Shows the markup menu with its top-left at `origin` (text-view coordinates) for a click at
    /// `click`, and says how it closed. `NSMenu.popUp` by default (`popUpMenu`); tests stand in.
    var presentMenu: (_ menu: NSMenu, _ origin: NSPoint, _ click: NSPoint) -> MarkupMenuEnding = { _, _, _ in .closedWithoutAClick }
    /// The selection's fill each time a refresh changes it, mid-drag too.
    var onSelectionFillChange: ([NSRect]) -> Void = { _ in }
    /// A reader key that acts on the selection or beyond the text (a color, a note, a chapter, the
    /// shortcuts), with the selection it acts on; false leaves the key to `NSTextView`.
    var onReaderKey: (ReaderKeyAction, SelectionReport?) -> Bool = { _, _ in false }
    /// Whether the reader's keys act at all; false (⌘K showing, a note being edited) swallows
    /// every one of them (`ReaderKeyCommands.keysAreLive`).
    var keysAreLive: () -> Bool = { true }
    /// The focus request waiting to settle (`requestFocus`), and the field being typed in when it
    /// was made, if one was, with the text field it was editing when it is the field editor.
    var waitingFocus: ReaderFocusRule.Reason?
    weak var focusFieldBeingLeft: NSResponder?
    weak var focusFieldBeingLeftOwner: AnyObject?
    /// The last request `apply` took, so a view update repeating it asks nothing.
    var appliedFocusRequest: ReaderFocusRequest?
    /// The verse panel's popover over the selection (`apply(_: VersePanelPresentation?)`), while one is up.
    var versePanel: VersePanelPopover?
    /// How a verse panel's popover is put up, and whether it is up (`showVersePanel`); a test puts
    /// one "up" without the screen, which the suite's windows are never on.
    var presentVersePanel: (NSPopover, NSRect, NSView) -> Bool = { ChapterTextController.showVersePanel($0, anchor: $1, of: $2) }
    /// How the reader's window is made key again once a verse panel is down, with the closed
    /// popover's own window (`makeKeyAfterVersePanel`); a test counts the calls without the screen.
    var makeReaderWindowKey: (NSWindow, NSWindow?) -> Void = { ChapterTextController.makeKeyAfterVersePanel($0, closingPopover: $1) }
    /// The range J, K, ⇧J or ⇧K last selected, while no scroll but the keys' own has happened
    /// since: the keys step on from it even while their reveal is still scrolling to it.
    var keyRange: NSRange?
    /// The keys' reveal in flight, from the clip's top where it started to where it ends.
    var keyScroll: (from: CGFloat, to: CGFloat)?
    /// When `keyScroll` stops counting, its animation ended or cut short.
    var keyScrollDeadline: Date?
    /// The character index in the verse that ⇧J and ⇧K keep selected; nil once the selection
    /// changes by other means.
    private(set) var verseAnchor: Int?
    /// The range `selectVerses` last set, while it is still the selection.
    private var verseSelection: NSRange?
    /// The running head strip's height over the clip's top (0: no strip). The reading position is
    /// the first fully visible line below it; a jump lands its line `scrollLeadIn` below it, and
    /// that line (`headLine`, "the line just under the head") is the one the head names the
    /// chapter at.
    public var headLineY: CGFloat = 0 {
        didSet {
            guard headLineY != oldValue else { return }
            refreshTopInset()
            updateRunningHead()
        }
    }
    /// Reduce Motion: the title block's hand-over to the running head is a cut (`RunningHead.cut`).
    var reducesMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    /// The chapter's number of chapter notes (notes on the chapter, not a verse), by chapter; with
    /// any, it carries a `ChapterNoteMark` at the trailing end of its opening line.
    var chapterNoteCounts: [Int: Int] = [:] {
        didSet { if chapterNoteCounts != oldValue { refreshChapterNoteMarks() } }
    }
    /// A click on a chapter-note mark, with its chapter.
    var onShowChapterNotes: (Int) -> Void = { _ in }
    /// How far down the vertical scroller's track starts: the whole running head over the clip's
    /// top (strip, progress line and fade), so the head never covers the knob or takes its clicks.
    var scrollerTopInset: CGFloat = 0 {
        didSet {
            guard scrollerTopInset != oldValue else { return }
            var insets = scrollView.scrollerInsets
            insets.top = scrollerTopInset
            scrollView.scrollerInsets = insets
        }
    }
    /// How much of `bottomInset` is in view, 0 to 1, reported when it changes by
    /// `ReadingProgress.step` or reaches an end: the chapter's footer links show by it, so they
    /// never lie over the text above the reserved space.
    var onFootReveal: (Double) -> Void = { _ in }
    private(set) var footReveal: Double = 0
    /// New text: the next reveal is reported even if it equals the last, since the reader view
    /// forgets the reveal whenever the text changes (two short chapters both fit the window, at
    /// reveal 1 each).
    private var needsFootReport = false
    /// Extra space below the text, for the footer links laid over the scroll's foot. Kept for the
    /// whole chapter (not only while the links show), so their appearing never moves the end.
    var bottomInset: CGFloat = 0 {
        didSet {
            guard bottomInset != oldValue, layout != nil else { return }
            sizeToLayout()
            updateRunningHead()
            reportReadingPosition()
        }
    }
    /// The marks on the opening lines, by chapter (`refreshChapterNoteMarks` keeps them).
    var chapterNoteMarkViews: [Int: NoteMarkView] = [:]
    /// The headings rotor's stops for the current text.
    private(set) var headingItems: [HeadingItem] = []
    /// VoiceOver's Headings rotor (and its next-heading command) over `headingItems`.
    private(set) lazy var headingsRotor = NSAccessibilityCustomRotor(rotorType: .heading, itemSearchDelegate: headingsSearch)
    private let headingsSearch = HeadingsRotorSearch()
    /// The running head's state at the current scroll, or nil before the first layout lands.
    public private(set) var runningHead: RunningHeadState?
    /// The chapter's place in the text view, for the head; rebuilt whenever the text reflows.
    private(set) var chapterBand: ChapterBand?
    private(set) var layout: BookLayout?
    private(set) var appliedDecorations: BookDecorations = .none
    /// The alpha the page opening's chapter label is drawn with (`1 − headOpacity`).
    private(set) var openingLabelAlpha: CGFloat = 1
    /// How many times the column has reflowed (a width change that laid the text out again).
    private(set) var reflowCount = 0

    /// A place the controller still has to scroll to: a jump's target, or the verse being read
    /// when the text reflowed or was replaced without a new target.
    private enum Pending {
        case target(ScrollTarget)
        case position(VerseLocation)
    }

    /// An underline in the text storage.
    private struct Underline: Hashable {
        let range: NSRange
        let style: Int
    }

    private var appliedTypography: ReaderTypography?
    private var appliedScrollTarget: ScrollTarget?
    private var pending: Pending?
    /// Storage ranges currently carrying an underline attribute.
    private var underlines: [Underline] = []
    private(set) var lastReportedPosition: VerseLocation?
    /// The verse the last jump or restore landed on, while it is still the first visible: a
    /// combined verse ("14-15") then reports the verse asked for, not its first number.
    private var landedVerse: VerseLocation?
    private var lastReportedHead: RunningHeadState?
    /// Verse-number ranges currently carrying the on-mark color as a rendering attribute.
    private var numberColorRanges: [NSRange] = []
    /// The page opening's chapter label runs, with their own color, for the fade into the head.
    private var openingLabelRuns: [(range: NSRange, color: NSColor)] = []
    /// The clip's top where the last jump landed; nil while one is pending or being made.
    private var jumpLandedY: CGFloat?
    /// The content height the controller last gave the text view's frame.
    private(set) var contentHeight: CGFloat = 0
    /// The clip view's origin while the frame held the content: restored after anything else
    /// resizes the text view.
    private var settledOrigin: NSPoint?
    private var isReplacingText = false
    private var isSizing = false
    private var observers: [any NSObjectProtocol] = []

    init(onReadingPositionChange: @escaping (VerseLocation) -> Void) {
        self.onReadingPositionChange = onReadingPositionChange

        let contentStorage = NSTextContentStorage()
        let layoutManager = NSTextLayoutManager()
        contentStorage.addTextLayoutManager(layoutManager)
        let container = DropZoneContainer(size: NSSize(width: Self.maximumColumnWidth, height: .greatestFiniteMagnitude))
        container.widthTracksTextView = false
        container.lineFragmentPadding = 0
        layoutManager.textContainer = container

        let textView = ColumnTextView(frame: .zero, textContainer: container)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        // The controller sets the height; the view must not size itself.
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: Self.horizontalInset, height: Self.verticalInset)
        textView.postsFrameChangedNotifications = true
        // The selection stays a real selection (Copy, the menu, the keys, VoiceOver), but its fill
        // is the controller's, behind the words only (`refreshSelectionFill`). The text keeps its
        // own colours when selected.
        textView.selectedTextAttributes = [.backgroundColor: NSColor.clear]
        textView.hideSystemSelectionFill()
        self.textView = textView

        for overlay in [gutterView, outlineView] as [NSView] {
            overlay.frame = textView.bounds
            overlay.autoresizingMask = [.width, .height]
            textView.addSubview(overlay)
        }

        // Highlight backgrounds are painted by a view behind the text view (a subview would draw
        // over the text, and the text view's own drawing is not reliably reachable).
        documentView.autoresizingMask = [.width]
        for layer in [fillsView, textView] as [NSView] {
            layer.frame = documentView.bounds
            layer.autoresizingMask = [.width, .height]
            documentView.addSubview(layer)
        }

        let scrollView = NSScrollView()
        scrollView.documentView = documentView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        // The page tone: the book sits on paper, not on the window's gray.
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Palette.paperPage.platformColor
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollView.postsFrameChangedNotifications = true
        self.scrollView = scrollView

        textView.columnDelegate = self
        headingsSearch.controller = self
        presentMenu = { [weak self] menu, origin, click in
            self?.popUpMenu(menu, at: origin, click: click) ?? .closedWithoutAClick
        }

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView.contentView, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.clipBoundsDidChange() }
        })
        observers.append(center.addObserver(forName: NSView.frameDidChangeNotification, object: textView, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.textFrameDidChange() }
        })
        // A pending scroll waits for the clip view to have a size.
        observers.append(center.addObserver(forName: NSView.frameDidChangeNotification, object: scrollView, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.performPendingScroll()
                // A taller or shorter window changes the head's place and the foot's without a scroll.
                self?.updateRunningHead()
            }
        })
        thumbReveal.attach(to: scrollView)
        observers.append(center.addObserver(forName: NSTextView.didChangeSelectionNotification, object: textView, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.selectionDidChange() }
        })
        // The selection's colour is the system's quieter one while the window is not key.
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let window = (note.object as AnyObject?).map(ObjectIdentifier.init)
                MainActor.assumeIsolated {
                    guard let self, let shown = self.textView.window, window == ObjectIdentifier(shown) else { return }
                    self.updateSelectionEmphasis()
                }
            })
        }
    }

    isolated deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    /// The single entry point: a layout, the typography it was built with (whose measure sets the
    /// column), its decorations and a scroll request are applied together, so the first position
    /// reported after a change is the requested one, never a transient one.
    ///
    /// The text is replaced only when `layout.id` changes. A replacement without a new target
    /// returns to the verse being read; a new target is scrolled to once its chapter is shown
    /// (showing it is the document's job). Decoration-only changes (user actions) keep the scroll
    /// position.
    func update(layout newLayout: BookLayout?, typography: ReaderTypography, scrollTarget: ScrollTarget?, decorations newDecorations: BookDecorations) {
        let textChanged = newLayout?.id != layout?.id
        // Another book or other chapters (the first layout too), not a translation or typography
        // alone: a chapter opened, and the reader takes the keyboard (`ReaderFocusRule`).
        let chapterOpened = newLayout.map { new in layout.map { $0.id.book != new.id.book || $0.chapters != new.chapters } ?? true } ?? false
        // A typography whose layout has not arrived yet (a size change: the new typography comes
        // a pass before the document's new layout) waits for it, so the chapter is laid out once.
        let typographyMatches = newLayout.map { $0.id.typography == typography.layoutHash } ?? true
        let measureChanged = typographyMatches && (appliedTypography.map { $0.measure != typography.measure } ?? true)
        if textChanged || typographyMatches { appliedTypography = typography }
        // Decorations mapped onto another layout (the markup model is given the new layout a pass
        // after the document builds it) would put marks at the old offsets: a new layout starts
        // without them, an unchanged one keeps what it has until its own arrive.
        var decorations = newDecorations
        if let id = newDecorations.layoutID, id != newLayout?.id {
            decorations = textChanged ? .none : appliedDecorations
        }
        if let scrollTarget, scrollTarget != appliedScrollTarget {
            appliedScrollTarget = scrollTarget
            pending = .target(scrollTarget)
            landedVerse = nil
            jumpLandedY = nil
        }

        var outlineChanged = false
        if textChanged {
            if pending == nil, let newLayout {
                // A new translation or typography without a new target: the verse being read, or
                // (a target taken on the previous book's layout) the target again.
                if let position = lastReportedPosition, position.book == newLayout.id.book {
                    pending = .position(position)
                } else if let appliedScrollTarget {
                    pending = .target(appliedScrollTarget)
                    landedVerse = nil
                    jumpLandedY = nil
                }
            }
            appliedDecorations = decorations
            replaceText(newLayout, typography: typography, decorations: decorations)
            // The selection changed with the text, unreported (`selectionDidChange`): report what
            // it is now, so the model never holds a verse of the text just replaced. Next turn,
            // as this runs inside a view update, where SwiftUI state must not change.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onSelectionChange(self.selectionReport())
            }
        } else {
            if measureChanged, newLayout != nil {
                (textView as? ColumnTextView)?.setMeasure(typography.measure)
                columnWidthDidChange()
            }
            if decorations != appliedDecorations {
                outlineChanged = decorations.outlinedID != appliedDecorations.outlinedID
                appliedDecorations = decorations
                applyDecorationChange()
            }
        }
        performPendingScroll()
        if textChanged {
            refreshOverlays()
            reportReadingPosition()
            updateRunningHead()
        }
        if outlineChanged, let id = decorations.outlinedID, let decoration = decorations.decoration(id: id) {
            scrollToHighlight(decoration.range)
        }
        if chapterOpened { requestFocus(.chapterOpened) }
    }

    /// A newly outlined highlight with no part on screen (a card click) is scrolled to, its first
    /// line just below the head's line. One already showing (a click inside it) keeps the scroll,
    /// and a pending scroll (a load or translation switch) wins. `scrollRangeToVisible` does
    /// nothing here: the controller, not the text view, owns the frame and the scroll.
    private func scrollToHighlight(_ range: NSRange) {
        guard pending == nil, !isTransientFrame else { return }
        let segments = segmentFrames(of: range)
        let visible = scrollView.documentVisibleRect
        guard let first = segments.first, !segments.contains(where: { $0.intersects(visible) }) else { return }
        // The page lands here: this scroll (after a jump's, or a row's click) is not reading on.
        jumpLandedY = nil
        // The highlight's verse is where the page now rests, not an earlier jump's.
        landedVerse = layout?.span(containing: range.location)?.location
        scroll(toY: first.minY - Self.outlineMargin - Self.scrollLeadIn - headLineY)
        jumpLandedY = scrollView.contentView.bounds.minY
    }

    // MARK: - Text and sizing

    /// Sets the chapter's text with its underlines already in it, lays it all out and sizes the
    /// text view to it. Backgrounds are painted by `update` once the page has landed.
    private func replaceText(_ layout: BookLayout?, typography: ReaderTypography, decorations: BookDecorations) {
        let signpost = ReaderSignposts.signposter.beginInterval(ReaderSignposts.replaceText)
        defer { ReaderSignposts.signposter.endInterval(ReaderSignposts.replaceText, signpost) }
        needsFootReport = true
        self.layout = layout
        lastReportedPosition = nil
        lastReportedHead = nil
        runningHead = nil
        keyRange = nil
        keyScroll = nil
        settledOrigin = nil
        numberColorRanges = []
        openingLabelAlpha = 1
        isReplacingText = true
        defer { isReplacingText = false }
        versePanelPageLaidOut()

        let text = (layout?.attributedString.mutableCopy() as? NSMutableAttributedString) ?? NSMutableAttributedString()
        let underlines = Self.underlines(in: decorations).filter { NSMaxRange($0.range) <= text.length }
        for underline in underlines {
            text.addAttributes([.underlineStyle: underline.style, .underlineColor: Palette.inkSecondary.platformColor], range: underline.range)
        }
        self.underlines = underlines
        openingLabelRuns = Self.openingLabelRuns(in: layout)
        headingItems = Self.headingItems(in: layout)
        // The measure follows the body size; set it before the text so the layout below is final.
        (textView as? ColumnTextView)?.setMeasure(typography.measure)
        (textView as? ColumnTextView)?.setTopInset(topInset(for: layout))
        // Lectern's notches need fragments of their own; every other style keeps TextKit's.
        textView.textLayoutManager?.delegate = typography.style == .lectern ? dropZoneDelegate : nil
        textView.textContentStorage?.performEditingTransaction {
            textView.textContentStorage?.textStorage?.setAttributedString(text)
        }
        // Rendering attributes (on-mark numbers, the label's fade) belong to the old text.
        if let layoutManager = textView.textLayoutManager {
            layoutManager.removeRenderingAttribute(.foregroundColor, for: layoutManager.documentRange)
        }
        sizeToLayout()
        rebuildBand()
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    /// The runs of the page's chapter label (the title block's CHAPTER 1, or a later chapter's
    /// label; Lectern's hairline has none), which fade as the head fades in.
    /// The text's distance from the view's top: the page's inset over chapter 1's title block
    /// (the head is hidden there); for a later chapter, whose head shows from the top, the head's
    /// own height and the lead-in a landed line keeps below it, so the first line rests right
    /// under the head.
    /// The head's height changed: a later chapter's text moves to rest right under it again, and
    /// the page is laid out for the new inset, keeping the reader's place.
    private func refreshTopInset() {
        guard let column = textView as? ColumnTextView, layout != nil else { return }
        let top = topInset(for: layout)
        guard column.textContainerInset.height != top else { return }
        column.setTopInset(top)
        columnWidthDidChange()
    }

    private func topInset(for layout: BookLayout?) -> CGFloat {
        guard let layout, !layout.opensWithTitleBlock else { return Self.verticalInset }
        return max(Self.verticalInset, headLineY + Self.scrollLeadIn)
    }

    private static func openingLabelRuns(in layout: BookLayout?) -> [(range: NSRange, color: NSColor)] {
        guard let layout, let first = layout.sections.first, first.openingRange.length > 0 else { return [] }
        var runs: [(range: NSRange, color: NSColor)] = []
        let string = layout.attributedString
        let label = ReaderRole.chapterLabel(first.location.chapter)
        string.enumerateAttributes(in: first.openingRange) { attributes, range, _ in
            guard (attributes[.readerRole] as? ReaderRoleBox)?.role == label else { return }
            let color = attributes[.foregroundColor] as? NSColor ?? Palette.inkSecondary.platformColor
            runs.append((range, color))
        }
        return runs
    }

    /// Lays the whole chapter out and gives the text view's frame the exact content height.
    @discardableResult
    private func sizeToLayout() -> CGFloat {
        let signpost = ReaderSignposts.signposter.beginInterval(ReaderSignposts.sizeToLayout)
        defer { ReaderSignposts.signposter.endInterval(ReaderSignposts.sizeToLayout, signpost) }
        guard let layoutManager = textView.textLayoutManager else { return 0 }
        layoutManager.ensureLayout(for: layoutManager.documentRange)
        // The top inset holds a later chapter's air; the foot keeps only the page's own inset.
        let height = ceil(layoutManager.usageBoundsForTextContainer.maxY + textView.textContainerInset.height + Self.verticalInset + bottomInset)
        contentHeight = height
        isSizing = true
        if abs(documentView.frame.height - height) > 0.5 {
            documentView.setFrameSize(NSSize(width: documentView.frame.width, height: height))
        }
        for layer in [fillsView, textView] as [NSView] where layer.frame != documentView.bounds {
            layer.frame = documentView.bounds
        }
        isSizing = false
        return height
    }

    /// True while the text view's frame does not hold the laid-out content (someone else resized it).
    var isTransientFrame: Bool {
        contentHeight > 0 && (abs(textView.frame.height - contentHeight) > 0.5 || abs(documentView.frame.height - contentHeight) > 0.5)
    }

    /// The column reflowed (window resize or a new measure): re-measure, then put the reader back
    /// on the verse they were reading. False when there is no text to lay out.
    @discardableResult
    fileprivate func columnWidthDidChange() -> Bool {
        let signpost = ReaderSignposts.signposter.beginInterval(ReaderSignposts.columnWidthDidChange)
        defer { ReaderSignposts.signposter.endInterval(ReaderSignposts.columnWidthDidChange, signpost) }
        guard layout != nil else { return false }
        versePanelPageLaidOut()
        reflowCount += 1
        sizeToLayout()
        rebuildBand()
        if pending == nil, let position = lastReportedPosition {
            pending = .position(position)
        }
        performPendingScroll()
        refreshOverlays()
        return true
    }

    /// The column moved without changing width (a window wider than the measure): only what is
    /// drawn from the inset moves.
    fileprivate func columnDidRecentre() {
        guard layout != nil else { return }
        versePanelPageLaidOut()
        refreshOverlays()
    }

    private func textFrameDidChange() {
        guard !isSizing, contentHeight > 0 else { return }
        if isTransientFrame {
            // Something other than the controller resized the view: undo it and keep the place.
            let origin = settledOrigin
            sizeToLayout()
            if pending != nil {
                performPendingScroll()
            } else if let origin {
                scroll(toY: origin.y)
            }
        }
        refreshOverlays()
    }

    private func clipBoundsDidChange() {
        versePanelPageMoved(alongTheKeys: noteClipMoved())
        guard !isTransientFrame else { return }
        refreshSelectionFill()
        if pending == nil { settledOrigin = scrollView.contentView.bounds.origin }
        reportReadingPosition()
        updateRunningHead()
        reportScrollSinceJump()
    }

    /// The clip's travel since the last jump landed, in lines of body text at the current size,
    /// with the target that jump was for, so the model can ignore a report from an earlier landing.
    private func reportScrollSinceJump() {
        guard pending == nil, !isReplacingText, let jumpLandedY, let target = appliedScrollTarget, let typography = appliedTypography,
              typography.bodyLineHeight > 0
        else { return }
        onScrollSinceJump(Double((scrollView.contentView.bounds.minY - jumpLandedY) / typography.bodyLineHeight), target)
    }

    /// The controller's own scroll, clamped to the page.
    func scroll(toY y: CGFloat) {
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: clampedScrollY(y)))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    func clampedScrollY(_ y: CGFloat) -> CGFloat {
        let maxY = max(0, documentView.frame.height - scrollView.contentView.bounds.height)
        return min(max(0, y), maxY)
    }

    /// Scrolls so the pending place's first line sits just below the head's line: a verse's
    /// number, or for verse 1 the top of its chapter's opening. A verse the chapter lacks clamps
    /// to its nearest end. A target waits for its chapter's layout and for the clip view to have
    /// a size; a position in another chapter goes to the shown chapter's opening.
    private func performPendingScroll() {
        guard let pending, let layout, !layout.spans.isEmpty, !isReplacingText else { return }
        guard scrollView.contentView.bounds.height > 0 else { return }
        let location: VerseLocation
        var atEnd = false
        switch pending {
        case .target(let target):
            guard layout.section(for: target.chapter) != nil else { return }
            atEnd = target.atEnd
            location = VerseLocation(book: layout.id.book, chapter: target.chapter, verse: target.verse)
        case .position(let position):
            let chapter = min(max(position.chapter, layout.chapters.lowerBound), layout.chapters.upperBound)
            location = VerseLocation(book: layout.id.book, chapter: chapter, verse: chapter == position.chapter ? position.verse : 1)
        }
        guard let section = layout.section(for: location.chapter) ?? (location.chapter < layout.chapters.lowerBound ? layout.sections.first : layout.sections.last),
              !section.spans.isEmpty
        else { return }
        // Every path that changes the layout sizes the view itself; only a frame someone else
        // changed needs it here.
        if contentHeight <= 0 || isTransientFrame { sizeToLayout() }
        let index: Int
        if location.verse <= 1 {
            index = section.openingRange.location
        } else {
            let spans = section.spans
            let span = spans.first { $0.contains(verse: location.verse) }
                ?? (location.verse > spans.last!.location.verse ? spans.last! : spans.first { $0.location.verse >= location.verse } ?? spans.last!)
            index = span.numberRange.location
        }
        guard let line = lineFrame(forCharacterIndex: index) else { return }
        // A landing on a chapter (not the reader's place put back after a reflow) shows the book
        // thumb for a moment: where in the book this is.
        if case .target = pending { thumbReveal.landed() }
        self.pending = nil
        landedVerse = location
        // The jump's own scroll is not reading on; the distance is measured from where it lands.
        jumpLandedY = nil
        // Verse 1 of the page's chapter is the page's top, where its opening sits below the head
        // (hidden there) as chapter 1's title block does.
        let opensThePage = location.verse <= 1 && section.location.chapter == layout.sections.first?.location.chapter
        // A turn back lands with the chapter's foot at the bottom.
        scroll(toY: atEnd ? .greatestFiniteMagnitude : opensThePage ? 0 : line.minY + textView.textContainerInset.height - Self.scrollLeadIn - headLineY)
        jumpLandedY = scrollView.contentView.bounds.minY
        settledOrigin = scrollView.contentView.bounds.origin
        reportReadingPosition()
        updateRunningHead()
    }

    /// The character index where the first fully visible line below the head's line starts.
    private func topLineStart() -> Int? {
        guard let layoutManager = textView.textLayoutManager, let contentStorage = textView.textContentStorage else { return nil }
        // Text-container coordinates: the head's line minus the inset above the text.
        let visibleTop = scrollView.contentView.bounds.minY + headLineY - textView.textContainerInset.height
        // A fragment is a whole paragraph, so look inside it line by line. The walk starts at the
        // fragment under the top edge (the chapter is laid out), not at the top of the page.
        let start = fragmentNearest(y: visibleTop)?.rangeInElement.location
        var lineStart: Int?
        layoutManager.enumerateTextLayoutFragments(from: start, options: [.ensuresLayout]) { fragment in
            guard fragment.layoutFragmentFrame.maxY > visibleTop else { return true }
            let fragmentTop = fragment.layoutFragmentFrame.minY
            let fragmentStart = contentStorage.offset(from: contentStorage.documentRange.location, to: fragment.rangeInElement.location)
            if let line = fragment.textLineFragments.first(where: { fragmentTop + $0.typographicBounds.minY >= visibleTop - 1 }) {
                lineStart = fragmentStart + line.characterRange.location
                return false
            }
            return true
        }
        return lineStart
    }

    private func reportReadingPosition() {
        let signpost = ReaderSignposts.signposter.beginInterval(ReaderSignposts.reportReadingPosition)
        defer { ReaderSignposts.signposter.endInterval(ReaderSignposts.reportReadingPosition, signpost) }
        guard !isReplacingText, pending == nil, !isTransientFrame, let layout, !layout.spans.isEmpty,
              let lineStart = topLineStart(), let firstVisible = layout.firstVisibleVerse(fromLineStart: lineStart)
        else { return }
        // The landed verse (`ReadingPositionRule`), so the window title and the head never disagree.
        let (position, landed) = ReadingPositionRule.resolve(firstVisible: firstVisible, landed: landedVerse, layout: layout)
        landedVerse = landed
        guard position != lastReportedPosition else { return }
        lastReportedPosition = position
        onReadingPositionChange(position)
    }

    // MARK: - Running head and the foot

    /// The line just under the head, in text-view coordinates: where a jump lands its line, and
    /// where the head measures the chapter's progress.
    private var headLine: CGFloat {
        scrollView.contentView.bounds.minY + headLineY + Self.scrollLeadIn
    }

    /// The chapter's place in the text view, from its line fragments (`ChapterBand.band`).
    private func rebuildBand() {
        chapterBand = layout.flatMap { layout in
            ChapterBand.band(for: layout, inset: textView.textContainerInset.height) {
                lineFrame(forCharacterIndex: $0, ensuringLayout: false)
            }
        }
    }

    /// True when the page scrolls and is scrolled to its foot.
    private var isAtPageFoot: Bool {
        let clip = scrollView.contentView.bounds
        let height = documentView.frame.height
        return height > clip.height && clip.maxY >= height - 0.5
    }

    /// How much of the space reserved under the text (`bottomInset`) the clip shows, reported
    /// when it has moved: 0 until the page's foot comes into view, 1 at the very end.
    private func updateFootReveal() {
        guard !isReplacingText, !isTransientFrame else { return }
        let clip = scrollView.contentView.bounds
        var reveal: Double = 0
        if bottomInset > 0, layout != nil, clip.height > 0 {
            let reserved = documentView.frame.height - bottomInset
            reveal = Double(min(max((clip.maxY - reserved) / bottomInset, 0), 1))
        }
        guard needsFootReport || ReadingProgress.shouldReport(reveal, after: footReveal) else { return }
        needsFootReport = false
        footReveal = reveal
        onFootReveal(reveal)
    }

    /// `RunningHead.state` at the current scroll, reported when it has moved; the page opening's
    /// chapter label (chapter 1's title block or a later chapter's label) fades as the head
    /// fades in.
    private func updateRunningHead() {
        updateFootReveal()
        guard !isReplacingText, pending == nil, !isTransientFrame, let band = chapterBand else { return }
        guard scrollView.contentView.bounds.height > 0 else { return }
        let state = RunningHead.state(band: band, headLineY: headLine + RunningHead.headLineTolerance,
                                      atFoot: isAtPageFoot, reducesMotion: reducesMotion(),
                                      topHeadLineY: headLineY + Self.scrollLeadIn + RunningHead.headLineTolerance,
                                      opensWithTitle: layout?.opensWithTitleBlock ?? true)
        runningHead = state
        applyOpeningLabelAlpha(CGFloat(1 - state.headOpacity))
        if let last = lastReportedHead, last.chapter == state.chapter,
           !ReadingProgress.shouldReport(state.progress, after: last.progress),
           !ReadingProgress.shouldReport(state.headOpacity, after: last.headOpacity) {
            return
        }
        lastReportedHead = state
        onRunningHeadChange(state)
    }

    /// Draws the title block's chapter label at `alpha` through a rendering attribute, so the
    /// text and its layout are untouched; full alpha removes it.
    private func applyOpeningLabelAlpha(_ alpha: CGFloat, force: Bool = false) {
        let alpha = (min(max(alpha, 0), 1) * 100).rounded() / 100
        guard force || alpha != openingLabelAlpha, let layoutManager = textView.textLayoutManager else { return }
        openingLabelAlpha = alpha
        applyOpeningNoteMarkAlpha()
        for run in openingLabelRuns {
            guard let range = textRange(for: run.range) else { continue }
            if alpha >= 1 {
                layoutManager.removeRenderingAttribute(.foregroundColor, for: range)
            } else {
                layoutManager.addRenderingAttribute(.foregroundColor, value: Self.color(run.color, alpha: alpha), for: range)
            }
        }
        if !openingLabelRuns.isEmpty { redrawFragments() }
    }

    /// Draws the laid-out text again after its rendering attributes changed. TextKit 2 draws each
    /// layout fragment in a layer-backed view of its own inside the text view, which the text
    /// view's own `needsDisplay` does not reach; without this a fragment keeps what it was drawn
    /// with as each part of it scrolled in (the phone's `setRenderingColors` meets the same).
    private func redrawFragments() {
        textView.needsDisplay = true
        func mark(_ view: NSView) {
            for subview in view.subviews where !(subview is NoteMarkView) {
                subview.needsDisplay = true
                mark(subview)
            }
        }
        mark(textView)
    }

    /// `color` at `alpha`, resolved per appearance like the palette's own colors.
    private static func color(_ color: NSColor, alpha: CGFloat) -> NSColor {
        NSColor(name: nil) { appearance in
            var resolved = color
            appearance.performAsCurrentDrawingAppearance { resolved = color.usingColorSpace(.sRGB) ?? color }
            return resolved.withAlphaComponent(resolved.alphaComponent * alpha)
        }
    }

    // MARK: - Geometry

    /// The layout fragment at `y` in text-container coordinates (the top one above the text), or
    /// nil where no fragment is (the walk then starts from the top).
    private func fragmentNearest(y: CGFloat) -> NSTextLayoutFragment? {
        textView.textLayoutManager?.textLayoutFragment(for: CGPoint(x: 0, y: max(0, y)))
    }

    /// The frame, in text-container coordinates, of the line holding `characterIndex`.
    /// A fragment is a whole paragraph; this finds the line inside it. Once the controller has
    /// sized the view the whole document is laid out, so `ensuringLayout` can be skipped.
    func lineFrame(forCharacterIndex characterIndex: Int, ensuringLayout: Bool = true) -> NSRect? {
        guard let layoutManager = textView.textLayoutManager, let contentStorage = textView.textContentStorage,
              let location = contentStorage.location(contentStorage.documentRange.location, offsetBy: characterIndex)
        else { return nil }
        if ensuringLayout, let upTo = NSTextRange(location: contentStorage.documentRange.location, end: location) {
            layoutManager.ensureLayout(for: upTo)
        }
        guard let fragment = layoutManager.textLayoutFragment(for: location) else { return nil }
        let fragmentStart = contentStorage.offset(from: contentStorage.documentRange.location, to: fragment.rangeInElement.location)
        let line = fragment.textLineFragments.first { NSLocationInRange(characterIndex - fragmentStart, $0.characterRange) }
        let bounds = line?.typographicBounds ?? NSRect(origin: .zero, size: fragment.layoutFragmentFrame.size)
        return bounds.offsetBy(dx: fragment.layoutFragmentFrame.minX, dy: fragment.layoutFragmentFrame.minY)
    }

    private func textRange(for range: NSRange) -> NSTextRange? {
        guard let contentStorage = textView.textContentStorage,
              let start = contentStorage.location(contentStorage.documentRange.location, offsetBy: range.location),
              let end = contentStorage.location(start, offsetBy: range.length)
        else { return nil }
        return NSTextRange(location: start, end: end)
    }

    /// The rects a highlight's background is painted with, one per line, in text-view
    /// coordinates. The single source of geometry: `applyBackgrounds` fills these and the
    /// outline strokes them outset. Each is built from the line fragment's own character
    /// positions: from the first highlighted character on that line to the end of its last
    /// non-whitespace one (a wrapped line's segment never runs on to the trailing edge), and
    /// vertically the body font's ascent and descent around the line's baseline.
    func segmentFrames(of range: NSRange) -> [NSRect] {
        segmentFrames(of: [range])[0]
    }

    /// How tall a segment is: the body font's ascent and descent around the baseline (a
    /// highlight), or the line fragment's whole height (the selection, as the system fills it).
    private enum SegmentHeight {
        case glyphs
        case line
    }

    /// `segmentFrames(of:)` for every range at once, in the order given, from one walk over the
    /// layout fragments the ranges touch (sorted by location, so each fragment is visited once).
    /// Once the controller has sized the view, the whole document is already laid out.
    private func segmentFrames(of ranges: [NSRange], height: SegmentHeight = .glyphs) -> [[NSRect]] {
        var frames = Array(repeating: [NSRect](), count: ranges.count)
        let text = textView.string as NSString
        let order = ranges.indices
            .filter { ranges[$0].length > 0 && NSMaxRange(ranges[$0]) <= text.length }
            .sorted { ranges[$0].location < ranges[$1].location }
        guard let first = order.first, let layoutManager = textView.textLayoutManager,
              let contentStorage = textView.textContentStorage
        else { return frames }
        let documentStart = contentStorage.documentRange.location
        guard let startLocation = contentStorage.location(documentStart, offsetBy: ranges[first].location) else { return frames }
        if contentHeight <= 0,
           let lastEnd = order.map({ NSMaxRange(ranges[$0]) }).max(),
           let endLocation = contentStorage.location(documentStart, offsetBy: lastEnd),
           let upTo = NSTextRange(location: documentStart, end: endLocation) {
            layoutManager.ensureLayout(for: upTo)
        }
        let inset = textView.textContainerInset
        let storage = textView.textStorage
        let fallbackFont = appliedTypography?.bodyFont ?? NSFont.systemFont(ofSize: 18)
        var fonts = Array(repeating: fallbackFont, count: ranges.count)
        for index in order {
            fonts[index] = storage?.attribute(.font, at: ranges[index].location, effectiveRange: nil) as? NSFont ?? fallbackFont
        }
        var next = 0
        var active: [Int] = []
        layoutManager.enumerateTextLayoutFragments(from: startLocation, options: [.ensuresLayout]) { fragment in
            let fragmentStart = contentStorage.offset(from: documentStart, to: fragment.rangeInElement.location)
            let fragmentEnd = contentStorage.offset(from: documentStart, to: fragment.rangeInElement.endLocation)
            while next < order.count, ranges[order[next]].location < fragmentEnd {
                active.append(order[next])
                next += 1
            }
            active.removeAll { NSMaxRange(ranges[$0]) <= fragmentStart }
            for index in active {
                let range = ranges[index]
                let font = fonts[index]
                let end = NSMaxRange(range)
                for line in fragment.textLineFragments {
                    let lineStart = fragmentStart + line.characterRange.location
                    let lineEnd = lineStart + line.characterRange.length
                    let segmentStart = max(range.location, lineStart)
                    var segmentEnd = min(end, lineEnd)
                    while segmentEnd > segmentStart, Self.isWhitespace(text.character(at: segmentEnd - 1)) { segmentEnd -= 1 }
                    guard segmentEnd > segmentStart else { continue }
                    // `locationForCharacter` is from the line's own origin, which sits at its
                    // typographic bounds: an indented first line or a hanging wrapped line starts
                    // that far in from the fragment's edge.
                    let x0 = line.typographicBounds.minX + line.locationForCharacter(at: segmentStart - fragmentStart).x
                    let x1 = line.typographicBounds.minX + line.locationForCharacter(at: segmentEnd - fragmentStart).x
                    let lineTop = fragment.layoutFragmentFrame.minY + line.typographicBounds.minY
                    let (top, tall) = switch height {
                    case .glyphs: (lineTop + line.glyphOrigin.y - font.ascender, font.ascender - font.descender)
                    case .line: (lineTop, line.typographicBounds.height)
                    }
                    frames[index].append(NSRect(
                        x: fragment.layoutFragmentFrame.minX + x0 + inset.width,
                        y: top + inset.height,
                        width: max(0, x1 - x0),
                        height: tall))
                }
            }
            active.removeAll { NSMaxRange(ranges[$0]) <= fragmentEnd }
            return next < order.count || !active.isEmpty
        }
        return frames
    }

    private static func isWhitespace(_ unit: unichar) -> Bool {
        unit == 0x20 || unit == 0x0A || unit == 0x2028 || unit == 0x09
    }

    /// Lays the column out now at the view's width if a resize is still waiting to (tests, and
    /// the end of a live resize).
    func flushPendingReflow() {
        (textView as? ColumnTextView)?.flushPendingReflow()
    }

    /// Collapses a selection to a caret at its start (the markup menu does this after a swatch,
    /// so the new color is not hidden under the selection color).
    public func collapseSelection() {
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        textView.setSelectedRange(NSRange(location: range.location, length: 0))
    }

    /// Where a popover or share picker should anchor for `range`, in text-view coordinates.
    public func frameOfFirstSegment(of range: NSRange) -> NSRect? {
        segmentFrames(of: range).first
    }

    // MARK: - Decorations

    private static func underlines(in decorations: BookDecorations) -> [Underline] {
        decorations.highlights.compactMap { decoration in
            switch decoration.style {
            case .background: return nil
            // Both in secondary ink: tertiary disappears on the dark page under a lamp. The pattern
            // tells them apart (dotted: a note without a color; dashed: made in another translation).
            case .dottedUnderline: return Underline(range: decoration.range, style: NSUnderlineStyle([.single, .patternDot]).rawValue)
            case .dashedUnderline: return Underline(range: decoration.range, style: NSUnderlineStyle([.single, .patternDash]).rawValue)
            }
        }
    }

    /// A decoration change after the load (a user action): underlines are storage attributes, so
    /// only the ranges that stop or start being underlined (and any underline overlapping one that
    /// stops) are edited, the frame is re-measured and the scroll position kept; backgrounds are
    /// painted behind the text and need no re-layout.
    private func applyDecorationChange() {
        let new = Self.underlines(in: appliedDecorations)
        if let storage = textView.textStorage, new != underlines {
            let length = storage.length
            let removed = Set(underlines).subtracting(new).filter { NSMaxRange($0.range) <= length }
            let kept = Set(underlines)
            let added = new.filter { underline in
                NSMaxRange(underline.range) <= length
                    && (!kept.contains(underline) || removed.contains { NSIntersectionRange($0.range, underline.range).length > 0 })
            }
            if !removed.isEmpty || !added.isEmpty {
                let origin = scrollView.contentView.bounds.origin
                textView.textContentStorage?.performEditingTransaction {
                    storage.beginEditing()
                    for underline in removed {
                        storage.removeAttribute(.underlineStyle, range: underline.range)
                        storage.removeAttribute(.underlineColor, range: underline.range)
                    }
                    for underline in added {
                        storage.addAttributes([.underlineStyle: underline.style, .underlineColor: Palette.inkSecondary.platformColor], range: underline.range)
                    }
                    storage.endEditing()
                }
                sizeToLayout()
                if pending == nil, scrollView.contentView.bounds.origin != origin { scroll(toY: origin.y) }
            }
            underlines = new
        }
        refreshOverlays()
    }

    /// Paints the chapter's highlights and recolors their on-mark verse numbers.
    private func applyHighlights() {
        let length = textView.textStorage?.length ?? 0
        let colored = layout == nil ? [] : appliedDecorations.highlights.compactMap { decoration -> (RangeDecoration, NSColor)? in
            guard case .background(let color) = decoration.style, NSMaxRange(decoration.range) <= length else { return nil }
            return (decoration, color.platformColor)
        }
        applyBackgrounds(colored)
        applyNumberColors(colored.map(\.0))
    }

    /// Computes the background fills from the same per-line rects the outline uses and hands
    /// them to the fills view, which paints them under the text. Where two highlights overlap,
    /// the overlapping range is painted again, after both, with a 50/50 blend.
    private func applyBackgrounds(_ colored: [(RangeDecoration, NSColor)]) {
        let signpost = ReaderSignposts.signposter.beginInterval(ReaderSignposts.applyBackgrounds)
        defer { ReaderSignposts.signposter.endInterval(ReaderSignposts.applyBackgrounds, signpost) }
        // Overlapping pairs, found by sweeping the ranges in order of location: a range is only
        // compared with those that start before it ends. Kept in the (i, j) order they paint in.
        let byLocation = colored.indices.sorted { colored[$0].0.range.location < colored[$1].0.range.location }
        var overlaps: [(i: Int, j: Int, range: NSRange)] = []
        for (position, a) in byLocation.enumerated() {
            let endA = NSMaxRange(colored[a].0.range)
            for b in byLocation[(position + 1)...] {
                guard colored[b].0.range.location < endA else { break }
                let overlap = NSIntersectionRange(colored[a].0.range, colored[b].0.range)
                guard overlap.length > 0 else { continue }
                overlaps.append((min(a, b), max(a, b), overlap))
            }
        }
        overlaps.sort { ($0.i, $0.j) < ($1.i, $1.j) }
        let segments = segmentFrames(of: colored.map(\.0.range) + overlaps.map(\.range))
        var fills: [HighlightFill] = []
        for (index, (decoration, color)) in colored.enumerated() {
            for rect in segments[index] {
                fills.append(HighlightFill(id: decoration.id, rect: rect, color: color))
            }
        }
        for (index, overlap) in overlaps.enumerated() {
            let blended = NSColor.blendedMarkup(colored[overlap.i].1, colored[overlap.j].1)
            for rect in segments[colored.count + index] {
                fills.append(HighlightFill(id: nil, rect: rect, color: blended))
            }
        }
        backgroundFills = fills
        fillsView.fills = fills
    }

    /// A verse number inside a highlight draws in the style's on-mark color where it has one
    /// (`ReaderTypography.verseNumberColorOnMark`), as a rendering attribute.
    private func applyNumberColors(_ highlights: [RangeDecoration]) {
        guard let layoutManager = textView.textLayoutManager else { return }
        for range in numberColorRanges {
            if let textRange = textRange(for: range) { layoutManager.removeRenderingAttribute(.foregroundColor, for: textRange) }
        }
        let hadRanges = !numberColorRanges.isEmpty
        numberColorRanges = []
        if let layout, let color = appliedTypography?.verseNumberColorOnMark {
            for highlight in highlights {
                guard let section = layout.section(containing: highlight.range.location) else { continue }
                for span in section.spans where span.numberRange.length > 0
                    && span.numberRange.location >= highlight.range.location && NSMaxRange(span.numberRange) <= NSMaxRange(highlight.range) {
                    guard let textRange = textRange(for: span.numberRange) else { continue }
                    layoutManager.addRenderingAttribute(.foregroundColor, value: color, for: textRange)
                    numberColorRanges.append(span.numberRange)
                }
            }
        }
        if hadRanges || !numberColorRanges.isEmpty { redrawFragments() }
    }

    /// Recomputes everything drawn from line geometry (the highlight fills, the outline, the
    /// gutter glyphs, the chapter-note mark, the drop numeral) from the current layout, so a
    /// reflow can never leave one of them stale.
    private func refreshOverlays() {
        refreshChapterNoteMarks()
        refreshDropNumeral()
        applyHighlights()
        refreshSelectionFill()
        guard let layout else {
            gutterView.glyphRects = []
            gutterView.glyphVerses = []
            outlineView.segmentRects = []
            return
        }
        applyOpeningLabelAlpha(openingLabelAlpha, force: true)
        let inset = textView.textContainerInset
        let size = MarkupGutterView.glyphSize
        // Beside the line where the verse's text starts; the number can end the previous line.
        let glyphs = appliedDecorations.bookmarks.compactMap { verse -> (verse: VerseLocation, rect: NSRect)? in
            guard let span = layout.span(for: verse), let line = lineFrame(forCharacterIndex: span.textRange.location, ensuringLayout: contentHeight <= 0)
            else { return nil }
            let y = line.minY + inset.height + max(0, (line.height - size) / 2)
            return (span.location, NSRect(x: inset.width - Self.gutterGlyphOffset, y: y, width: size, height: size))
        }
        gutterView.glyphVerses = glyphs.map(\.verse)
        gutterView.glyphRects = glyphs.map(\.rect)
        // The outline is the outlined highlight's own background rects, outset on every side.
        if let id = appliedDecorations.outlinedID, let decoration = appliedDecorations.decoration(id: id) {
            outlineView.segmentRects = segmentFrames(of: decoration.range).map { $0.insetBy(dx: -Self.outlineMargin, dy: -Self.outlineMargin) }
        } else {
            outlineView.segmentRects = []
        }
    }

    /// Places Lectern's numeral beside the chapter's laid-out first line (`DropNumeral.placements`)
    /// in its view, made for the chapter it names; none in the other styles.
    private func refreshDropNumeral() {
        var placement: DropNumeral.Placement?
        if let layout, let typography = appliedTypography, let layoutManager = textView.textLayoutManager,
           let contentStorage = textView.textContentStorage {
            placement = DropNumeral.placements(in: layout, typography: typography, layoutManager: layoutManager, contentStorage: contentStorage).first
        }
        guard let placement, let typography = appliedTypography else {
            numeralView?.removeFromSuperview()
            numeralView = nil
            return
        }
        if numeralView?.chapter != placement.chapter {
            numeralView?.removeFromSuperview()
            let made = DropNumeralView(chapter: placement.chapter)
            textView.addSubview(made, positioned: .below, relativeTo: gutterView)
            numeralView = made
        }
        numeralView?.place(placement, font: DropNumeral.font(for: typography), inset: textView.textContainerInset)
    }

    // MARK: - Selection and menu

    private func selectionDidChange() {
        if textView.selectedRange() != verseSelection {
            verseSelection = nil
            verseAnchor = nil
        }
        if !isClearingAway { selectionWasClearedAway = false }
        // A replacement refills once the new text is laid out (`refreshOverlays`).
        guard !isReplacingText else { return }
        refreshSelectionFill()
        onSelectionChange(isClearingAway ? nil : selectionReport())
    }

    /// True while `clearSelection` sets its caret.
    private var isClearingAway = false
    /// True from a click away until the selection next changes.
    private var selectionWasClearedAway = false

    /// Whether a Shift-click extends the selection: not after a click away, which leaves nothing
    /// to extend from (`ColumnTextView.mouseDown` then takes it as a plain click).
    var shiftClickExtends: Bool { !selectionWasClearedAway }

    /// How far above and below the visible rect the selection is filled: half a clip, so the
    /// lines a scroll brings in are filled before they show.
    static func selectionFillMargin(for visible: NSRect) -> CGFloat {
        visible.height / 2
    }

    /// Fills the selection behind its words, from the same segments the highlights are painted
    /// with (one per line, first selected glyph to last), at the line's full height and joined to
    /// the next line's as the system's fill is. Only the lines in or near view are filled, so a
    /// drag or Select All in a long chapter never lays out or walks the whole chapter; a scroll,
    /// a reflow and new text refill.
    func refreshSelectionFill() {
        let selected = textView.selectedRanges.map(\.rangeValue).filter { $0.length > 0 }
        var rects: [NSRect] = []
        if layout != nil, !selected.isEmpty, let (band, characters) = selectionFillBand() {
            let clipped = selected.map { NSIntersectionRange($0, characters) }.filter { $0.length > 0 }
            for lines in segmentFrames(of: clipped, height: .line) {
                rects += Self.joined(lines).filter { $0.intersects(band) }
            }
        }
        let changed = rects != selectionFills
        selectionFills = rects
        fillsView.selectionRects = rects
        updateSelectionEmphasis()
        if changed { onSelectionFillChange(rects) }
    }

    /// The visible rect with its margin, in text-view coordinates, and the characters of the
    /// layout fragments it touches; nil while the clip has no height.
    private func selectionFillBand() -> (NSRect, NSRange)? {
        guard let layoutManager = textView.textLayoutManager, let contentStorage = textView.textContentStorage else { return nil }
        let visible = scrollView.documentVisibleRect
        guard visible.height > 0 else { return nil }
        let band = visible.insetBy(dx: 0, dy: -Self.selectionFillMargin(for: visible))
        let inset = textView.textContainerInset.height
        let documentStart = contentStorage.documentRange.location
        // Where no fragment is (above the text, below it), the band runs to the text's end.
        let start = fragmentNearest(y: band.minY - inset)
            .map { contentStorage.offset(from: documentStart, to: $0.rangeInElement.location) } ?? 0
        let end = layoutManager.textLayoutFragment(for: CGPoint(x: 0, y: band.maxY - inset))
            .map { contentStorage.offset(from: documentStart, to: $0.rangeInElement.endLocation) } ?? (textView.textStorage?.length ?? 0)
        return (band, NSRange(location: start, length: max(0, end - start)))
    }

    /// One selection's line rects with each line's run down to the next line's top, so
    /// consecutive lines (a stanza's air between them too) read as one fill.
    private static func joined(_ lines: [NSRect]) -> [NSRect] {
        var joined = lines
        for index in joined.indices.dropLast() {
            let gap = joined[index + 1].minY - joined[index].maxY
            if gap > 0, gap <= joined[index].height { joined[index].size.height += gap }
        }
        return joined
    }

    /// The system's emphasis: its strong colour while the reader's text has the keyboard in the
    /// key window, its quieter one otherwise. `focused` is the text view's own word while its
    /// first responder status is changing.
    func updateSelectionEmphasis(focused: Bool? = nil) {
        let window = textView.window
        fillsView.selectionIsEmphasized = window?.isKeyWindow == true && (focused ?? (window?.firstResponder === textView))
    }

    /// The innermost highlight whose range contains `range` (a caret counts at either end).
    private func innermostHighlight(containing range: NSRange) -> RangeDecoration? {
        ReaderTextLogic.innermostHighlight(containing: range, in: appliedDecorations)
    }

    /// The current selection resolved to verses of one chapter, or nil when it covers no verse
    /// text (an opening or a heading never counts). A caret inside a highlight reports the
    /// innermost containing highlight's range as the selection (and names it as primary)
    /// without the text view selecting anything.
    func selectionReport() -> SelectionReport? {
        guard let layout else { return nil }
        return ReaderTextLogic.report(for: textView.selectedRange(), layout: layout, decorations: appliedDecorations)
    }

    /// What a markup action should act on: a caret inside a highlight means that whole highlight
    /// (the innermost when nested; the caret itself is left alone so the highlight's own color
    /// stays visible); a drag snaps to whole words; a caret elsewhere means nothing. The Mac snaps
    /// with AppKit's word selection, not `ReaderTextLogic.snapToWords` (see its note).
    func actionRange() -> NSRange? {
        let range = textView.selectedRange()
        if range.length == 0 { return innermostHighlight(containing: range)?.range }
        return textView.selectionRange(forProposedRange: range, granularity: .selectByWord)
    }

    /// Snaps a non-empty selection to words and returns the report, or nil when there is nothing
    /// to act on.
    func reportForAction() -> SelectionReport? {
        if textView.selectedRange().length > 0, let snapped = actionRange(), snapped != textView.selectedRange() {
            textView.setSelectedRange(snapped)
        }
        return selectionReport()
    }

    /// Right-click: the selection (snapped to words), else the highlight under the caret, else
    /// the word under the pointer, then the provider's menu at the pointer. Nil falls back to
    /// the text view's standard menu.
    fileprivate func menu(for event: NSEvent) -> NSMenu? {
        let point = textView.convert(event.locationInWindow, from: nil)
        let index = textView.characterIndexForInsertion(at: point)
        let current = textView.selectedRange()
        if current.length > 0, !NSLocationInRange(index, current) {
            textView.setSelectedRange(NSRange(location: index, length: 0))
        }
        if textView.selectedRange().length == 0, actionRange() == nil {
            textView.setSelectedRange(textView.selectionRange(forProposedRange: NSRange(location: index, length: 0), granularity: .selectByWord))
        }
        guard let report = reportForAction() else { return nil }
        return menuProvider(report)
    }

    /// Mouse-up after a click or drag in the text (`point` in text-view coordinates). A plain
    /// click (one click that left a caret outside every highlight) on a verse's lines selects the
    /// whole verse. Then the verse, a drag (snapped to words), a double-click's word or a click
    /// inside a highlight opens the markup menu beside what it acts on (`menuOrigin`); a click off
    /// the text opens nothing.
    func clickEnded(at point: NSPoint, clickCount: Int) {
        let selected = textView.selectedRange()
        if clickCount == 1, selected.length == 0, innermostHighlight(containing: selected) == nil, let span = verseSpan(at: point) {
            selectVerses(span.textRange, anchor: span.textRange.location)
        }
        showMenu(click: point)
    }

    /// The markup menu for what the selection acts on, and what follows its closing. A choice or
    /// a key leaves things as they are (after Esc the selection stays for the keys). A click
    /// anywhere outside it only deselects: the menu holds the mouse while it is open and swallows
    /// that click. The one exception is the second click of a double-click on a verse's word,
    /// which selects the word and opens the word's menu, as a double-click does with no menu up.
    private func showMenu(click: NSPoint) {
        var click = click
        while let range = actionRange(), let report = reportForAction(), let menu = menuProvider(report) {
            switch presentMenu(menu, menuOrigin(for: range, menuSize: menu.size, click: click), click) {
            case .chosen, .closedWithoutAClick:
                return
            case .mouseDown(let point, let clickCount):
                guard clickCount == 2, let point, let word = word(at: point) else {
                    clearSelection()
                    return
                }
                textView.setSelectedRange(word)
                click = point
            }
        }
    }

    /// The selection cleared, a highlight's outline with it, and reported as none, once. Nothing
    /// of it remains: the caret goes to the text's start (the page's opening, in no verse and no
    /// highlight, so J and K start from the page), and until something is selected again a
    /// Shift-click is a plain click (`shiftClickExtends`), not an extension from that caret.
    func clearSelection() {
        let caret = NSRange(location: 0, length: 0)
        verseSelection = nil
        verseAnchor = nil
        keyRange = nil
        if textView.selectedRange() == caret {
            refreshSelectionFill()
            onSelectionChange(nil)
        } else {
            isClearingAway = true
            textView.setSelectedRange(caret)    // reported as none by `selectionDidChange`
            isClearingAway = false
        }
        selectionWasClearedAway = true
    }

    /// The word a double-click at `point` (text-view coordinates) selects, on a verse's lines;
    /// nil elsewhere. The character under the point is the one before the caret's place when the
    /// point is on that character's right half.
    func word(at point: NSPoint) -> NSRange? {
        guard verseSpan(at: point) != nil else { return nil }
        let length = (textView.string as NSString).length
        let index = textView.characterIndexForInsertion(at: point)
        guard index != NSNotFound else { return nil }
        let under = [index - 1, index].first { candidate in
            candidate >= 0 && candidate < length && segmentFrames(of: NSRange(location: candidate, length: 1)).contains { glyph in
                point.x >= glyph.minX && point.x <= glyph.maxX && abs(point.y - glyph.midY) <= glyph.height
            }
        } ?? min(index, max(0, length - 1))
        let word = textView.selectionRange(forProposedRange: NSRange(location: under, length: 1), granularity: .selectByWord)
        return word.length > 0 ? word : nil
    }

    /// The space between a selection's line and the menu beside it.
    static let menuGap: CGFloat = outlineMargin + 2

    /// Where the markup menu's top-left goes for `range`, on the page as it is now: the visible
    /// rect below the running head.
    func menuOrigin(for range: NSRange, menuSize: NSSize, click: NSPoint?) -> NSPoint {
        let visible = scrollView.documentVisibleRect
        let page = NSRect(x: visible.minX, y: visible.minY + headLineY, width: visible.width, height: max(0, visible.height - headLineY))
        return Self.menuOrigin(for: segmentFrames(of: range), in: page, menuSize: menuSize, click: click)
    }

    /// Where the markup menu's top-left goes for a selection painted on `lines` (text-view
    /// coordinates, flipped), with `visible` the reader's visible area and `click` the click that
    /// opens it: at the selection's left edge, just below its last visible line when the menu
    /// fits there, else just above its first visible line when it fits there, so it covers no
    /// selected word. The pointer is never inside the menu as it opens, so a double-click's second
    /// click can never choose an item: where neither side has room (AppKit would fit the menu to
    /// the screen, maybe under the pointer), or the place found would hold the click's point, the
    /// menu opens beside the click instead (`besideClick`). Only lines in view count, unless none is.
    static func menuOrigin(for lines: [NSRect], in visible: NSRect, menuSize: NSSize, click: NSPoint?) -> NSPoint {
        let shown = lines.filter { $0.intersects(visible) }
        let bounds = (shown.isEmpty ? lines : shown).reduce(NSRect.null) { $0.union($1) }
        guard !bounds.isNull else { return click.map { besideClick($0, in: visible, menuSize: menuSize) } ?? visible.origin }
        let below = NSPoint(x: bounds.minX, y: bounds.maxY + menuGap)
        let above = NSPoint(x: bounds.minX, y: bounds.minY - menuGap - menuSize.height)
        let place: NSPoint?
        if below.y + menuSize.height <= visible.maxY {
            place = below
        } else if above.y >= visible.minY {
            place = above
        } else {
            place = nil
        }
        guard let click else { return place ?? below }
        if let place, !NSRect(origin: place, size: menuSize).contains(click) { return place }
        return besideClick(click, in: visible, menuSize: menuSize)
    }

    /// The menu beside `click`, wholly to its right when it fits in `visible`, else wholly to its
    /// left, at the click's height as far as `visible` allows: AppKit may slide a menu up or down
    /// to fit the screen, never across the pointer from beside it. **(call)**
    static func besideClick(_ click: NSPoint, in visible: NSRect, menuSize: NSSize) -> NSPoint {
        let right = click.x + menuGap
        let left = click.x - menuGap - menuSize.width
        let x = right + menuSize.width <= visible.maxX || left < visible.minX ? right : left
        let y = min(max(click.y - menuSize.height / 2, visible.minY), max(visible.minY, visible.maxY - menuSize.height))
        return NSPoint(x: x, y: y)
    }

    /// Shows `menu` with its top-left at `origin` (text-view coordinates) and gathers what AppKit
    /// reports as it closes, for `menuEnding`: the one place the real closing is read. `popUp` is
    /// modal and returns true for a chosen item; the swatch row, which closes the menu itself
    /// after its pick, marks the menu instead (`MarkupMenu.rowActed`).
    func popUpMenu(_ menu: NSMenu, at origin: NSPoint, click: NSPoint) -> MarkupMenuEnding {
        let opened = ProcessInfo.processInfo.systemUptime
        let chosen = menu.popUp(positioning: nil, at: origin, in: textView) || (menu as? MarkupMenu)?.rowActed == true
        let window = textView.window
        // A click count and a point only from a mouse event (`clickCount` raises on any other).
        let event = NSApp.currentEvent.map { event in
            let isClick = Self.closingClicks.contains(event.type)
            return MenuCloseState.Event(type: event.type, time: event.timestamp, clickCount: isClick ? event.clickCount : 0,
                                        point: isClick && event.window === window ? textView.convert(event.locationInWindow, from: nil) : nil)
        }
        let screen = NSEvent.mouseLocation
        let pointer = window.flatMap { window in
            NSWindow.windowNumber(at: screen, belowWindowWithWindowNumber: 0) == window.windowNumber
                ? textView.convert(window.convertPoint(fromScreen: screen), from: nil) : nil
        }
        return Self.menuEnding(MenuCloseState(chosen: chosen, event: event, buttonsDown: NSEvent.pressedMouseButtons, pointer: pointer,
                                              opened: opened, now: ProcessInfo.processInfo.systemUptime, click: click))
    }

    /// What AppKit reports as the markup menu's `popUp` returns (`popUpMenu`): whether an item was
    /// chosen (or the swatch row acted), the current event (its point in text-view coordinates,
    /// nil when not in the reader's window), the mouse buttons down, the pointer (nil unless the
    /// reader's window is the top window under it), when the menu opened, now, and the click
    /// that opened it.
    struct MenuCloseState {
        struct Event {
            var type: NSEvent.EventType
            var time: TimeInterval
            var clickCount: Int
            var point: NSPoint?
        }
        var chosen: Bool
        var event: Event?
        var buttonsDown: Int
        var pointer: NSPoint?
        var opened: TimeInterval
        var now: TimeInterval
        var click: NSPoint
    }

    /// The mouse events that close a menu from outside it: either half of a click, as menu
    /// tracking may take the whole click before `popUp` returns.
    static let closingClicks: [NSEvent.EventType] = [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp]

    /// How the menu closed, from what AppKit reported. A choice first. Then a mouse-down or -up
    /// stamped at or after the menu opened (the opening click's own mouse-up is earlier): a
    /// click away at its point, with its own click count for the left button (a mouse-up carries
    /// it too). Then a button still down: the click, at the pointer, the second of a double-click
    /// when it is the left button alone, within the double-click time of the menu opening and
    /// within 4 points of the opening click. Anything else (Esc, a lost focus): closed without a
    /// click.
    static func menuEnding(_ state: MenuCloseState) -> MarkupMenuEnding {
        if state.chosen { return .chosen }
        if let event = state.event, event.time >= state.opened, closingClicks.contains(event.type) {
            let left = event.type == .leftMouseDown || event.type == .leftMouseUp
            return .mouseDown(at: event.point, clickCount: left ? event.clickCount : 1)
        }
        guard state.buttonsDown != 0 else { return .closedWithoutAClick }
        guard let pointer = state.pointer else { return .mouseDown(at: nil, clickCount: 1) }
        let isDouble = state.buttonsDown == 1 && state.now - state.opened <= NSEvent.doubleClickInterval
            && hypot(pointer.x - state.click.x, pointer.y - state.click.y) <= 4
        return .mouseDown(at: pointer, clickCount: isDouble ? 2 : 1)
    }

    /// Selects whole verses and remembers the anchor (a character index in the verse that ⇧J and
    /// ⇧K keep selected).
    func selectVerses(_ range: NSRange, anchor: Int) {
        verseSelection = range
        verseAnchor = anchor
        textView.setSelectedRange(range)
    }

    /// The verse whose lines `point` is on (`point` in text-view coordinates): the character
    /// AppKit would put the caret at, then `ReaderTextLogic.verse(at:in:isOnLines:)`.
    func verseSpan(at point: NSPoint) -> VerseSpan? {
        guard let layout else { return nil }
        let index = textView.characterIndexForInsertion(at: point)
        return ReaderTextLogic.verse(at: index, in: layout) { isOnLines($0, at: point) }
    }

    /// As the phone's: horizontally the verse's painted segment on a line, vertically that line
    /// fragment's whole height, outset by `outlineMargin`; `point` in text-view coordinates.
    func isOnLines(_ span: VerseSpan, at point: NSPoint) -> Bool {
        let margin = Self.outlineMargin
        let inset = textView.textContainerInset
        return segmentFrames(of: span.fullRange).contains { segment in
            guard point.x >= segment.minX - margin, point.x <= segment.maxX + margin else { return false }
            // The segment's first character, which names its line.
            let start = textView.characterIndexForInsertion(at: NSPoint(x: segment.minX + min(1, segment.width / 2), y: segment.midY))
            guard start != NSNotFound,
                  let line = lineFrame(forCharacterIndex: start, ensuringLayout: contentHeight <= 0)?.offsetBy(dx: inset.width, dy: inset.height)
            else { return false }
            return point.y >= line.minY - margin && point.y <= line.maxY + margin
        }
    }
}

/// How the markup menu closed: an item chosen (a swatch too); closed with no mouse-down (Esc); or
/// by a mouse-down outside it, at a point in the text view's coordinates (nil when it was not in
/// the reader's window) with the system's click count (1 for a button other than the left).
enum MarkupMenuEnding: Equatable {
    case chosen
    case closedWithoutAClick
    case mouseDown(at: NSPoint?, clickCount: Int)
}

/// A flipped container so the document's coordinates match the text view's.
final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// Paints the highlight backgrounds behind the (transparent) text view, from the same rects the
/// outline strokes, and the selection's fill over them (still under the text). Flipped like the
/// text view, never hit-tested.
public final class HighlightFillView: NSView {
    public var fills: [ChapterTextController.HighlightFill] = [] {
        didSet { if fills != oldValue { needsDisplay = true } }
    }

    /// The selection's line rects (`ChapterTextController.selectionFills`), kept apart from the
    /// highlights' fills. A change redraws only where the old and new selection lie, as a drag
    /// changes it on every mouse move.
    public var selectionRects: [NSRect] = [] {
        didSet {
            guard selectionRects != oldValue else { return }
            let changed = (oldValue + selectionRects).reduce(NSRect.null) { $0.union($1) }
            if !changed.isNull { setNeedsDisplay(changed) }
        }
    }

    /// The system's emphasis (`ChapterTextController.updateSelectionEmphasis`).
    public var selectionIsEmphasized = false {
        didSet {
            guard selectionIsEmphasized != oldValue else { return }
            let selection = selectionRects.reduce(NSRect.null) { $0.union($1) }
            if !selection.isNull { setNeedsDisplay(selection) }
        }
    }

    /// The system's own selection colours, so only the fill's shape is the app's: the one place
    /// a system colour is right in the reader, since this is the system's selection.
    public static func selectionColor(emphasized: Bool) -> NSColor {
        emphasized ? .selectedTextBackgroundColor : .unemphasizedSelectedTextBackgroundColor
    }

    public override var isFlipped: Bool { true }
    public override func hitTest(_ point: NSPoint) -> NSView? { nil }

    public override func draw(_ dirtyRect: NSRect) {
        for fill in fills where fill.rect.intersects(dirtyRect) {
            fill.color.setFill()
            NSBezierPath(roundedRect: fill.rect, xRadius: 2, yRadius: 2).fill()
        }
        // One path, so the joined lines fill as one shape with no seam between them; square
        // cornered like the system's.
        let selection = NSBezierPath()
        for rect in selectionRects where rect.intersects(dirtyRect) { selection.appendRect(rect) }
        guard !selection.isEmpty else { return }
        Self.selectionColor(emphasized: selectionIsEmphasized).setFill()
        selection.fill()
    }
}

/// Keeps the text column centred and no wider than the typography's measure, tells the
/// controller when the column reflows, routes the context menu through it, and lists the
/// gutter's bookmarks among its accessibility children.
final class ColumnTextView: NSTextView {
    weak var columnDelegate: ChapterTextController?
    private(set) var measure: CGFloat = ChapterTextController.maximumColumnWidth

    /// How long width changes must stop before the column reflows: a long chapter (Psalm 119) is
    /// costly to lay out, so an animated resize (the inspector sliding in) lays it out once,
    /// after its last frame, and a single resize shows the old width for this long.
    static let reflowCoalescing: Duration = .milliseconds(150)
    /// True while the column keeps a width the view no longer has, waiting for the resize to settle.
    private var hasPendingReflow = false
    /// The width the view was last asked to take (`setFrameSize`); its frame can be wider while a
    /// reflow waits.
    private var availableWidth: CGFloat = 0
    /// Bumped by each width change that waits, so only the last one's timer reflows.
    private var pendingGeneration = 0

    /// A new measure (the body size or column width changed): re-centre the column at the
    /// current width. The caller lays the text out next, so no reflow is reported here.
    func setMeasure(_ newMeasure: CGFloat) {
        guard newMeasure != measure else { return }
        measure = newMeasure
        hasPendingReflow = false
        let width = viewWidth
        let column = columnWidth(for: width)
        textContainer?.size = NSSize(width: column, height: CGFloat.greatestFiniteMagnitude)
        if frame.width != width { super.setFrameSize(NSSize(width: width, height: frame.height)) }
        recentre(width: width, column: column)
    }

    /// A wider or narrower view. Within the measure's width it only re-centres the column (no
    /// layout). A new column width never lays the text out from here once there is text: the
    /// column keeps its width, centred, and reflows once when the live resize ends or the width
    /// has stopped changing for `reflowCoalescing`. Before there is text it takes the width at once.
    override func setFrameSize(_ requested: NSSize) {
        // The view always fills its superview (the document view): read the width from there, since
        // autoresizing applies the superview's change to this view's frame, which a waiting reflow
        // can hold wider than asked.
        let newSize = NSSize(width: superview?.bounds.width ?? requested.width, height: requested.height)
        let previousWidth = availableWidth
        availableWidth = newSize.width
        guard let current = textContainer?.size.width else {
            super.setFrameSize(newSize)
            return
        }
        let column = columnWidth(for: newSize.width)
        guard newSize.width != previousWidth else {
            super.setFrameSize(NSSize(width: hasPendingReflow ? max(newSize.width, current) : newSize.width, height: newSize.height))
            return
        }
        if column == current {
            super.setFrameSize(newSize)
            hasPendingReflow = false
            if recentre(width: newSize.width, column: column) { columnDelegate?.columnDidRecentre() }
            return
        }
        guard columnDelegate?.layout != nil else {
            super.setFrameSize(newSize)
            reflow()
            return
        }
        hasPendingReflow = true
        // Until then the old column stays centred, its margins narrowing rather than its text
        // running off the edge; past that, the view stays as wide as the column, its overflow
        // clipped. A text view narrower than its text container costs TextKit a fresh layout of
        // the whole text on every frame, which a legacy scroller's 15 points brought on in an
        // animated narrowing.
        super.setFrameSize(NSSize(width: max(newSize.width, current), height: newSize.height))
        if recentre(width: newSize.width, column: current, minimumInset: 0) { columnDelegate?.columnDidRecentre() }
        if !inLiveResize { scheduleReflow() }
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        flushPendingReflow()
    }

    /// Reflows now if a width change is waiting.
    func flushPendingReflow() {
        guard hasPendingReflow else { return }
        reflow()
    }

    private func reflow() {
        hasPendingReflow = false
        let width = viewWidth
        let column = columnWidth(for: width)
        textContainer?.size = NSSize(width: column, height: CGFloat.greatestFiniteMagnitude)
        if frame.width != width { super.setFrameSize(NSSize(width: width, height: frame.height)) }
        recentre(width: width, column: column)
        columnDelegate?.columnWidthDidChange()
    }

    /// The width the view was last given; its frame can be wider while a reflow waits.
    private var viewWidth: CGFloat { availableWidth > 0 ? availableWidth : frame.width }

    private func scheduleReflow() {
        pendingGeneration += 1
        let generation = pendingGeneration
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.reflowCoalescing)
            guard let self, generation == self.pendingGeneration, !self.inLiveResize else { return }
            self.flushPendingReflow()
        }
    }

    /// The measure, or the width less the side insets when narrower.
    private func columnWidth(for width: CGFloat) -> CGFloat {
        min(measure, max(200, width - 2 * ChapterTextController.horizontalInset))
    }

    /// Centres a column `column` wide in `width`, its side inset at least `minimumInset`; true
    /// when the inset changed.
    @discardableResult
    private func recentre(width: CGFloat, column: CGFloat, minimumInset: CGFloat = ChapterTextController.horizontalInset) -> Bool {
        let inset = max(minimumInset, (width - column) / 2)
        guard textContainerInset.width != inset else { return false }
        textContainerInset = NSSize(width: inset, height: textContainerInset.height)
        return true
    }

    /// The text's distance from the view's top (`ChapterTextController.topInset`). The caller
    /// lays the text out next.
    func setTopInset(_ top: CGFloat) {
        guard textContainerInset.height != top else { return }
        textContainerInset = NSSize(width: textContainerInset.width, height: top)
    }

    /// Writes only verse text (copy, drag and Services all come through here): the selection
    /// resolved to its chapter's verses, never a heading, label, title or verse number.
    override func writeSelection(to pboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        guard types.contains(.string), selectedRange().length > 0, let text = columnDelegate?.selectionReport()?.selection.quotedText, !text.isEmpty else { return false }
        pboard.declareTypes([.string], owner: nil)
        return pboard.setString(text, forType: .string)
    }

    override func accessibilityChildren() -> [Any]? {
        let bookmarks = columnDelegate?.gutterView.accessibilityElements(parent: self) ?? []
        let numerals = [columnDelegate?.numeralView].compactMap { $0 }
        let marks = (columnDelegate?.chapterNoteMarkViews ?? [:]).sorted { $0.key < $1.key }.map(\.value).filter { !$0.isHidden }
        let children = (super.accessibilityChildren() ?? []).filter { child in
            !marks.contains { $0 === child as AnyObject } && !numerals.contains { $0 === child as AnyObject }
        }
        return children + numerals + bookmarks + marks
    }

    /// The Headings rotor: the book's title (on chapter 1), the chapter's opening and its section headings.
    override func accessibilityCustomRotors() -> [NSAccessibilityCustomRotor] {
        guard let rotor = columnDelegate?.headingsRotor else { return super.accessibilityCustomRotors() }
        return super.accessibilityCustomRotors() + [rotor]
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        columnDelegate?.menu(for: event) ?? super.menu(for: event)
    }

    /// The system draws a TextKit 2 selection in a view of its own inside the text view, filled
    /// to the container's edges on every line whose break is selected, and in its quieter colour
    /// it ignores `selectedTextAttributes`. That view stays (it still answers for the selection's
    /// geometry) but draws nothing; the controller fills the selection behind its words. It shows
    /// and hides itself, so its alpha is what is set, and again if it is ever made anew.
    func hideSystemSelectionFill() {
        for subview in subviews where Self.isSystemSelectionView(subview) { subview.alphaValue = 0 }
    }

    override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)
        if Self.isSystemSelectionView(subview) { subview.alphaValue = 0 }
    }

    private static func isSystemSelectionView(_ view: NSView) -> Bool {
        NSStringFromClass(type(of: view)) == "_NSTextSelectionView"
    }

    /// The selection's colour follows the keyboard (`updateSelectionEmphasis`).
    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { columnDelegate?.updateSelectionEmphasis(focused: true) }
        return became
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { columnDelegate?.updateSelectionEmphasis(focused: false) }
        return resigned
    }

    /// A focus request made before the view had a window settles once it has one.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { columnDelegate?.resolveFocus() }
    }

    /// The reader's single keys (`ShortcutCatalog`), while this view has keyboard focus; any other
    /// key, or one the controller leaves, goes to `NSTextView`. A held key repeats only where
    /// repeating means moving (J, K, ⇧J, ⇧K, the arrows); a held colour, 0, N or B acts once and
    /// its repeats are swallowed.
    override func keyDown(with event: NSEvent) {
        if let stroke = ReaderKeyStroke(event: event), let action = ShortcutCatalog.readerAction(for: stroke) {
            if event.isARepeat, action.actsOnMarkup { return }
            if columnDelegate?.perform(action) == true { return }
        }
        super.keyDown(with: event)
    }

    /// While a drag is under way `NSTextView` sets the selection on every move "still selecting",
    /// and posts no selection notification until the mouse-up; the fill follows it from here.
    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        if stillSelecting { columnDelegate?.refreshSelectionFill() }
    }

    /// `event` with Shift lifted, all else kept.
    static func withoutShift(_ event: NSEvent) -> NSEvent {
        NSEvent.mouseEvent(with: event.type, location: event.locationInWindow, modifierFlags: event.modifierFlags.subtracting(.shift),
                           timestamp: event.timestamp, windowNumber: event.windowNumber, context: nil, eventNumber: event.eventNumber,
                           clickCount: event.clickCount, pressure: event.pressure) ?? event
    }

    /// `NSTextView` tracks a drag inside `mouseDown` and returns on mouse-up, so the selection
    /// then says whether it was a click or a drag.
    /// After a click away nothing is left to extend, so a Shift-click is a plain click.
    override func mouseDown(with event: NSEvent) {
        let extends = columnDelegate?.shiftClickExtends ?? true
        let event = !extends && event.modifierFlags.contains(.shift) ? Self.withoutShift(event) : event
        super.mouseDown(with: event)
        columnDelegate?.clickEnded(at: convert(event.locationInWindow, from: nil), clickCount: event.clickCount)
    }
}
#endif
