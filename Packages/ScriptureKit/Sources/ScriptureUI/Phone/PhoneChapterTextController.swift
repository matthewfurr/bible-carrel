#if os(iOS)
import ScriptureData
import SwiftUI
import UIKit

/// The phone's counterpart of `ChapterTextController`: owns the TextKit 2 `UITextView` that shows
/// one chapter (a `BookLayout` of one section), and is itself the scroll view the bars follow. It
/// replaces the text when the layout changes, scrolls to a requested verse once its chapter is
/// laid out, reports the reading position (the first visible verse, as a `VerseLocation`) and the
/// running head's state as the reader scrolls, draws markup (highlight fills in views behind the
/// text, underlines as storage attributes, the focused highlight's outline, the margin marks in
/// the right margin, a chapter-note mark on the opening line) and carries the chapter's footer
/// links below the text, scrolling with it.
///
/// As on the Mac the whole chapter is laid out before any scroll. While a scroll target is pending
/// (its chapter not yet shown, or the view not yet in a window with a size) no reading position
/// is reported, so nothing transient is ever saved.
///
/// Never touch `textView.layoutManager`: doing so silently switches the view to TextKit 1.
///
/// The book thumb (spec 4.4) is driven from here: a long press within `thumbEdgeZone` of the
/// text view's right edge, held `thumbHold`, then dragged, reported through `onThumb`. The
/// system scroll indicator is hidden, since the thumb takes its place at that edge.
@MainActor
public final class PhoneChapterTextController: NSObject, UITextViewDelegate {
    /// The reader's side margins on the phone (DESIGN.md › iPhone), in place of the Mac's `xxl`.
    static let sideInset: CGFloat = AppSpacing.lg
    /// Above the text, and below it above the footer.
    static let verticalInset: CGFloat = AppSpacing.xl
    /// Space kept above the target verse's line when scrolling to it.
    static let scrollLeadIn: CGFloat = 8
    /// The air a later chapter keeps above its first line, beyond the page's inset: room for its
    /// chapter-note mark, which sits there at the column's trailing edge. (It was 2.4 × the size
    /// and a label; Matt, 2026-11-13: "the massive gap".) The least of it; at large text sizes
    /// it grows with the mark (`laterChapterAir(for:)`).
    static let laterChapterAir: CGFloat = AppSpacing.md

    /// The air above a later chapter at `traits`' text size: enough for the chapter-note mark,
    /// `xs` above the first line, to sit inside the page, and never less than `laterChapterAir`.
    /// (It was a fixed 16 pt while the mark grew with Dynamic Type; parked 2026-11-13.)
    static func laterChapterAir(for traits: UITraitCollection) -> CGFloat {
        let mark = ChapterNoteMarkButton.paperSize(for: traits).height
        return max(laterChapterAir, ceil(AppSpacing.xs + mark - verticalInset))
    }
    /// The outline is the fill's own rects outset by this much on every side.
    static let outlineMargin: CGFloat = 2
    static let outlineWidth: CGFloat = 1.5
    /// Highlight fills keep their own 2 pt radius and the outline 4 pt, so the two stay concentric.
    static let fillRadius: CGFloat = 2
    static let outlineRadius: CGFloat = 4

    /// One painted background rect: a highlight's rect on one line, or the blended overlap of two.
    struct HighlightFill: Equatable {
        let id: UUID?
        let rect: CGRect
        let color: UIColor
    }

    public let textView: UITextView
    /// The text view in its holder, which lists the marks and the footer for VoiceOver.
    let pageView: ReaderPageView
    /// The reading position: the first visible verse, reported when it changes.
    var onReadingPositionChange: (VerseLocation) -> Void
    /// The running head's state (the bar's title and progress line), reported when its chapter
    /// changes or its progress or opacity has moved at least `ReadingProgress.step` (or reached an end).
    var onRunningHeadChange: (RunningHeadState) -> Void = { _ in }
    /// How far the page has scrolled since the last jump landed, in lines of body text (signed),
    /// for `NavigationModel.reportLinesScrolledSinceJump`. Reported on every scroll the reader makes.
    var onScrollSinceJump: (Double, ScrollTarget) -> Void = { _, _ in }
    var onSelectionChange: (SelectionReport?) -> Void = { _ in }
    /// The selection went away with its text (another chapter, translation or book took its
    /// place), reported on the next turn of the main queue (`reportDroppedSelection`).
    var onSelectionDropped: () -> Void = {}
    var onMarginMarkTap: (MarginMark) -> Void = { _ in }
    /// The markup menu for a selection, or nil for none (the system's Look Up and Translate stay).
    var menuProvider: (SelectionReport) -> UIMenu? = { _ in nil }
    /// A tap inside a highlight selected its range: outline it.
    var onHighlightTap: (UUID) -> Void = { _ in }
    /// The note on a highlight, if it has one: a tap on that highlight (pen off) opens the note to
    /// read (`onOpenNote`) instead of selecting it under the edit bar (spec 3.1).
    var noteForHighlight: (UUID) -> UUID? = { _ in nil }
    var onOpenNote: (UUID) -> Void = { _ in }
    /// The scene's undo manager, which the markup registers its deletes with. The text view
    /// answers with it in place of its own, so shake to undo and the three-finger swipe reach them.
    var sceneUndoManager: UndoManager?
    /// Where the text view's Copy writes (a test's own pasteboard, else the general one).
    var pasteboard: UIPasteboard = .general
    /// Reduce Motion: the opening's hand-over to the bar title is a cut (`RunningHead.cut`).
    var reducesMotion: () -> Bool = { UIAccessibility.isReduceMotionEnabled }
    /// The navigation bar's bottom, as a distance below the text view's top edge: the reading
    /// position is the first fully visible line below it, a jump lands its line `scrollLeadIn`
    /// below it, and that line (`headLine`) is where the head names the chapter. Nil takes the
    /// text view's adjusted top inset, which is the bars' bottom when the text runs under them.
    var headLineY: CGFloat? {
        didSet {
            guard headLineY != oldValue else { return }
            updateRunningHead()
        }
    }
    /// The chapter's number of chapter notes (notes on the chapter, not a verse), by chapter; a
    /// chapter with any carries a `ChapterNoteMark` at the trailing end of its opening line.
    var chapterNoteCounts: [Int: Int] = [:] {
        didSet {
            guard chapterNoteCounts != oldValue else { return }
            refreshChapterNoteMarks()
            placeMarkButtons()
        }
    }
    /// A tap on a chapter's note mark, with its chapter.
    var onShowChapterNotes: (Int) -> Void = { _ in }
    /// The mark on the opening line, by chapter (`refreshChapterNoteMarks` keeps it).
    var chapterNoteMarkViews: [Int: ChapterNoteMarkButton] = [:]
    /// Lectern's drop numeral, laid over the text where the chapter's notch is; nil in the other
    /// styles. Remade only when the chapter it names changes.
    private(set) var numeralView: DropNumeralView?
    /// Hands TextKit the fragments that cut Lectern's notches (set while a Lectern layout shows).
    private let dropZoneDelegate = DropZoneLayoutDelegate()
    /// The headings rotor's stops for the current text.
    private(set) var headingItems: [BookHeadingItem] = []
    /// The running head's state at the current scroll, or nil before the first layout lands.
    public private(set) var runningHead: RunningHeadState?
    /// The chapter's place in the text view; rebuilt whenever the text reflows.
    private(set) var chapterBand: ChapterBand?
    private(set) var layout: BookLayout?
    private(set) var appliedDecorations: BookDecorations = .none
    /// The alpha the page opening's chapter label is drawn with (`1 − headOpacity`).
    private(set) var openingLabelAlpha: CGFloat = 1
    /// The rects the chapter's highlight fills are painted with, in text-view coordinates.
    private(set) var backgroundFills: [HighlightFill] = []
    /// The margin marks' buttons, in `appliedMarks` order.
    private(set) var markButtons: [MarginMarkButton] = []
    /// The selection's fill, in place of the system's (`installSelectionHighlight`).
    let selectionHighlightView = ReaderSelectionHighlightView()
    /// The selection's fill as last painted, in text-view coordinates: the system's line rects,
    /// each trimmed to its line's words (`trim(_:to:)`). Empty with no ranged selection.
    private(set) var selectionFills: [CGRect] = []

    /// A place the controller still has to scroll to: a jump's target, or the verse being read
    /// when the text reflowed or was replaced without a new target.
    private enum Pending {
        case target(ScrollTarget)
        case position(VerseLocation)
    }

    /// An underline in the text storage.
    private struct Underline: Equatable {
        let range: NSRange
        let style: NSUnderlineStyle
    }

    /// Behind the text: one view per fill. In front of it: the outline and the margin marks.
    private let fillsView = PassiveView()
    private let outlineView = PassiveView()
    private var footer: UIView?

    private var appliedTypography: ReaderTypography?
    private var appliedScrollTarget: ScrollTarget?
    private var appliedMarks: [MarginMark] = []
    private var pending: Pending?
    /// The underlines currently in the text storage.
    private var underlines: [Underline] = []
    private var lastReportedPosition: VerseLocation?
    /// The first visible verse as measured, before `ReadingPositionRule` adjusts it.
    private var lastFirstVisible: VerseLocation?
    /// The verse the last jump or restore landed on, while it is still the first visible: a
    /// combined verse ("14-15") then reports the verse asked for, not its first number.
    private var landedVerse: VerseLocation?
    private var lastReportedHead: RunningHeadState?
    /// Verse numbers drawn in the on-mark color, and the title block's label at its fade: the
    /// foreground colors the text carries as rendering attributes. TextKit asks for them again
    /// through the layout manager's validator (`validateRenderingColors`).
    private var numberColors: [(range: NSRange, color: UIColor)] = []
    private var labelFadeColors: [(range: NSRange, color: UIColor)] = []
    /// The page opening's chapter label runs, with their own color, for the fade into the head.
    private var openingLabelRuns: [(range: NSRange, color: UIColor)] = []
    /// The content offset where the last jump landed; nil while one is pending or being made.
    private var jumpLandedY: CGFloat?
    /// The chapter shown is a later one, with air above its opening for its chapter-note mark
    /// (`laterChapterAir(for:)`), kept in the text's top inset because TextKit 2 drops a
    /// paragraph's space before at the start of the text.
    private var opensLater = false
    private var isReplacingText = false
    /// The content height the controller last gave the text view.
    private(set) var contentHeight: CGFloat = 0
    /// Set while the controller itself sets the selection, so the change is not snapped again.
    private var isSettingSelection = false
    /// Presents the markup menu at a tapped highlight, where the text view's own menu does not appear.
    private lazy var highlightMenu = UIEditMenuInteraction(delegate: self)
    /// A tap on a highlight; it begins only there, and the text view's own taps wait for it to fail.
    private let highlightTap = UITapGestureRecognizer()
    /// A tap on a verse's lines selects the verse; it begins only there, and the text view's own
    /// single taps wait for it to fail.
    private let verseTap = UITapGestureRecognizer()
    /// The page's state as the verse tap's current touch came down (`verseTapTouch(tapCount:)`);
    /// nil for a touch it refused (on a handle or a control).
    private var verseTapTouchState: VerseTapTouch?
    /// Whether VoiceOver is running, when a tap is never a verse tap.
    var isVoiceOverRunning: () -> Bool = { UIAccessibility.isVoiceOverRunning }
    /// How many times the edit menu has been presented at a selection (a highlight's or a verse's).
    private(set) var menuPresentations = 0
    /// Any tap, alongside the text view's own.
    private let awayTap = UITapGestureRecognizer()
    /// While the chapter switcher is open, a flick anywhere on the page is the cards' (Matt,
    /// 2026-11-13): this pan takes it, and the page's own pan does not begin.
    private let switcherPan = UIPanGestureRecognizer()
    /// The width, top inset and size the geometry was last set for, and the footer's height.
    private var settledWidth: CGFloat = 0
    private var settledTopInset: CGFloat?
    private var settledSize: CGSize = .zero
    private var footerHeight: CGFloat = 0
    private var needsAccessoryMeasure = true

    // MARK: Pen state

    /// The pen paints a finished stroke's report (nil when it covered no word).
    var onPaint: (SelectionReport?) -> Void = { _ in }
    /// The pen selects a tapped mark, or nil for a tap away from every mark.
    var onPenSelect: (UUID?) -> Void = { _ in }
    /// A handle drag ended on these words.
    var onResize: (SelectionReport?) -> Void = { _ in }
    /// The menu under the selected mark.
    var penMenuProvider: (UUID, SelectionReport) -> UIMenu? = { _, _ in nil }
    /// Whether a mark is drawn on its own words (made in this translation), so it has handles.
    var canResize: (UUID) -> Bool = { _ in true }
    private(set) var isPenOn = false
    private var penColor: UIColor = .clear
    private var penSelectedID: UUID?
    private let paintGesture = PhonePaintGesture()
    private let startHandle = PenHandleView(end: .start)
    private let endHandle = PenHandleView(end: .end)
    /// The stroke under the finger, in front of the fills and behind the text.
    private let liveView = PassiveView()
    private var stroke: PenStroke?
    /// The selected mark's fills are hidden while a handle drags it, so the live stroke shows its new extent.
    private var suppressedFillID: UUID?
    /// The menu goes under the selected mark once the mark is drawn.
    private var pendingPenMenu = false
    private let paintHaptic = UIImpactFeedbackGenerator(style: .light)
    /// The system magnifier over the finger while a stroke paints or a handle drags.
    private var loupe: UITextLoupeSession?
    /// Where the touch the paint gesture is following began (text-view coordinates).
    private var paintTouchStart: CGPoint?

    // MARK: The book thumb

    /// How far in from the text view's right edge a long press opens the thumb (call): the
    /// margin the marks sit in and a little of the column's edge.
    static let thumbEdgeZone: CGFloat = 28
    /// How long the press is held before the thumb opens; a tap (a margin mark's) ends sooner.
    static let thumbHold: TimeInterval = 0.3
    /// The thumb's press: began, moved and ended with its height in the page's coordinates
    /// (`pageView`), or cancelled.
    var onThumb: (ThumbGesture) -> Void = { _ in }
    private let thumbPress = UILongPressGestureRecognizer()
    /// Where the touch the thumb's press is following began, when that was in the edge zone;
    /// nil for a touch it does not take. Set for every touch the text view sees.
    private var thumbTouchStart: CGPoint?
    /// Whether a press in the zone has begun and not yet ended.
    private var isThumbPressed = false
    /// Whether the touch going on now (or the last one) was the thumb's: the away tap, which
    /// runs alongside everything, does not also act on its lift.
    private(set) var thumbClaimedTouch = false
    /// While the thumb is pressed its ruler lies along the right margin, where the margin marks
    /// and the chapter-note mark are: they stand aside until it lifts (Matt, 2026-11-13: the
    /// ruler ran over them).
    private(set) var thumbHidesMarks = false

    // MARK: The chapter switcher

    /// The switcher's state, which this controller writes as the scroll goes and its cards read
    /// (`ChapterSwitcherModel`). The screen's; without it there is no switcher.
    var switcher: ChapterSwitcherModel? {
        didSet {
            guard switcher !== oldValue else { return }
            oldValue?.closeOnPage = { _ in }
            switcher?.closeOnPage = { [weak self] in self?.closeSwitcher(animated: $0) }
        }
    }
    /// The gap between the page and the switcher's cards, and between the cards and the bars.
    static let switcherGap: CGFloat = AppSpacing.md
    /// The cards (`ChapterSwitcherDeckView`, hosted), kept in the text view just past the end
    /// being pulled; hidden unless a pull or the open switcher shows them.
    private var switcherView: UIView?
    private var switcherHeight: CGFloat = 0
    /// The end the switcher is open at: the page rests with the cards in view, in room added to
    /// the scroll (`contentInset`) at that end.
    private(set) var openSwitcherEdge: ChapterSwitcher.Edge?
    /// The end whose cards a pull under way is bringing in.
    private(set) var pulledSwitcherEdge: ChapterSwitcher.Edge?
    /// The room the open switcher has added to the scroll's own insets, at its end.
    private(set) var switcherInsets = UIEdgeInsets.zero
    /// A pull let go past its threshold: the switcher opens once the drag has ended.
    private var pendingSwitcherOpen: (edge: ChapterSwitcher.Edge, opening: ChapterSwitcher.Opening)?
    /// The page's speed as the finger lifted, in points per second (positive toward its foot).
    private var liftVelocity: CGFloat = 0
    /// The column's leading inset and width as last laid out, for the cards' frame.
    private var settledColumn: (side: CGFloat, width: CGFloat) = (0, 0)
    /// The scroll's clock, for its speed between ticks (a test steps its own).
    var scrollClock: () -> CFTimeInterval = { CACurrentMediaTime() }
    /// The scroll's drag and coast as the switcher follows them.
    private var switcherTracker = ChapterSwitcherTracker()

    init(onReadingPositionChange: @escaping (VerseLocation) -> Void = { _ in }) {
        self.onReadingPositionChange = onReadingPositionChange

        let contentStorage = NSTextContentStorage()
        let layoutManager = NSTextLayoutManager()
        contentStorage.addTextLayoutManager(layoutManager)
        let container = DropZoneContainer(size: CGSize(width: ReaderTypography.default.measure, height: .greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        layoutManager.textContainer = container

        let textView = ReaderTextView(frame: .zero, textContainer: container)
        textView.isEditable = false
        textView.isSelectable = true
        textView.dataDetectorTypes = []
        // Scripture is read, not rewritten: no Writing Tools or other system intelligence items in its menus.
        textView.writingToolsBehavior = .none
        textView.backgroundColor = Palette.paperPage.platformColor
        textView.alwaysBounceVertical = true
        // The book thumb takes the scroll indicator's place at the right edge.
        textView.showsVerticalScrollIndicator = false
        textView.contentInsetAdjustmentBehavior = .automatic
        textView.textContainerInset = UIEdgeInsets(top: Self.verticalInset, left: Self.sideInset,
                                                   bottom: Self.verticalInset, right: Self.sideInset)
        self.textView = textView
        pageView = ReaderPageView(textView: textView)
        super.init()
        pageView.accessories = { [weak self] in
            guard let self else { return ([], nil) }
            return (markButtons + Array(chapterNoteMarkViews.values) + [numeralView].compactMap { $0 }, footer)
        }

        textView.delegate = self
        textView.readerDelegate = self
        if let layoutManager = textView.textLayoutManager {
            // After the text view's own validator, if it has one. UIKit validates on the main
            // thread; should it ever not, the recolour (cosmetic: the opening label's fade and
            // verse numbers on marks) is skipped rather than trapping in `assumeIsolated`.
            let system = layoutManager.renderingAttributesValidator
            layoutManager.renderingAttributesValidator = { [weak self] manager, fragment in
                system?(manager, fragment)
                guard Thread.isMainThread else { return }
                MainActor.assumeIsolated { self?.validateRenderingColors(of: fragment, in: manager) }
            }
        }
        textView.accessibilityCustomRotors = [makeHeadingsRotor()]
        selectionHighlightView.fill = { [weak self] lines in self?.selectionFill(for: lines) ?? [] }
        installSelectionHighlight()
        fillsView.layer.zPosition = -1
        textView.insertSubview(fillsView, at: 0)
        textView.addSubview(outlineView)
        textView.addInteraction(highlightMenu)
        highlightTap.addTarget(self, action: #selector(handleHighlightTap(_:)))
        highlightTap.delegate = self
        textView.addGestureRecognizer(highlightTap)
        verseTap.addTarget(self, action: #selector(handleVerseTap(_:)))
        verseTap.delegate = self
        textView.addGestureRecognizer(verseTap)
        awayTap.addTarget(self, action: #selector(handleAwayTap(_:)))
        awayTap.delegate = self
        textView.addGestureRecognizer(awayTap)
        liveView.layer.zPosition = -1
        textView.insertSubview(liveView, aboveSubview: fillsView)
        paintGesture.addTarget(self, action: #selector(handlePaint(_:)))
        paintGesture.delegate = self
        paintGesture.isEnabled = false
        textView.addGestureRecognizer(paintGesture)
        switcherPan.addTarget(self, action: #selector(handleSwitcherPan(_:)))
        switcherPan.delegate = self
        switcherPan.maximumNumberOfTouches = 1
        textView.addGestureRecognizer(switcherPan)
        thumbPress.minimumPressDuration = Self.thumbHold
        thumbPress.addTarget(self, action: #selector(handleThumbPress(_:)))
        thumbPress.delegate = self
        textView.addGestureRecognizer(thumbPress)
        for handle in [startHandle, endHandle] {
            handle.press.addTarget(self, action: #selector(handleHandleDrag(_:)))
            textView.addSubview(handle)
        }
        // Fills resolve their dynamic colors themselves; the outline's border and the marks' tint
        // are layer colors and are set again when the appearance changes, Sepia included. Dynamic
        // Type resizes the footer and the marks.
        let appearanceTraits: [UITrait] = [UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self, SepiaTrait.self]
        textView.registerForTraitChanges(appearanceTraits) { [weak self] (_: UITextView, _) in
            self?.refreshOverlays()
        }
        textView.registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { [weak self] (view: UITextView, _) in
            self?.needsAccessoryMeasure = true
            view.setNeedsLayout()
        }
    }

    /// The single entry point: a layout, the typography it was built with (whose measure sets the
    /// column), its decorations, the margin marks and a scroll request are applied together, so
    /// the first position reported after a change is the requested one, never a transient one.
    ///
    /// The text is replaced only when `layout.id` changes. A replacement without a new target
    /// returns to the verse being read; a new target is scrolled to once its chapter is shown
    /// (showing it is the document's job). Decoration-only changes (user actions) keep the scroll
    /// position.
    func update(layout newLayout: BookLayout?, typography: ReaderTypography, scrollTarget: ScrollTarget?,
                decorations newDecorations: BookDecorations, marginMarks: [MarginMark], footer: UIView?) {
        setFooter(footer)
        let textChanged = newLayout?.id != layout?.id
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
            if !textChanged, pending == nil, let position = lastReportedPosition, position == lastFirstVisible,
               !scrollTarget.atEnd, position.book == newLayout?.id.book, position.chapter == scrollTarget.chapter, position.verse == scrollTarget.verse {
                // A target for the verse already at the top is already met (a return to the Read
                // tab resumes there); scrolling would snap a part-read verse back. It lands here.
                // Only when that verse is the one measured at the top: a position the rule moved
                // (a landing inside a combined verse) is not where the page is.
                jumpLandedY = textView.contentOffset.y
            } else {
                pending = .target(scrollTarget)
                landedVerse = nil
                jumpLandedY = nil
            }
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
            if replaceText(newLayout, typography: typography, decorations: decorations) {
                reportSelectionAfterReplacement()
            }
        } else {
            if measureChanged, newLayout != nil {
                applyGeometry(force: true)
                if pending == nil, let position = lastReportedPosition { pending = .position(position) }
            }
            if decorations != appliedDecorations {
                outlineChanged = decorations.outlinedID != appliedDecorations.outlinedID
                appliedDecorations = decorations
                applyDecorationChange()
            }
        }
        // A finished stroke stays drawn until the markup it made arrives (the first update after
        // it, since the markup changes at once), so it never flickers off.
        if stroke?.isFinished == true { clearStroke() }
        if marginMarks != appliedMarks {
            appliedMarks = marginMarks
            rebuildMarkButtons()
            placeMarkButtons()
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
        presentPendingPenMenu()
    }

    /// A newly outlined highlight with no part on screen (a row chosen in Notes in This Chapter)
    /// is scrolled to, its first line just below the head's line. One already showing (a tap
    /// inside it) keeps the scroll, and a pending scroll (a load or translation switch) wins.
    private func scrollToHighlight(_ range: NSRange) {
        guard pending == nil else { return }
        let segments = segmentFrames(of: [range])[0]
        let visible = visiblePage
        guard let first = segments.first, !segments.contains(where: { $0.intersects(visible) }) else { return }
        // The page lands here: this scroll is not reading on.
        jumpLandedY = nil
        // The highlight's verse is where the page now rests, not an earlier jump's.
        landedVerse = layout?.span(containing: range.location)?.location
        scroll(toY: first.minY - Self.outlineMargin - Self.scrollLeadIn - barBottom)
        jumpLandedY = textView.contentOffset.y
    }

    /// Where the reader's selection menu goes: `target`, the rect it is kept clear of, and the
    /// side it opens to (`.down`, an arrow pointing down at the selection: the menu above it;
    /// `.up`: below it).
    struct MenuPlacement: Equatable {
        var target: CGRect
        var arrow: UIEditMenuArrowDirection
    }

    /// The menu's place for a selection painted on `lines` (text-view coordinates), with
    /// `visible` the page between the bars and `room` the height the menu needs beside it.
    /// It is placed against the whole selection's bounds, the part in view: directly above its
    /// first line when there is room under the top bar, else directly below its last line.
    /// With room on neither side (a passage taller than the page, or both ends off screen) it
    /// goes above the visible part, at the page's top edge over the bar (call: the bar, not the
    /// words). A selection wholly out of view keeps its bounds and the system's choice; no lines,
    /// no menu.
    static func menuPlacement(for lines: [CGRect], in visible: CGRect, room: CGFloat) -> MenuPlacement? {
        let bounds = lines.reduce(CGRect.null) { $0.union($1) }
        guard !bounds.isNull else { return nil }
        let part = bounds.intersection(visible)
        guard !part.isNull, part.height > 0 else { return MenuPlacement(target: bounds, arrow: .automatic) }
        if part.minY - visible.minY < room, visible.maxY - part.maxY >= room {
            return MenuPlacement(target: part, arrow: .up)
        }
        return MenuPlacement(target: part, arrow: .down)
    }

    /// The height the menu needs beside a selection: the edit menu's bar and the gap the system
    /// keeps, with the text size (call: measured from the bar on iOS 27, 46 pt at the default size).
    private var menuRoom: CGFloat {
        UIFontMetrics(forTextStyle: .body).scaledValue(for: 56, compatibleWith: textView.traitCollection)
    }

    /// `range`'s menu place on the page as it is now.
    private func menuPlacement(for range: NSRange) -> MenuPlacement? {
        Self.menuPlacement(for: segmentFrames(of: [range])[0], in: visiblePage, room: menuRoom)
    }

    /// The configuration the reader's own menu was last presented with.
    private(set) var presentedMenuConfiguration: UIEditMenuConfiguration?

    /// The page in view between the bars, in text-view coordinates.
    var visiblePage: CGRect {
        CGRect(x: 0, y: textView.contentOffset.y + barBottom, width: textView.bounds.width,
               height: textView.bounds.height - barBottom - pageInsetBottom)
    }

    /// The first line's rect of `range` in text-view coordinates, for menus and handles.
    func rect(for range: NSRange) -> CGRect? {
        segmentFrames(of: [range])[0].first
    }

    // MARK: - Text and geometry

    private var contentStorage: NSTextContentStorage? {
        textView.textLayoutManager?.textContentManager as? NSTextContentStorage
    }

    /// The bars' bottom below the text view's top edge.
    private var barBottom: CGFloat {
        headLineY ?? pageInsetTop
    }

    /// The bars' insets alone: the scroll's, without the room the chapter switcher adds to them
    /// while it is open (`switcherInsets`).
    private var pageInsetTop: CGFloat { textView.adjustedContentInset.top - switcherInsets.top }
    private var pageInsetBottom: CGFloat { textView.adjustedContentInset.bottom - switcherInsets.bottom }

    /// Sets the chapter's text with its underlines already in it and lays the whole chapter out.
    /// A selection never carries into other text: the same string keeps its range; the same
    /// chapter laid out in another style (whose openings and verse numbers move the verses'
    /// offsets) keeps it on the same words, carried by verse and offset as highlights are; any
    /// other text (another chapter, translation or book) clears it. Whether there was a selection
    /// is read before the text is swapped, since UIKit clamps the range to a shorter text.
    /// Returns whether the selection changed (moved or cleared), for the caller to report once
    /// the replacement is over (`reportSelectionAfterReplacement`).
    private func replaceText(_ layout: BookLayout?, typography: ReaderTypography, decorations: BookDecorations) -> Bool {
        let previous = self.layout
        let selected = textView.selectedRange
        let hadSelection = selected.location != NSNotFound && selected.length > 0
        self.layout = layout
        lastReportedPosition = nil
        lastFirstVisible = nil
        lastReportedHead = nil
        runningHead = nil
        // Another chapter names other links, which may take another height.
        needsAccessoryMeasure = true
        opensLater = !(layout?.opensWithTitleBlock ?? true)
        numberColors = []
        labelFadeColors = []
        openingLabelAlpha = 1
        isReplacingText = true
        defer { isReplacingText = false }

        let text = (layout?.attributedString.mutableCopy() as? NSMutableAttributedString) ?? NSMutableAttributedString()
        let underlines = Self.underlines(in: decorations).filter { NSMaxRange($0.range) <= text.length }
        for underline in underlines {
            text.addAttributes(Self.underlineAttributes(underline), range: underline.range)
        }
        self.underlines = underlines
        openingLabelRuns = Self.openingLabelRuns(in: layout)
        headingItems = BookHeadings.items(in: layout)
        // Lectern's notches need fragments of their own; every other style keeps TextKit's.
        textView.textLayoutManager?.delegate = typography.style == .lectern ? dropZoneDelegate : nil
        let sameText = contentStorage?.textStorage?.string == text.string
        contentStorage?.performEditingTransaction {
            contentStorage?.textStorage?.setAttributedString(text)
        }
        var selectionChanged = false
        if hadSelection, !sameText {
            textView.selectedRange = Self.carried(selected, from: previous, to: layout) ?? NSRange(location: 0, length: 0)
            highlightMenu.dismissMenu()
            selectionChanged = true
        }
        // Rendering attributes (on-mark numbers, the label's fade) belong to the old text.
        if let layoutManager = textView.textLayoutManager {
            layoutManager.removeRenderingAttribute(.foregroundColor, for: layoutManager.documentRange)
        }
        // Another chapter: the switcher that brought it, or any other, is gone.
        closeSwitcher(animated: false)
        applyGeometry(force: true)
        switcherTracker.pageMoved()
        textView.setContentOffset(CGPoint(x: 0, y: minOffsetY), animated: false)
        return selectionChanged
    }

    /// `range` in `previous` moved to the same words in `layout` when both are the same chapters
    /// of the same book and translation (another page style), by verse and offset within the
    /// verse's text; nil for other text, or a range that covers no verse text.
    static func carried(_ range: NSRange, from previous: BookLayout?, to layout: BookLayout?) -> NSRange? {
        guard let previous, let layout, previous.id.book == layout.id.book, previous.id.translationID == layout.id.translationID,
              previous.id.chapters == layout.id.chapters,
              let selection = ReaderTextLogic.report(for: range, layout: previous, decorations: .none)?.selection,
              let start = layout.span(for: VerseLocation(book: selection.book, chapter: selection.chapter, verse: selection.verse)),
              let end = layout.span(for: VerseLocation(book: selection.book, chapter: selection.chapter, verse: selection.endVerse))
        else { return nil }
        let from = start.textRange.location + min(max(selection.startOffset, 0), start.textRange.length)
        let to = end.textRange.location + min(max(selection.endOffset, 0), end.textRange.length)
        return to > from ? NSRange(location: from, length: to - from) : nil
    }

    /// After a replacement changed the selection, the screen is told on the next turn of the main
    /// queue: the replacement runs inside a SwiftUI update, where the model must not change (as
    /// the running head's reports are deferred). What is selected then is reported, so a
    /// selection made since is never undone by a stale word; with none, the selection went away
    /// with its text (`onSelectionDropped`), which keeps an outline a jump has set.
    private func reportSelectionAfterReplacement() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let range = textView.selectedRange
            if range.location != NSNotFound, range.length > 0 {
                onSelectionChange(report(for: range))
            } else {
                onSelectionDropped()
            }
        }
    }

    /// The runs of the page's chapter label (the title block's CHAPTER 1, or a later chapter's
    /// label; Lectern's hairline has none), which fade as the bar's title fades in.
    private static func openingLabelRuns(in layout: BookLayout?) -> [(range: NSRange, color: UIColor)] {
        guard let layout, let first = layout.sections.first, first.openingRange.length > 0 else { return [] }
        var runs: [(range: NSRange, color: UIColor)] = []
        let label = ReaderRole.chapterLabel(first.location.chapter)
        layout.attributedString.enumerateAttributes(in: first.openingRange) { attributes, range, _ in
            guard (attributes[.readerRole] as? ReaderRoleBox)?.role == label else { return }
            runs.append((range, attributes[.foregroundColor] as? UIColor ?? Palette.inkSecondary.platformColor))
        }
        return runs
    }

    /// Sizes the column to the measure (or the width less the side insets, when narrower), centres
    /// it, keeps a later chapter's air above the text and the footer's room below it, lays the
    /// chapter out and places everything drawn from its geometry. Cheap when nothing changed: the
    /// text view lays itself out on every scroll frame.
    private func applyGeometry(force: Bool = false) {
        let width = textView.bounds.width
        guard width > 0 else { return }
        let measure = appliedTypography?.measure ?? ReaderTypography.default.measure
        let column = min(measure, max(0, width - 2 * Self.sideInset))
        let side = max(Self.sideInset, ((width - column) / 2).rounded(.down))
        let widthChanged = width != settledWidth
        if widthChanged || needsAccessoryMeasure {
            needsAccessoryMeasure = false
            footerHeight = footer.map { ceil($0.sizeThatFits(CGSize(width: column, height: .greatestFiniteMagnitude)).height) } ?? 0
            switcherHeight = switcherView.map { ceil($0.sizeThatFits(CGSize(width: column, height: .greatestFiniteMagnitude)).height) } ?? 0
        }
        if widthChanged, settledWidth > 0 {
            // Rotation or any other new width: the switcher closes.
            closeSwitcher(animated: false)
        }
        settledColumn = (side, column)
        let airAbove = opensLater ? Self.laterChapterAir(for: textView.traitCollection) : 0
        let insets = UIEdgeInsets(top: Self.verticalInset + airAbove, left: side, bottom: Self.verticalInset + footerHeight, right: side)
        let insetsChanged = textView.textContainerInset != insets
        guard force || widthChanged || insetsChanged else { return }
        settledWidth = width
        if insetsChanged { textView.textContainerInset = insets }
        if let layoutManager = textView.textLayoutManager {
            // A Lectern chapter's later zone paragraphs take their notch from its first paragraph,
            // which the text view may not have laid out again yet at a new width (it lays out what
            // is on screen first): lay the chapter out afresh, top down.
            if widthChanged, layoutManager.delegate === dropZoneDelegate {
                layoutManager.invalidateLayout(for: layoutManager.documentRange)
            }
            layoutManager.ensureLayout(for: layoutManager.documentRange)
        }
        let textBottom = insets.top + (textView.textLayoutManager?.usageBoundsForTextContainer.maxY ?? 0)
        footer?.frame = CGRect(x: side, y: textBottom + Self.verticalInset, width: column, height: footerHeight)
        contentHeight = ceil(textBottom + insets.bottom)
        if abs(textView.contentSize.height - contentHeight) > 0.5 || textView.contentSize.width != width {
            textView.contentSize = CGSize(width: width, height: contentHeight)
        }
        rebuildBand()
        refreshOverlays()
        if let edge = openSwitcherEdge ?? pulledSwitcherEdge { placeSwitcher(at: edge) }
        // A new layout or a reflow changes how far the page can scroll without a scroll.
        updateRunningHead()
    }

    /// The text view laid itself out (a scroll, a rotation, the safe area arriving): keep the
    /// geometry current, and after a reflow or a change in the inset above the text, put the
    /// reader back on the verse they were reading.
    fileprivate func textViewDidLayout() {
        if fillsView.superview === textView, textView.subviews.first !== fillsView {
            textView.sendSubviewToBack(fillsView)
        }
        installSelectionHighlight()
        guard layout != nil else { return }
        let width = textView.bounds.width
        let top = pageInsetTop
        let reflowed = width != settledWidth || needsAccessoryMeasure
        let topMoved = textView.window != nil && settledTopInset != nil && settledTopInset != top
        let resized = textView.bounds.size != settledSize
        applyGeometry()
        if textView.window != nil { settledTopInset = top }
        settledSize = textView.bounds.size
        if reflowed || topMoved, pending == nil, let position = lastReportedPosition {
            pending = .position(position)
        }
        performPendingScroll()
        if resized || topMoved {
            // A taller or shorter page changes the head's place and the foot's without a scroll.
            updateRunningHead()
        }
    }

    /// The page's own top and foot as content offsets, without the chapter switcher's room.
    private var minOffsetY: CGFloat { -pageInsetTop }

    private var maxOffsetY: CGFloat {
        max(minOffsetY, textView.contentSize.height + pageInsetBottom - textView.bounds.height)
    }

    private func clampedScrollY(_ y: CGFloat) -> CGFloat {
        min(max(y, minOffsetY), maxOffsetY)
    }

    /// The controller's own scroll, held to the page's ends. It is not the reader's: the
    /// switcher's tracker forgets the end the page was stopped at, and any coast.
    private func scroll(toY y: CGFloat) {
        switcherTracker.pageMoved()
        textView.setContentOffset(CGPoint(x: 0, y: clampedScrollY(y)), animated: false)
    }

    /// Scrolls so the pending place's first line sits just below the head's line: a verse's
    /// number; verse 1 rests at the page's top, where the chapter's opening sits below the bar
    /// (whose title is hidden there) as chapter 1's title block does. A verse the chapter lacks
    /// clamps to its nearest end. A target waits for the layout of its chapter and for the view to
    /// be in a window with a size (so the bars' insets are known); a position in another chapter
    /// goes to the page's nearest end.
    private func performPendingScroll() {
        guard let pending, let layout, !layout.spans.isEmpty, !isReplacingText,
              textView.window != nil, textView.bounds.height > 0
        else { return }
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
              let last = section.spans.last
        else { return }
        applyGeometry()
        let index: Int
        if location.verse <= 1 {
            index = section.openingRange.location
        } else {
            let span = section.spans.first { $0.contains(verse: location.verse) }
                ?? (location.verse > last.location.verse ? last : section.spans.first { $0.location.verse >= location.verse } ?? last)
            index = span.fullRange.location
        }
        guard let line = lineFrame(forCharacterIndex: index) else { return }
        self.pending = nil
        landedVerse = location
        settledTopInset = pageInsetTop
        // The jump's own scroll is not reading on; the distance is measured from where it lands.
        jumpLandedY = nil
        let opensThePage = location.verse <= 1 && section.location.chapter == layout.sections.first?.location.chapter
        // A turn back lands with the chapter's foot (and its links) at the bottom.
        scroll(toY: atEnd ? maxOffsetY : opensThePage ? minOffsetY : line.minY + textView.textContainerInset.top - Self.scrollLeadIn - barBottom)
        jumpLandedY = textView.contentOffset.y
        reportReadingPosition()
        updateRunningHead()
    }

    /// The character index where the first fully visible line below the head's line starts.
    private func topLineStart() -> Int? {
        guard let layoutManager = textView.textLayoutManager, let contentStorage else { return nil }
        // Text-container coordinates: the bars' bottom, less the inset above the text.
        let visibleTop = textView.contentOffset.y + barBottom - textView.textContainerInset.top
        // A fragment is a whole paragraph, so look inside it line by line. The walk starts at the
        // fragment under the top edge (the chapter is laid out), not at the top of the text.
        let start = layoutManager.textLayoutFragment(for: CGPoint(x: 0, y: max(0, visibleTop)))?.rangeInElement.location
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
        guard !isReplacingText, pending == nil, textView.bounds.height > 0, let layout, !layout.spans.isEmpty,
              let lineStart = topLineStart(), let firstVisible = layout.firstVisibleVerse(fromLineStart: lineStart)
        else { return }
        lastFirstVisible = firstVisible
        // The landed verse (`ReadingPositionRule`), so the bar's title and the head never disagree.
        let (position, landed) = ReadingPositionRule.resolve(firstVisible: firstVisible, landed: landedVerse, layout: layout)
        landedVerse = landed
        guard position != lastReportedPosition else { return }
        lastReportedPosition = position
        onReadingPositionChange(position)
    }

    // MARK: - Running head

    /// The line just under the bars, in text-view coordinates: where a jump lands its line, and
    /// where the head names the chapter.
    private var headLine: CGFloat {
        textView.contentOffset.y + barBottom + Self.scrollLeadIn
    }

    /// The chapter's place in the text view, from its line fragments (`ChapterBand.band`).
    private func rebuildBand() {
        chapterBand = layout.flatMap { layout in
            ChapterBand.band(for: layout, inset: textView.textContainerInset.top) { lineFrame(forCharacterIndex: $0) }
        }
    }

    /// True when the page scrolls and is scrolled to its foot.
    private var isAtPageFoot: Bool {
        maxOffsetY > minOffsetY + 0.5 && textView.contentOffset.y >= maxOffsetY - 0.5
    }

    /// `RunningHead.state` at the current scroll, reported when it has moved. Every page opens as
    /// chapter 1 does: the bar's title is hidden at the page's top and fades in as the opening
    /// scrolls under the bar, the opening's chapter label fading out as it does; at the page's
    /// foot the chapter is read through.
    private func updateRunningHead() {
        guard !isReplacingText, pending == nil, let band = chapterBand, textView.bounds.height > 0 else { return }
        let state = RunningHead.state(band: band, headLineY: headLine + RunningHead.headLineTolerance,
                                      atFoot: isAtPageFoot, reducesMotion: reducesMotion(),
                                      topHeadLineY: minOffsetY + barBottom + Self.scrollLeadIn + RunningHead.headLineTolerance,
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

    /// Draws the page opening's chapter label at `alpha` through a rendering attribute, so the
    /// text and its layout are untouched; full alpha removes it.
    private func applyOpeningLabelAlpha(_ alpha: CGFloat, force: Bool = false) {
        let alpha = (min(max(alpha, 0), 1) * 100).rounded() / 100
        guard force || alpha != openingLabelAlpha else { return }
        openingLabelAlpha = alpha
        applyOpeningNoteMarkAlpha()
        labelFadeColors = alpha >= 1 ? [] : openingLabelRuns.map { run in
            let color = run.color
            return (run.range, UIColor { traits in
                let resolved = color.resolvedColor(with: traits)
                return resolved.withAlphaComponent(resolved.cgColor.alpha * alpha)
            })
        }
        setRenderingColors(in: openingLabelRuns.map(\.range))
    }

    // MARK: - Geometry

    /// The frame, in text-container coordinates, of the line holding `characterIndex`. The whole
    /// document is laid out once the geometry is applied.
    func lineFrame(forCharacterIndex characterIndex: Int) -> CGRect? {
        guard let layoutManager = textView.textLayoutManager, let contentStorage,
              let location = contentStorage.location(contentStorage.documentRange.location, offsetBy: characterIndex),
              let fragment = layoutManager.textLayoutFragment(for: location)
        else { return nil }
        let fragmentStart = contentStorage.offset(from: contentStorage.documentRange.location, to: fragment.rangeInElement.location)
        let line = fragment.textLineFragments.first { NSLocationInRange(characterIndex - fragmentStart, $0.characterRange) }
        let bounds = line?.typographicBounds ?? CGRect(origin: .zero, size: fragment.layoutFragmentFrame.size)
        return bounds.offsetBy(dx: fragment.layoutFragmentFrame.minX, dy: fragment.layoutFragmentFrame.minY)
    }

    private func textRange(for range: NSRange) -> NSTextRange? {
        guard let contentStorage,
              let start = contentStorage.location(contentStorage.documentRange.location, offsetBy: range.location),
              let end = contentStorage.location(start, offsetBy: range.length)
        else { return nil }
        return NSTextRange(location: start, end: end)
    }

    /// The rects each range is painted with, one per line, in text-view coordinates, from one walk
    /// over the fragments the ranges touch: from the first character on that line to the end of its
    /// last non-whitespace one, and vertically the body font's ascent and descent around the
    /// line's baseline. The same geometry as the Mac's.
    func segmentFrames(of ranges: [NSRange]) -> [[CGRect]] {
        var frames = Array(repeating: [CGRect](), count: ranges.count)
        guard let contentStorage, let storage = contentStorage.textStorage, let layoutManager = textView.textLayoutManager else { return frames }
        let text = storage.string as NSString
        let order = ranges.indices
            .filter { ranges[$0].location != NSNotFound && ranges[$0].length > 0 && NSMaxRange(ranges[$0]) <= text.length }
            .sorted { ranges[$0].location < ranges[$1].location }
        let documentStart = contentStorage.documentRange.location
        guard let first = order.first,
              let startLocation = contentStorage.location(documentStart, offsetBy: ranges[first].location)
        else { return frames }
        let inset = textView.textContainerInset
        let fallbackFont = appliedTypography?.bodyFont ?? ReaderTypography.default.bodyFont
        var fonts = Array(repeating: fallbackFont, count: ranges.count)
        for index in order {
            fonts[index] = storage.attribute(.font, at: ranges[index].location, effectiveRange: nil) as? UIFont ?? fallbackFont
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
                for line in fragment.textLineFragments {
                    let lineStart = fragmentStart + line.characterRange.location
                    let lineEnd = lineStart + line.characterRange.length
                    let segmentStart = max(range.location, lineStart)
                    var segmentEnd = min(NSMaxRange(range), lineEnd)
                    while segmentEnd > segmentStart, Self.isWhitespace(text.character(at: segmentEnd - 1)) { segmentEnd -= 1 }
                    guard segmentEnd > segmentStart else { continue }
                    // `locationForCharacter` is from the line's own origin, which sits at its
                    // typographic bounds: an indented first line or a hanging wrapped line starts
                    // that far in from the fragment's edge.
                    let x0 = line.typographicBounds.minX + line.locationForCharacter(at: segmentStart - fragmentStart).x
                    let x1 = line.typographicBounds.minX + line.locationForCharacter(at: segmentEnd - fragmentStart).x
                    let baseline = fragment.layoutFragmentFrame.minY + line.typographicBounds.minY + line.glyphOrigin.y
                    frames[index].append(CGRect(
                        x: fragment.layoutFragmentFrame.minX + x0 + inset.left,
                        y: baseline - font.ascender + inset.top,
                        width: max(0, x1 - x0),
                        height: font.ascender - font.descender))
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

    // MARK: - Footer

    private func setFooter(_ footer: UIView?) {
        guard footer !== self.footer else { return }
        self.footer?.removeFromSuperview()
        if let footer { textView.addSubview(footer) }
        self.footer = footer
        needsAccessoryMeasure = true
        if layout != nil { applyGeometry(force: true) }
    }

    // MARK: - Decorations

    private static func underlines(in decorations: BookDecorations) -> [Underline] {
        decorations.highlights.compactMap { decoration in
            switch decoration.style {
            case .background: return nil
            // As on the Mac, both in secondary ink; the pattern tells them apart.
            case .dottedUnderline: return Underline(range: decoration.range, style: [.single, .patternDot])
            case .dashedUnderline: return Underline(range: decoration.range, style: [.single, .patternDash])
            }
        }
    }

    private static func underlineAttributes(_ underline: Underline) -> [NSAttributedString.Key: Any] {
        [.underlineStyle: underline.style.rawValue, .underlineColor: Palette.inkSecondary.platformColor]
    }

    /// A decoration change after the load (a user action): only the ranges that were or become
    /// underlined are edited, and the scroll position is kept; the fills, the outline and the
    /// marks are drawn again.
    private func applyDecorationChange() {
        let new = Self.underlines(in: appliedDecorations)
        if let storage = contentStorage?.textStorage, new != underlines {
            let length = storage.length
            let offset = textView.contentOffset
            contentStorage?.performEditingTransaction {
                storage.beginEditing()
                for underline in underlines where NSMaxRange(underline.range) <= length {
                    storage.removeAttribute(.underlineStyle, range: underline.range)
                    storage.removeAttribute(.underlineColor, range: underline.range)
                }
                for underline in new where NSMaxRange(underline.range) <= length {
                    storage.addAttributes(Self.underlineAttributes(underline), range: underline.range)
                }
                storage.endEditing()
            }
            underlines = new
            // Re-measures and draws the overlays again.
            applyGeometry(force: true)
            if pending == nil, textView.contentOffset != offset { scroll(toY: offset.y) }
        } else {
            refreshOverlays()
        }
    }

    /// Paints the chapter's highlights and recolors their on-mark verse numbers.
    private func applyHighlights() {
        let length = contentStorage?.textStorage?.length ?? 0
        let colored = layout == nil ? [] : appliedDecorations.highlights.compactMap { decoration -> (RangeDecoration, UIColor)? in
            guard case .background(let color) = decoration.style, NSMaxRange(decoration.range) <= length else { return nil }
            return (decoration, color.platformColor)
        }
        backgroundFills = computeFills(colored)
        drawFills()
        applyNumberColors(colored.map(\.0))
    }

    /// The background fills, from the same per-line rects the outline uses. Where two highlights
    /// overlap, the overlap is painted again, after both, with a 50/50 blend.
    private func computeFills(_ colored: [(RangeDecoration, UIColor)]) -> [HighlightFill] {
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
            fills += segments[index].map { HighlightFill(id: decoration.id, rect: $0, color: color) }
        }
        for (index, overlap) in overlaps.enumerated() {
            let blended = UIColor.blendedMarkup(colored[overlap.i].1, colored[overlap.j].1)
            fills += segments[colored.count + index].map { HighlightFill(id: nil, rect: $0, color: blended) }
        }
        return fills
    }

    /// One view per fill, behind the text; a mark a handle is dragging is left out.
    private func drawFills() {
        fillsView.subviews.forEach { $0.removeFromSuperview() }
        for fill in backgroundFills where suppressedFillID == nil || fill.id != suppressedFillID {
            let view = UIView(frame: fill.rect)
            view.backgroundColor = fill.color
            view.layer.cornerRadius = Self.fillRadius
            fillsView.addSubview(view)
        }
    }

    /// A verse number inside a highlight draws in the style's on-mark color where it has one
    /// (`ReaderTypography.verseNumberColorOnMark`), as a rendering attribute.
    private func applyNumberColors(_ highlights: [RangeDecoration]) {
        let previous = numberColors.map(\.range)
        numberColors = []
        if let layout, let color = appliedTypography?.verseNumberColorOnMark {
            for highlight in highlights {
                guard let section = layout.section(containing: highlight.range.location) else { continue }
                for span in section.spans where span.numberRange.length > 0
                    && span.numberRange.location >= highlight.range.location && NSMaxRange(span.numberRange) <= NSMaxRange(highlight.range) {
                    numberColors.append((span.numberRange, color))
                }
            }
        }
        setRenderingColors(in: previous + numberColors.map(\.range))
    }

    /// The rendering colors on `ranges` changed. Invalidating them is what makes TextKit 2 draw
    /// them again (the text view draws each layout fragment in a view of its own, which its own
    /// `setNeedsDisplay` does not reach), and it drops their rendering attributes, so the colors
    /// they should carry are put back at once; the viewport is then laid out again.
    private func setRenderingColors(in ranges: [NSRange]) {
        guard !ranges.isEmpty, let layoutManager = textView.textLayoutManager else { return }
        for range in ranges {
            if let textRange = textRange(for: range) { layoutManager.invalidateRenderingAttributes(for: textRange) }
        }
        for range in ranges { applyRenderingColors(in: range, layoutManager: layoutManager) }
        layoutManager.textViewportLayoutController.layoutViewport()
        textView.setNeedsDisplay()
    }

    /// Gives `range` exactly the rendering colors the text should carry there now.
    private func applyRenderingColors(in range: NSRange, layoutManager: NSTextLayoutManager) {
        guard let whole = textRange(for: range) else { return }
        layoutManager.removeRenderingAttribute(.foregroundColor, for: whole)
        for run in labelFadeColors + numberColors {
            let part = NSIntersectionRange(run.range, range)
            guard part.length > 0, let textRange = textRange(for: part) else { continue }
            layoutManager.addRenderingAttribute(.foregroundColor, value: run.color, for: textRange)
        }
    }

    /// The layout manager's validator: whenever TextKit validates a fragment's rendering
    /// attributes (after an invalidation, its own or ours), the fragment gets its colors back.
    fileprivate func validateRenderingColors(of fragment: NSTextLayoutFragment, in layoutManager: NSTextLayoutManager) {
        guard !(labelFadeColors.isEmpty && numberColors.isEmpty), let contentStorage else { return }
        let start = contentStorage.offset(from: contentStorage.documentRange.location, to: fragment.rangeInElement.location)
        let end = contentStorage.offset(from: contentStorage.documentRange.location, to: fragment.rangeInElement.endLocation)
        let range = NSRange(location: start, length: end - start)
        guard (labelFadeColors + numberColors).contains(where: { NSIntersectionRange($0.range, range).length > 0 }) else { return }
        applyRenderingColors(in: range, layoutManager: layoutManager)
    }

    /// Recomputes everything drawn from line geometry (the fills, the outline, the margin marks,
    /// the chapter-note mark, the numeral), so a reflow can never leave one of them stale.
    private func refreshOverlays() {
        let size = textView.contentSize
        fillsView.frame = CGRect(origin: .zero, size: size)
        outlineView.frame = CGRect(origin: .zero, size: size)
        liveView.frame = CGRect(origin: .zero, size: size)
        refreshChapterNoteMarks()
        refreshDropNumeral()
        applyHighlights()
        selectionHighlightView.refresh()
        guard layout != nil else {
            outlineView.subviews.forEach { $0.removeFromSuperview() }
            markButtons.forEach { $0.isHidden = true }
            placeHandles()
            return
        }
        applyOpeningLabelAlpha(openingLabelAlpha, force: true)
        outlineView.subviews.forEach { $0.removeFromSuperview() }
        if let id = appliedDecorations.outlinedID, id != suppressedFillID, let decoration = appliedDecorations.decoration(id: id) {
            let color = Palette.accent.platformColor.resolvedColor(with: textView.traitCollection).cgColor
            for rect in segmentFrames(of: [decoration.range])[0] {
                let view = UIView(frame: rect.insetBy(dx: -Self.outlineMargin, dy: -Self.outlineMargin))
                view.layer.borderWidth = Self.outlineWidth
                view.layer.borderColor = color
                view.layer.cornerRadius = Self.outlineRadius
                outlineView.addSubview(view)
            }
        }
        placeMarkButtons()
        drawStroke()
        placeHandles()
    }

    /// Places Lectern's numeral beside the chapter's laid-out first line (`DropNumeral.placements`),
    /// making its view when the chapter it names changes; none in the other styles.
    private func refreshDropNumeral() {
        var placement: DropNumeral.Placement?
        if let layout, let typography = appliedTypography, let layoutManager = textView.textLayoutManager, let contentStorage {
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
            textView.insertSubview(made, aboveSubview: liveView)
            numeralView = made
        }
        numeralView?.place(placement, font: DropNumeral.font(for: typography), inset: textView.textContainerInset)
    }

    // MARK: - Margin marks

    private func rebuildMarkButtons() {
        markButtons.forEach { $0.removeFromSuperview() }
        markButtons = appliedMarks.map { mark in
            let isNote = mark.isNote
            let button = MarginMarkButton(type: .system)
            button.setImage(UIImage(systemName: isNote ? "note.text" : "bookmark.fill"), for: .normal)
            button.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(textStyle: .caption1), forImageIn: .normal)
            button.tintColor = Palette.accent.platformColor
            button.accessibilityLabel = Self.accessibilityLabel(for: mark)
            button.addAction(UIAction { [weak self, weak button] _ in
                guard let self, let button else { return }
                controlTapped(button) { self.onMarginMarkTap(mark) }
            }, for: .primaryActionTriggered)
            textView.addSubview(button)
            return button
        }
    }

    /// VoiceOver's name for a mark, with its chapter and verse.
    static func accessibilityLabel(for mark: MarginMark) -> String {
        "\(mark.isNote ? "Note" : "Bookmark"), chapter \(mark.verse.chapter) verse \(mark.verse.verse)"
    }

    /// Each mark beside the glyphs of the line its character is on, in the margin right of the
    /// column; marks on one line stack downward: a note, then a bookmark. (A chapter's note mark
    /// is on its opening line, `refreshChapterNoteMarks`.)
    private func placeMarkButtons() {
        guard markButtons.count == appliedMarks.count, !markButtons.isEmpty else { return }
        let inset = textView.textContainerInset
        let columnRight = textView.bounds.width - inset.right
        let markHeight = ceil(UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: textView.traitCollection).lineHeight)
        // Stacking order on a line, then each entry's size: a mark's glyph line.
        let entries: [(order: Int, index: Int, button: MarginMarkButton, size: CGSize)] = appliedMarks.enumerated().map { offset, mark in
            (mark.isNote ? 0 : 1, mark.characterIndex, markButtons[offset], CGSize(width: Self.sideInset, height: markHeight))
        }
        let bands = segmentFrames(of: entries.map { NSRange(location: $0.index, length: 1) })
        var lines: [(band: CGRect, entries: [(order: Int, button: MarginMarkButton, size: CGSize)])] = []
        for (offset, entry) in entries.enumerated() {
            let band = bands[offset].first ?? lineFrame(forCharacterIndex: entry.index)?.offsetBy(dx: inset.left, dy: inset.top)
            guard let band else {
                entry.button.isHidden = true
                continue
            }
            entry.button.isHidden = false
            if let line = lines.firstIndex(where: { abs($0.band.minY - band.minY) < 1 }) {
                lines[line].entries.append((entry.order, entry.button, entry.size))
            } else {
                lines.append((band, [(entry.order, entry.button, entry.size)]))
            }
        }
        for line in lines {
            let ordered = line.entries.enumerated().sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }.map(\.element)
            var y = (line.band.midY - (ordered.first?.size.height ?? markHeight) / 2).rounded()
            for entry in ordered {
                entry.button.frame = CGRect(x: columnRight + (inset.right - Self.sideInset) / 2, y: y,
                                            width: entry.size.width, height: entry.size.height)
                y += entry.size.height + AppSpacing.xxs
            }
        }
        // Each touch area is 44 pt tall around its glyph, kept on screen, and split at the midpoint
        // where two marks sit closer than that. It reaches as far as 44 pt wide but never into
        // the column: there a press and hold belongs to the text, to select the line's last word.
        let reach = MarginMarkButton.minimumHitSize
        let shown = entries.map(\.button).filter { !$0.isHidden }.sorted { $0.frame.midY < $1.frame.midY }
        for (index, button) in shown.enumerated() {
            let frame = button.frame
            let top = index > 0 ? max(frame.midY - reach / 2, (shown[index - 1].frame.midY + frame.midY) / 2) : frame.midY - reach / 2
            let bottom = index < shown.count - 1 ? min(frame.midY + reach / 2, (frame.midY + shown[index + 1].frame.midY) / 2) : frame.midY + reach / 2
            let right = min(textView.bounds.width, frame.midX + reach / 2)
            let left = max(right - reach, columnRight)
            button.hitArea = CGRect(x: left, y: top, width: right - left, height: bottom - top)
                .offsetBy(dx: -frame.minX, dy: -frame.minY)
        }
    }

    // MARK: - UITextViewDelegate

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isReplacingText else { return }
        reportReadingPosition()
        updateRunningHead()
        reportScrollSinceJump()
        handleSwitcher(switcherTracker.scrolled(toY: textView.contentOffset.y, at: scrollClock(), ends: pageEnds, isBusy: isSwitcherBusy))
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        switcherTracker.dragBegan(atY: textView.contentOffset.y, at: scrollClock(), ends: pageEnds)
    }

    /// UIKit's `velocity` is in points per millisecond.
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint,
                                          targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        liftVelocity = velocity.y * 1000
        handleSwitcher(switcherTracker.dragEnded(atY: textView.contentOffset.y, at: scrollClock(), velocity: liftVelocity,
                                                 ends: pageEnds))
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { switcherTracker.coastEnded() }
        // The drag is over and the scroll has set off on its own bounce back: the switcher's
        // opening takes the page from it.
        if let pending = pendingSwitcherOpen {
            pendingSwitcherOpen = nil
            openSwitcher(at: pending.edge, opening: pending.opening)
        } else if !decelerate {
            closeSwitcherIfOutOfView()
        }
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        switcherTracker.coastEnded()
        closeSwitcherIfOutOfView()
    }

    /// The page's travel since the last jump landed, in lines of body text at the current size,
    /// with the target that jump was for, so the model can ignore a report from an earlier landing.
    private func reportScrollSinceJump() {
        guard !isReplacingText, pending == nil, let jumpLandedY, let target = appliedScrollTarget, let typography = appliedTypography,
              typography.bodyLineHeight > 0
        else { return }
        onScrollSinceJump(Double((textView.contentOffset.y - jumpLandedY) / typography.bodyLineHeight), target)
    }

    /// The system's press-and-hold selection, snapped to whole words once per change (setting the
    /// snapped range here comes back through this method, and is not snapped again), then reported.
    public func textViewDidChangeSelection(_ textView: UITextView) {
        // With the pen on there is no text selection; the pen's own selection is the outline.
        guard !isReplacingText, !isSettingSelection, !isPenOn, layout != nil else { return }
        var range = textView.selectedRange
        guard range.location != NSNotFound else {
            onSelectionChange(nil)
            return
        }
        if range.length > 0, let layout, let snapped = ReaderTextLogic.snapToWords(range, in: layout), snapped != range {
            setSelection(snapped)
            range = snapped
        }
        onSelectionChange(report(for: range))
    }

    /// The markup menu, which carries its own Look Up and Translate (`PhoneMarkupMenu`) so its
    /// list reads in one voice; the system's suggestions are dropped. A selection with no verse
    /// in it (a heading alone) keeps the system's Look Up and Translate.
    public func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        guard let report = report(for: range), let menu = menuProvider(report) else {
            return UIMenu(children: Self.keptSystemActions(suggestedActions))
        }
        return menu
    }

    // MARK: - Selection and menu

    /// Puts the reader's selection fill in place of the system's highlight view, by the system's
    /// own public slot for it, and again should the text view ever make its display anew.
    private func installSelectionHighlight() {
        guard let display = textView.interactions.lazy.compactMap({ $0 as? UITextSelectionDisplayInteraction }).first,
              display.highlightView !== selectionHighlightView
        else { return }
        display.highlightView = selectionHighlightView
        // A display made anew mid-selection hands the view its rects now, not at the next change.
        display.setNeedsSelectionUpdate()
    }

    /// The selection's fill for the system's line rects (`selectionHighlightView`'s coordinates):
    /// each trimmed to the words the highlights' own segments find on that line. The system
    /// gives rects only for the lines in or near view, so only the selection's part in the
    /// layout fragments under them is walked: a handle drag on a whole chapter's selection
    /// costs what one screen does.
    private func selectionFill(for lines: [CGRect]) -> [CGRect] {
        let view = selectionHighlightView
        let range = textView.selectedRange
        var fills: [CGRect] = []
        // Hidden: the system's selection has collapsed (it keeps its last rects).
        if !view.isHidden, !isPenOn, layout != nil, range.location != NSNotFound, range.length > 0, !lines.isEmpty {
            let lines = lines.map { view.convert($0, to: textView) }
            let walked = characters(under: lines).map { NSIntersectionRange($0, range) } ?? range
            fills = Self.trim(lines, to: segmentFrames(of: [walked])[0])
        }
        selectionFills = fills
        return fills.map { view.convert($0, from: textView) }
    }

    /// The characters of the layout fragments from the one under the topmost of `lines` (text-view
    /// coordinates) to the one under the lowest; nil when either is not found.
    private func characters(under lines: [CGRect]) -> NSRange? {
        guard let layoutManager = textView.textLayoutManager, let contentStorage,
              let first = lines.min(by: { $0.minY < $1.minY }), let last = lines.max(by: { $0.maxY < $1.maxY })
        else { return nil }
        let inset = textView.textContainerInset
        func fragment(under line: CGRect) -> NSTextLayoutFragment? {
            layoutManager.textLayoutFragment(for: CGPoint(x: line.midX - inset.left, y: line.midY - inset.top))
        }
        guard let top = fragment(under: first), let bottom = fragment(under: last) else { return nil }
        let documentStart = contentStorage.documentRange.location
        let start = contentStorage.offset(from: documentStart, to: top.rangeInElement.location)
        let end = contentStorage.offset(from: documentStart, to: bottom.rangeInElement.endLocation)
        return end > start ? NSRange(location: start, length: end - start) : nil
    }

    /// Each line rect (the system's, the line's full height) cut to the horizontal extent of the
    /// word segments on that line (those whose middle lies within it); a line with none is left out.
    static func trim(_ lines: [CGRect], to segments: [CGRect]) -> [CGRect] {
        lines.compactMap { line in
            let words = segments.filter { $0.midY >= line.minY && $0.midY < line.maxY }
            guard let minX = words.map(\.minX).min(), let maxX = words.map(\.maxX).max(), maxX > minX else { return nil }
            return CGRect(x: minX, y: line.minY, width: maxX - minX, height: line.height)
        }
    }

    /// Collapses a selection to an insertion point at its start (the markup menu does this before
    /// it changes the markup, so the selection tint does not hide the new color).
    func collapseSelection() {
        let range = textView.selectedRange
        guard range.location != NSNotFound, range.length > 0 else { return }
        textView.selectedRange = NSRange(location: range.location, length: 0)
    }

    /// The system share sheet for `text`, anchored on the first line of `range`, once the menu has closed.
    func presentShareSheet(_ text: String, for range: NSRange) {
        DispatchQueue.main.async { [weak self] in
            guard let self, var presenter = self.textView.nearestViewController else { return }
            while let presented = presenter.presentedViewController { presenter = presented }
            let sheet = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            if let popover = sheet.popoverPresentationController {
                popover.sourceView = self.textView
                popover.sourceRect = self.rect(for: range) ?? self.textView.bounds
            }
            presenter.present(sheet, animated: true)
        }
    }

    /// The range resolved to verses of one chapter, or nil when it covers no verse text (an
    /// opening or a heading never counts).
    private func report(for range: NSRange) -> SelectionReport? {
        guard let layout, range.location != NSNotFound else { return nil }
        return ReaderTextLogic.report(for: range, layout: layout, decorations: appliedDecorations)
    }

    /// Copy (⌘C with a keyboard, VoiceOver's Edit rotor) writes only the selection's verse text,
    /// never a heading, label, title or verse number (Ruling R8); a selection of none writes nothing.
    fileprivate func copySelection() {
        let range = textView.selectedRange
        guard range.location != NSNotFound, range.length > 0,
              let text = report(for: range)?.selection.quotedText, !text.isEmpty
        else { return }
        pasteboard.string = text
    }

    private func setSelection(_ range: NSRange) {
        isSettingSelection = true
        defer { isSettingSelection = false }
        textView.selectedRange = range
    }

    /// Of the system's suggestions only Look Up and Translate, found by their selectors anywhere
    /// in the suggested menus.
    private static func keptSystemActions(_ elements: [UIMenuElement]) -> [UIMenuElement] {
        elements.flatMap { element -> [UIMenuElement] in
            if let menu = element as? UIMenu { return keptSystemActions(menu.children) }
            guard let command = element as? UICommand else { return [] }
            return keptSelectors.contains(NSStringFromSelector(command.action)) ? [command] : []
        }
    }

    static let keptSelectors: Set<String> = ["_define:", "_translate:"]

    /// The innermost highlight under `point`: the one containing the character there, provided
    /// the point is on its painted rects (not in the margin or past the end of its line).
    private func highlight(at point: CGPoint) -> RangeDecoration? {
        guard layout != nil, !appliedDecorations.highlights.isEmpty,
              let position = textView.closestPosition(to: point),
              case let index = textView.offset(from: textView.beginningOfDocument, to: position),
              let decoration = ReaderTextLogic.innermostHighlight(containing: NSRange(location: index, length: 0), in: appliedDecorations)
        else { return nil }
        let hit = segmentFrames(of: [decoration.range])[0].contains {
            $0.insetBy(dx: -Self.outlineMargin, dy: -Self.outlineMargin).contains(point)
        }
        return hit ? decoration : nil
    }

    @objc private func handleHighlightTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        highlightTapped(at: gesture.location(in: textView), touch: verseTapTouchState ?? VerseTapTouch())
    }

    func highlightTapped(at point: CGPoint, touch: VerseTapTouch) {
        guard let decoration = highlightForTap(at: point, touch: touch) else { return }
        // On the reader's selection (an opened highlight, or a selection over this one): it keeps it.
        let selected = textView.selectedRange
        if !isPenOn, selected.location != NSNotFound, selected.length > 0 {
            presentMenu(for: selected)
            return
        }
        if isPenOn {
            // Selecting it again (it may already be) puts the menu back under it.
            pendingPenMenu = true
            onPenSelect(decoration.id)
            presentPendingPenMenu()
            return
        }
        if let noteID = noteForHighlight(decoration.id) {
            onOpenNote(noteID)
            return
        }
        openHighlight(id: decoration.id)
    }

    /// A tap away from any highlight with nothing selected: the text view keeps its hidden
    /// insertion point where it was and reports no change, so drop the outline that point left.
    @objc private func handleAwayTap(_ gesture: UITapGestureRecognizer) {
        // A tap on the page anywhere but the switcher's cards sends them away (Matt: they stay
        // until something is tapped). The tap goes on to do what it does.
        if gesture.state == .ended, openSwitcherEdge != nil, !isOnSwitcher(gesture.location(in: textView)) {
            closeSwitcher(animated: true)
        }
        guard gesture.state == .ended, awayTapMayAct, highlight(at: gesture.location(in: textView)) == nil else { return }
        if isPenOn {
            onPenSelect(nil)
            return
        }
        // Once every recogniser on the touch has acted: a repeated tap that left nothing selected
        // selects its verse again (`settleRepeatedTap`); otherwise the empty selection is reported.
        let point = gesture.location(in: textView)
        let repeated = verseTapTouchState.flatMap { $0.tapCount >= 2 ? $0 : nil }
        DispatchQueue.main.async { [weak self] in
            guard let self, textView.selectedRange.length == 0 else { return }
            if let repeated, settleRepeatedTap(at: point, touch: repeated) { return }
            onSelectionChange(nil)
        }
    }

    /// Selects the highlight's range, outlines it and presents the markup menu at it.
    private func openHighlight(id: UUID) {
        guard let decoration = appliedDecorations.decoration(id: id) else { return }
        if !textView.isFirstResponder { textView.becomeFirstResponder() }
        setSelection(decoration.range)
        onSelectionChange(report(for: decoration.range))
        onHighlightTap(id)
        presentMenu(for: decoration.range)
    }

    /// Presents the markup menu against `range`, the selection: directly above or below its
    /// whole bounds (`menuPlacement(for:in:room:)`), from the middle of the side it opens on.
    /// `editMenuInteraction(_:targetRectFor:)` gives the system the same bounds, so the menu
    /// is kept clear of every selected line, not the first alone.
    private func presentMenu(for range: NSRange) {
        guard let placement = menuPlacement(for: range) else { return }
        menuPresentations += 1
        let target = placement.target
        let configuration = UIEditMenuConfiguration(
            identifier: nil, sourcePoint: CGPoint(x: target.midX, y: placement.arrow == .up ? target.maxY : target.minY))
        configuration.preferredArrowDirection = placement.arrow
        presentedMenuConfiguration = configuration
        highlightMenu.presentEditMenu(with: configuration)
    }

    // MARK: A tap selects the verse

    /// What a touch looked like as it came down; the verse tap's rules read it at touch-up.
    struct VerseTapTouch: Equatable {
        var tapCount = 1            // UITouch.tapCount: 2 for the second tap of a double tap
        var pageWasMoving = false   // textView.isDragging || textView.isDecelerating
        var cardsWereOpen = false   // openSwitcherEdge != nil
        var awayFromSelection = false   // isTapAway at the touch's point, as it came down
    }

    var verseTapRecognizer: UITapGestureRecognizer { verseTap }

    /// Whether `point` (text-view coordinates) is on one of the verse's laid-out lines: horizontally
    /// within the verse's painted segment on that line (`segmentFrames` of its `fullRange`: number and
    /// words, trailing white space left out), vertically within that line fragment's whole
    /// typographic height (`lineFrame(forCharacterIndex:)`), both outset by `outlineMargin`.
    func isOnLines(_ span: VerseSpan, at point: CGPoint) -> Bool {
        isOnLines(of: span.fullRange, at: point)
    }

    /// Whether `point` is on `range`'s laid-out lines, by `isOnLines(_:at:)`'s measure.
    private func isOnLines(of range: NSRange, at point: CGPoint) -> Bool {
        let margin = Self.outlineMargin
        let inset = textView.textContainerInset
        return segmentFrames(of: [range])[0].contains { segment in
            guard point.x >= segment.minX - margin, point.x <= segment.maxX + margin,
                  // The segment's first character, which names its line.
                  let start = textView.closestPosition(to: CGPoint(x: segment.minX + min(1, segment.width / 2), y: segment.midY)),
                  let line = lineFrame(forCharacterIndex: textView.offset(from: textView.beginningOfDocument, to: start))?
                      .offsetBy(dx: inset.left, dy: inset.top)
            else { return false }
            return point.y >= line.minY - margin && point.y <= line.maxY + margin
        }
    }

    /// The page's state for a touch coming down now at `point`; the delegate's `shouldReceive` records it.
    func verseTapTouch(tapCount: Int, at point: CGPoint? = nil) -> VerseTapTouch {
        var touch = VerseTapTouch(tapCount: tapCount, pageWasMoving: textView.isDragging || textView.isDecelerating,
                                  cardsWereOpen: openSwitcherEdge != nil)
        if let point { touch.awayFromSelection = isAwayFromSelection(point) }
        return touch
    }

    /// Whether a tap at `point` is a tap away (Matt, 2026-11-17): with the reader's selection up
    /// (a tapped verse, a dragged range, a held word, an opened highlight), a tap anywhere off it
    /// only clears it, and selects or opens nothing; the next tap does what a tap does with
    /// nothing selected. The one place that answers it: `verseForTap` declines such a tap, the
    /// verse tap's action clears the selection, and the highlight tap declines it too. Read
    /// against the selection as the touch came down (`touch.awayFromSelection`, for a repeated
    /// tap settled after the system's own tap has cleared it) or as it is now. A tap that stops
    /// a moving scroll is not a tap; with the pen on, or VoiceOver running, taps are as they were.
    func isTapAway(at point: CGPoint, touch: VerseTapTouch) -> Bool {
        guard !isPenOn, !isVoiceOverRunning(), !touch.pageWasMoving else { return false }
        return touch.awayFromSelection || isAwayFromSelection(point)
    }

    /// Whether the reader's selection is up and `point` is off it: off its laid-out lines, and,
    /// for a selected verse, off that verse's number too.
    private func isAwayFromSelection(_ point: CGPoint) -> Bool {
        let range = textView.selectedRange
        guard !isPenOn, let layout, range.location != NSNotFound, range.length > 0 else { return false }
        if isOnLines(of: range, at: point) { return false }
        if let span = layout.span(containing: range.location), span.textRange == range, isOnLines(span, at: point) { return false }
        return true
    }

    /// The highlight a tap at `point` opens, or nil when it is not a highlight tap (a tap away
    /// from the reader's selection is not, even on a highlight).
    func highlightForTap(at point: CGPoint, touch: VerseTapTouch) -> RangeDecoration? {
        isTapAway(at: point, touch: touch) ? nil : highlight(at: point)
    }

    /// A tap on one of the page's controls (a margin mark, a chapter-note mark), which the verse
    /// tap never takes: with the reader's selection up it is a tap away (`isTapAway`, at the
    /// control's centre) and only clears the selection; otherwise the control does `action`.
    func controlTapped(_ control: UIView, action: () -> Void) {
        let centre = textView.convert(CGPoint(x: control.bounds.midX, y: control.bounds.midY), from: control)
        if isTapAway(at: centre, touch: VerseTapTouch()) {
            clearSelection()
            return
        }
        action()
    }

    /// The selection cleared and its menu closed, reported as none; nothing else.
    private func clearSelection() {
        highlightMenu.dismissMenu()
        let range = textView.selectedRange
        if range.location != NSNotFound, range.length > 0 {
            setSelection(NSRange(location: range.location, length: 0))
        }
        onSelectionChange(nil)
    }

    /// The verse a tap at `point` selects, or nil when it is not a verse tap. A tap away from the
    /// reader's selection (`isTapAway`) is not: it only clears the selection. One on the
    /// selection is the verse under it, whose tap keeps the selection.
    func verseForTap(at point: CGPoint, touch: VerseTapTouch) -> VerseSpan? {
        guard let layout, !isPenOn, !isVoiceOverRunning(), touch.tapCount == 1, !touch.pageWasMoving, !touch.cardsWereOpen,
              awayTapMayAct, !isTapAway(at: point, touch: touch), !isInThumbZone(point), highlight(at: point) == nil,
              let position = textView.closestPosition(to: point)
        else { return nil }
        let index = textView.offset(from: textView.beginningOfDocument, to: position)
        return ReaderTextLogic.verse(at: index, in: layout) { isOnLines($0, at: point) }
    }

    /// The recogniser's action. A tap away from the selection clears it and does nothing else; a
    /// tap on the selection keeps it and presents its menu again; with nothing selected the tap
    /// selects the verse's `textRange`, reports it and presents the menu.
    func verseTapped(at point: CGPoint, touch: VerseTapTouch) {
        if isTapAway(at: point, touch: touch) {
            clearSelection()
            if touch.tapCount >= 2 {
                // The system's double tap does not wait for this tap, so it may select a word
                // under it afterwards: once every recogniser on the touch has acted, that goes too.
                DispatchQueue.main.async { [weak self] in
                    guard let self, textView.selectedRange.length > 0 else { return }
                    clearSelection()
                }
            }
            return
        }
        guard let span = verseForTap(at: point, touch: touch) else { return }
        let selected = textView.selectedRange
        if selected.location != NSNotFound, selected.length > 0 {
            presentMenu(for: selected)
            return
        }
        if !textView.isFirstResponder { textView.becomeFirstResponder() }
        setSelection(span.textRange)
        onSelectionChange(report(for: span.textRange))
        presentMenu(for: span.textRange)
    }

    @objc private func handleVerseTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        verseTapped(at: gesture.location(in: textView), touch: verseTapTouchState ?? VerseTapTouch())
    }

    /// A repeated tap (`tapCount` 2 or more) on a verse's lines, settled once the touch's
    /// recognisers have acted. The verse tap declines such a tap so the system's double tap can
    /// narrow to a word; when that tap came too slowly for the double tap, the system's single
    /// tap clears the selection instead. So with nothing selected the verse under the tap is
    /// selected, with its menu, by the verse tap's other rules; a selection the double tap made
    /// is left alone. Returns whether it selected the verse.
    @discardableResult
    func settleRepeatedTap(at point: CGPoint, touch: VerseTapTouch) -> Bool {
        guard touch.tapCount >= 2, textView.selectedRange.length == 0 else { return false }
        var single = touch
        single.tapCount = 1
        guard verseForTap(at: point, touch: single) != nil else { return false }
        verseTapped(at: point, touch: single)
        return true
    }
}

extension PhoneChapterTextController: @MainActor UIEditMenuInteractionDelegate, UIGestureRecognizerDelegate {
    public func editMenuInteraction(_ interaction: UIEditMenuInteraction, menuFor configuration: UIEditMenuConfiguration,
                                    suggestedActions: [UIMenuElement]) -> UIMenu? {
        if isPenOn {
            guard let id = penSelectedID, let decoration = appliedDecorations.decoration(id: id),
                  let report = report(for: decoration.range)
            else { return nil }
            return penMenuProvider(id, report)
        }
        return textView(textView, editMenuForTextIn: textView.selectedRange, suggestedActions: suggestedActions)
    }

    public func editMenuInteraction(_ interaction: UIEditMenuInteraction, targetRectFor configuration: UIEditMenuConfiguration) -> CGRect {
        if isPenOn {
            guard let id = penSelectedID, let decoration = appliedDecorations.decoration(id: id) else { return .null }
            return segmentFrames(of: [decoration.range])[0].reduce(CGRect.null) { $0.union($1) }
        }
        return menuPlacement(for: textView.selectedRange)?.target ?? .null
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === paintGesture {
            let point = gestureRecognizer.location(in: textView)
            return paintMayBegin(touchStartedAt: paintTouchStart ?? point, at: point)
        }
        if gestureRecognizer === awayTap { return awayTapMayAct }
        if gestureRecognizer === switcherPan { return openSwitcherEdge != nil && !isThumbPressed }
        let touch = verseTapTouchState ?? VerseTapTouch()
        if gestureRecognizer === verseTap {
            // A verse tap, or a tap away from the selection, which this recogniser clears (the
            // text view's single taps wait for it, so they do not act on the tap as well).
            let point = gestureRecognizer.location(in: textView)
            return isTapAway(at: point, touch: touch) || verseForTap(at: point, touch: touch) != nil
        }
        return gestureRecognizer !== highlightTap || highlightForTap(at: gestureRecognizer.location(in: textView), touch: touch) != nil
    }

    /// A touch on a handle belongs to the handle alone: it neither paints, selects, deselects
    /// nor opens the thumb. The thumb takes only touches that start in its edge zone; the paint
    /// gesture notes whether its touch did, so it never begins there. The verse tap takes no touch
    /// on a handle or a control (the margin's marks, the chapter-note mark), and records the
    /// page's state as its touch comes down: the away tap closes the cards at touch-up, in no
    /// fixed order with the verse tap.
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer === verseTap {
            let refused = touch.view is PenHandleView || touch.view is UIControl
            verseTapTouchState = refused ? nil : verseTapTouch(tapCount: touch.tapCount, at: touch.location(in: textView))
            return !refused
        }
        guard gestureRecognizer === paintGesture || gestureRecognizer === highlightTap || gestureRecognizer === awayTap
                || gestureRecognizer === thumbPress
        else { return true }
        let point = touch.location(in: textView)
        if gestureRecognizer === thumbPress {
            // Every touch: the start is the current touch's, never a stale one.
            let takes = !(touch.view is PenHandleView) && thumbReceivesTouch(at: point)
            thumbTouchStart = takes ? point : nil
            return takes
        }
        if gestureRecognizer === awayTap { awayTapTouchBegan() }
        if touch.view is PenHandleView { return false }
        if gestureRecognizer === paintGesture { paintTouchStart = point }
        return true
    }

    /// In the edge zone the pen waits for the thumb's press to fail (a drag that starts moving,
    /// or a lift before the hold), so the press is the thumb's. Only while the press is following
    /// a touch, so a stroke begun in the text never waits on it.
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === paintGesture, otherGestureRecognizer === thumbPress, let start = paintTouchStart else { return false }
        return thumbPress.numberOfTouches > 0 && paintRequiresThumbToFail(touchStartedAt: start)
    }

    /// The away tap runs alongside everything.
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer === awayTap || otherGestureRecognizer === awayTap
    }

    /// The text view's own taps (which would clear the selection the highlight tap makes) wait
    /// for the highlight tap to fail. With the pen on, the scroll view's pan and the taps wait for
    /// the paint gesture to fail (Ruling 2): a drag that starts moving scrolls, a quick tap selects
    /// or deselects, and a hold paints and does neither.
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // In the edge zone the text view's own long presses, loupe, selection and taps wait for
        // the thumb's press to fail, so the press is the thumb's by rule, not by its shorter hold.
        if gestureRecognizer === thumbPress {
            return textViewGestureWaitsForThumb(otherGestureRecognizer, touchStartedAt: thumbTouchStart)
        }
        if gestureRecognizer === paintGesture {
            return isPenOn && (otherGestureRecognizer === textView.panGestureRecognizer
                || otherGestureRecognizer === highlightTap || otherGestureRecognizer === awayTap)
        }
        // The text view's single taps (which would clear the verse just selected) wait for the
        // verse tap; its double tap does not, so a double tap still selects a word.
        if gestureRecognizer === verseTap {
            return (otherGestureRecognizer as? UITapGestureRecognizer)?.numberOfTapsRequired == 1
                && otherGestureRecognizer.view === textView && !ownGestures.contains { $0 === otherGestureRecognizer }
        }
        return gestureRecognizer === highlightTap && otherGestureRecognizer is UITapGestureRecognizer
            && otherGestureRecognizer !== awayTap && otherGestureRecognizer.view === textView
    }
}

// MARK: - The book thumb

/// The book thumb's press at the page's right edge (`PhoneChapterTextController.onThumb`), its
/// height in the window's coordinates.
enum ThumbGesture: Equatable {
    case began(y: CGFloat)
    case moved(y: CGFloat)
    case ended(y: CGFloat)
    case cancelled
}

extension PhoneChapterTextController {
    /// Whether `point` (text-view coordinates) is within `thumbEdgeZone` of the page's right
    /// edge inside the safe area, where the thumb's track is drawn (the overlay keeps to the safe
    /// area; in landscape the text view runs on under the sensor housing), or beyond it.
    func isInThumbZone(_ point: CGPoint) -> Bool {
        point.x >= textView.bounds.width - textView.safeAreaInsets.right - Self.thumbEdgeZone
    }

    /// Whether the thumb's press takes a touch starting at `point`: only in the edge zone, so a
    /// press in the column (or a stroke begun there) is never the thumb's.
    func thumbReceivesTouch(at point: CGPoint) -> Bool { isInThumbZone(point) }

    /// Whether the pen's paint gesture may begin at `point`, for a touch that started at
    /// `start`: with the pen on, at a paintable place, and never for a touch that started in
    /// the edge zone, which is the thumb's.
    func paintMayBegin(touchStartedAt start: CGPoint, at point: CGPoint) -> Bool {
        isPenOn && !isInThumbZone(start) && isPaintable(point)
    }

    /// Whether the paint gesture waits for the thumb's press to fail, for a touch that started at
    /// `start`: in the edge zone only.
    func paintRequiresThumbToFail(touchStartedAt start: CGPoint) -> Bool { isInThumbZone(start) }

    /// The margin's marks out of the ruler's way while the thumb is pressed, and back when it
    /// lifts. At once: the loupe's picture of the page is taken as the press begins.
    private func setMarksAside(_ aside: Bool) {
        thumbHidesMarks = aside
        markButtons.forEach { $0.alpha = aside ? 0 : 1 }
        applyOpeningNoteMarkAlpha()
    }

    /// A picture of the page under `frame` (the window's coordinates), for the thumb's loupe
    /// (`PageBackdrop`): the text view as it is drawn now, text, highlights and all, at `scale`.
    func pagePicture(under frame: CGRect, scale: CGFloat) -> CGImage? {
        guard textView.window != nil, frame.width > 0, frame.height > 0 else { return nil }
        // The text view's own coordinates are its content's, which its layer draws in.
        let rect = textView.convert(frame, from: nil)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            context.cgContext.translateBy(x: -rect.minX, y: -rect.minY)
            textView.layer.render(in: context.cgContext)
        }.cgImage
    }

    /// The hold before the thumb's press begins.
    var thumbPressDuration: TimeInterval { thumbPress.minimumPressDuration }

    /// The recognisers the controller adds to the text view; the rest are the text view's own.
    var ownGestures: [UIGestureRecognizer] { [paintGesture, highlightTap, verseTap, awayTap, thumbPress, switcherPan] }

    /// Whether `other` waits for the thumb's press to fail, for a touch that started at `start`
    /// (nil when the press did not take it): the text view's own recognisers (its long presses,
    /// loupe, selection and taps) do in the edge zone; the scroll's pan, the controller's own
    /// recognisers and anything on another view never do.
    func textViewGestureWaitsForThumb(_ other: UIGestureRecognizer, touchStartedAt start: CGPoint?) -> Bool {
        guard let start, isInThumbZone(start) else { return false }
        guard other !== textView.panGestureRecognizer, !ownGestures.contains(where: { $0 === other }) else { return false }
        return textView.gestureRecognizers?.contains { $0 === other } ?? false
    }

    /// A new touch on the text view: whatever the thumb claimed before is over.
    func awayTapTouchBegan() { thumbClaimedTouch = false }

    /// Whether the away tap may act on the touch now: not on one the thumb's press claimed.
    var awayTapMayAct: Bool { !thumbClaimedTouch }

    @objc fileprivate func handleThumbPress(_ press: UILongPressGestureRecognizer) {
        let point = press.location(in: textView)
        thumbPressed(press.state, at: point, touchStartedAt: thumbTouchStart ?? point)
    }

    /// The thumb's press in `state` at `point` (text-view coordinates), for a touch that started
    /// at `start`, reported through `onThumb` with its height in the page: it begins only for a
    /// touch that started in the edge zone (wherever the finger has drifted to by the hold), and
    /// its moves, end or cancellation follow only a press that began.
    func thumbPressed(_ state: UIGestureRecognizer.State, at point: CGPoint, touchStartedAt start: CGPoint) {
        // The window's coordinates, which the screen measures the thumb's track in too. (The
        // page's own would not do: the track's overlay keeps to the safe area, under the bars,
        // and its named space began there, a bar's height below the page's top; the press read
        // that much too far down the book. Found 2026-11-13.)
        let y = textView.convert(point, to: nil).y
        switch state {
        case .began:
            guard isInThumbZone(start) else { return }
            isThumbPressed = true
            thumbClaimedTouch = true
            highlightMenu.dismissMenu()
            // The switcher and the thumb never show together.
            closeSwitcher(animated: true)
            setMarksAside(true)
            // The drag from here is the thumb's: the page stays put under it. (A swipe at the
            // edge moves the finger before the hold, so the press fails and the page scrolls.)
            textView.panGestureRecognizer.isEnabled = false
            textView.panGestureRecognizer.isEnabled = true
            onThumb(.began(y: y))
        case .changed:
            guard isThumbPressed else { return }
            onThumb(.moved(y: y))
        case .ended:
            guard isThumbPressed else { return }
            isThumbPressed = false
            setMarksAside(false)
            onThumb(.ended(y: y))
        case .cancelled, .failed:
            guard isThumbPressed else { return }
            isThumbPressed = false
            setMarksAside(false)
            onThumb(.cancelled)
        default:
            break
        }
    }
}

// MARK: - The chapter switcher

extension PhoneChapterTextController {
    /// The page's scroll range: its top and its foot as content offsets, without the room the
    /// open switcher adds.
    var pageEnds: ClosedRange<CGFloat> { minOffsetY...maxOffsetY }

    /// Nothing is pulled while a selection drag, the pen (a stroke or a handle drag) or the thumb
    /// is under way. Asked by the tracker only for a tick that would report, never on every
    /// scroll tick.
    var isSwitcherBusy: Bool {
        isThumbPressed || stroke != nil || loupe != nil || isSelectionDragging
    }

    /// The text view's own presses and drags (its loupe, its selection's handles) that are under way.
    private var isSelectionDragging: Bool {
        textView.gestureRecognizers?.contains { recognizer in
            guard recognizer !== textView.panGestureRecognizer, !ownGestures.contains(where: { $0 === recognizer }),
                  recognizer is UILongPressGestureRecognizer || recognizer is UIPanGestureRecognizer
            else { return false }
            return recognizer.state == .began || recognizer.state == .changed
        } ?? false
    }

    /// The room the open switcher takes at its end of the scroll: the cards and the gap between
    /// them and the page.
    var switcherRoom: CGFloat { switcherHeight + Self.switcherGap }

    /// Where the page rests with the switcher open at `edge`: its own end, and the cards' room on.
    func switcherRestY(at edge: ChapterSwitcher.Edge) -> CGFloat {
        edge == .bottom ? maxOffsetY + switcherRoom : minOffsetY - switcherRoom
    }

    /// The cards' frame in the text view (`nil` with none): for the tests, and the touches.
    var switcherFrame: CGRect? { switcherView.flatMap { $0.isHidden ? nil : $0.frame } }

    /// Whether `point` (text-view coordinates) is on the open switcher's cards: a tap there is
    /// the cards', and no tap away.
    func isOnSwitcher(_ point: CGPoint) -> Bool {
        openSwitcherEdge != nil && (switcherFrame?.contains(point) ?? false)
    }

    /// Whether the page's own pan may begin: not while the switcher is open, when a flick
    /// anywhere on the page moves the cards instead (`switcherPan`).
    var pageMayPan: Bool { openSwitcherEdge == nil }

    @objc fileprivate func handleSwitcherPan(_ pan: UIPanGestureRecognizer) {
        switcherFlicked(pan.state, translation: pan.translation(in: textView).y, velocity: pan.velocity(in: textView).y)
    }

    /// A flick anywhere on the page while the switcher is open, `translation` points down the
    /// screen so far and moving at `velocity` points per second: onward is the way the page was
    /// pulled (up at the foot, down at the top). The front card rides it, and where it is going
    /// to end (its travel and a sixth of a second of its speed) moves the cards by one, or back
    /// from the first card closes them.
    func switcherFlicked(_ state: UIGestureRecognizer.State, translation: CGFloat, velocity: CGFloat) {
        guard let edge = openSwitcherEdge, let switcher else { return }
        let onward: CGFloat = edge == .bottom ? -1 : 1
        switch state {
        case .changed:
            switcher.drag(onward: onward * translation)
        case .ended:
            switcher.endDrag(predictedOnward: onward * (translation + velocity * Self.flickMomentum))
        case .cancelled, .failed:
            switcher.endDrag(predictedOnward: 0)
        default:
            break
        }
    }

    /// How much of a flick's speed counts toward where it is going to end, in seconds.
    static let flickMomentum: CGFloat = 1.0 / 6

    /// The hosted cards (`ChapterSwitcherDeckView`), kept as the footer is; nil for none.
    func setSwitcherView(_ view: UIView?) {
        guard view !== switcherView else { return }
        closeSwitcher(animated: false)
        switcherView?.removeFromSuperview()
        if let view {
            view.isHidden = true
            textView.addSubview(view)
        }
        switcherView = view
        needsAccessoryMeasure = true
        if layout != nil { applyGeometry(force: true) }
    }

    /// Whether a pull or a coast at `edge` may show the cards: the screen allows it, the book has
    /// a chapter that way, and the switcher is not already open.
    private func switcherMayShow(at edge: ChapterSwitcher.Edge) -> Bool {
        guard let switcher, switcherView != nil, switcherHeight > 0, openSwitcherEdge == nil else { return false }
        let edges = switcher.edges
        return edge == .top ? edges.top : edges.bottom
    }

    /// The cards just past the page's `edge`: below its foot, or above its top.
    private func placeSwitcher(at edge: ChapterSwitcher.Edge) {
        guard let switcherView else { return }
        let y = edge == .bottom ? contentHeight + Self.switcherGap : -switcherHeight
        let frame = CGRect(x: settledColumn.side, y: y, width: settledColumn.width, height: switcherHeight)
        if switcherView.frame != frame { switcherView.frame = frame }
    }

    /// What the tracker read from the scroll: a pull brings the cards in at its end, letting go
    /// past the threshold opens the switcher (once the drag has ended), and anything else sends
    /// the cards away.
    fileprivate func handleSwitcher(_ event: ChapterSwitcherTracker.Event?) {
        guard let event, openSwitcherEdge == nil else { return }
        switch event {
        case let .pulled(edge, distance):
            guard distance > 0, switcherMayShow(at: edge) else {
                endSwitcherPull()
                return
            }
            if pulledSwitcherEdge != edge {
                pulledSwitcherEdge = edge
                placeSwitcher(at: edge)
                switcherView?.isHidden = false
            }
            switcher?.pulled(edge: edge, distance: distance)
        case let .opened(edge, opening, _):
            // Not while the thumb, the pen or a selection has the finger.
            guard !isSwitcherBusy else { return endSwitcherPull() }
            switch opening {
            case .pull:
                // A pull whose cards are showing, or a flick from the page's end too quick to
                // have shown them; none that way, or not allowed, opens nothing.
                guard pulledSwitcherEdge == edge || switcherMayShow(at: edge) else { return endSwitcherPull() }
                pendingSwitcherOpen = (edge, opening)
            case .arrival:
                guard switcherMayShow(at: edge) else { return }
                liftVelocity = edge == .bottom ? switcherTracker.speed : -switcherTracker.speed
                openSwitcher(at: edge, opening: opening)
            }
        case .cancelled:
            endSwitcherPull()
        }
    }

    /// A pull that opened nothing is over: its cards go with the page's own spring back.
    private func endSwitcherPull() {
        guard pulledSwitcherEdge != nil else { return }
        pulledSwitcherEdge = nil
        pendingSwitcherOpen = nil
        switcherView?.isHidden = true
        switcher?.closed()
    }

    /// Opens the switcher at `edge`: room for the cards is added to the scroll at that end, and
    /// the page springs to rest with them in view, at the speed it was let go with (a fast pull
    /// overshoots and settles; under Reduce Motion it is simply there). Nothing on the page is
    /// covered: the page itself has moved.
    func openSwitcher(at edge: ChapterSwitcher.Edge, opening: ChapterSwitcher.Opening) {
        guard let switcherView, switcherHeight > 0, openSwitcherEdge == nil else { return }
        pulledSwitcherEdge = nil
        openSwitcherEdge = edge
        placeSwitcher(at: edge)
        switcherView.isHidden = false
        // The scroll's own bounce back stops here; the page goes on to its new rest.
        let from = textView.contentOffset
        textView.setContentOffset(from, animated: false)
        setSwitcherInsets(edge == .bottom ? UIEdgeInsets(top: 0, left: 0, bottom: switcherRoom, right: 0)
                                          : UIEdgeInsets(top: switcherRoom, left: 0, bottom: 0, right: 0))
        textView.contentOffset = from
        switcher?.opened(edge: edge, opening: opening, speed: abs(liftVelocity))
        let rest = CGPoint(x: 0, y: switcherRestY(at: edge))
        let travel = rest.y - from.y
        guard abs(travel) > 0.5, !reducesMotion(), textView.window != nil else {
            textView.contentOffset = rest
            return
        }
        // The spring's own unit: the travel per second, toward the rest.
        let velocity = min(max(liftVelocity / travel, -Self.switcherSpringLimit), Self.switcherSpringLimit)
        UIView.animate(withDuration: Self.switcherSpring.duration, delay: 0,
                       usingSpringWithDamping: Self.switcherSpring.damping, initialSpringVelocity: velocity,
                       options: [.allowUserInteraction, .beginFromCurrentState]) { [textView] in
            textView.contentOffset = rest
        }
    }

    /// Gives the scroll `insets` of room for the switcher, in place of what it had: added to
    /// whatever insets the scroll has of its own, which are left as they are.
    private func setSwitcherInsets(_ insets: UIEdgeInsets) {
        var all = textView.contentInset
        all.top += insets.top - switcherInsets.top
        all.bottom += insets.bottom - switcherInsets.bottom
        switcherInsets = insets
        textView.contentInset = all
    }

    /// The page's spring to its rest as the switcher opens, and back as it closes (calls; tune
    /// on a device).
    static let switcherSpring: (duration: TimeInterval, damping: CGFloat) = (0.55, 0.7)
    /// The most the lift's speed may start that spring with, in travels per second.
    static let switcherSpringLimit: CGFloat = 12

    /// Closes the switcher without moving the reader: the cards' room leaves the scroll, and a
    /// page resting in it goes back to its own end (animated: on the spring, the cards fading
    /// as it closes over them). Also ends a pull whose cards are showing.
    func closeSwitcher(animated: Bool) {
        endSwitcherPull()
        guard let edge = openSwitcherEdge else { return }
        openSwitcherEdge = nil
        let end = edge == .bottom ? maxOffsetY : minOffsetY
        let y = textView.contentOffset.y
        let isInRoom = edge == .bottom ? y > end : y < end
        textView.setContentOffset(textView.contentOffset, animated: false)
        let leave = { [self] in
            setSwitcherInsets(.zero)
            if isInRoom { textView.contentOffset = CGPoint(x: 0, y: end) }
        }
        let finish = { [weak self] in
            // Unless it has been pulled or opened again meanwhile.
            guard let self, openSwitcherEdge == nil, pulledSwitcherEdge == nil else { return }
            switcherView?.isHidden = true
            switcher?.closed()
        }
        guard animated, isInRoom, !reducesMotion(), textView.window != nil else {
            leave()
            finish()
            return
        }
        switcher?.closing()
        UIView.animate(withDuration: Self.switcherSpring.duration, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0,
                       options: [.allowUserInteraction, .beginFromCurrentState], animations: leave) { _ in finish() }
    }

    /// The reader scrolled back into the chapter until the cards left the screen: the switcher
    /// closes behind them, unseen, so the page's end is its own again.
    private func closeSwitcherIfOutOfView() {
        guard openSwitcherEdge != nil, let switcherView, !textView.bounds.intersects(switcherView.frame) else { return }
        closeSwitcher(animated: false)
    }
}

// MARK: - Pen

/// A stroke in progress: the words around where it was anchored (the held word for a paint, the
/// mark's far end for a handle), the words it covers now, and the color it is drawn in.
private struct PenStroke {
    enum Kind: Equatable {
        case paint
        case resize(UUID)
    }

    let kind: Kind
    let anchor: NSRange
    var range: NSRange?
    let color: UIColor
    /// Ended and handed to the markup; drawn until the markup comes back.
    var isFinished = false
}

extension PhoneChapterTextController {
    /// The pen's state from the reader: on or off, its color, and the mark it has selected.
    func setPen(isOn: Bool, color: UIColor, selectedID: UUID?) {
        penColor = color
        if isOn != isPenOn {
            isPenOn = isOn
            paintGesture.isEnabled = isOn
            // No press-and-hold selection with the pen on; the paint gesture has the hold.
            if isOn { collapseSelection() }
            textView.isSelectable = !isOn
            highlightMenu.dismissMenu()
            clearStroke()
        }
        let selected = isOn ? selectedID : nil
        if selected != penSelectedID {
            penSelectedID = selected
            pendingPenMenu = selected != nil
            if selected == nil { highlightMenu.dismissMenu() }
            placeHandles()
        }
    }

    /// The caret position nearest `point`, as a character index.
    private func characterIndex(at point: CGPoint) -> Int? {
        guard let position = textView.closestPosition(to: point) else { return nil }
        return textView.offset(from: textView.beginningOfDocument, to: position)
    }

    /// The characters on either side of the caret nearest `point`: the word under the finger.
    private func characters(around point: CGPoint) -> NSRange? {
        guard let index = characterIndex(at: point), let length = layout?.attributedString.length, length > 0 else { return nil }
        let start = max(0, min(index, length) - 1)
        return NSRange(location: start, length: min(length, index + 1) - start)
    }

    /// Inside the chapter's verse text: not in its opening (the title block, a label, a
    /// rule), on a section heading, below the text, or on a margin or chapter-note mark. Text is
    /// classified by the layout's `openingRange`s and spans, never by its reader roles.
    func isPaintable(_ point: CGPoint) -> Bool {
        let inset = textView.textContainerInset
        let textBottom = inset.top + (textView.textLayoutManager?.usageBoundsForTextContainer.maxY ?? 0)
        guard let layout, point.y >= inset.top, point.y <= textBottom, let index = characterIndex(at: point) else { return false }
        // The caret nearest the point sits before the character under it, or after the line's last.
        guard let section = layout.section(containing: index), !NSLocationInRange(index, section.openingRange),
              layout.span(containing: index) != nil || (index > 0 && layout.span(containing: index - 1) != nil)
        else { return false }
        let marks: [UIView] = markButtons + Array(chapterNoteMarkViews.values)
        return !marks.contains { !$0.isHidden && $0.point(inside: $0.convert(point, from: textView), with: nil) }
    }

    @objc fileprivate func handlePaint(_ gesture: PhonePaintGesture) {
        let point = gesture.location(in: textView)
        switch gesture.state {
        case .began:
            guard let anchor = characters(around: point) else { return }
            highlightMenu.dismissMenu()
            stroke = PenStroke(kind: .paint, anchor: anchor, color: penColor)
            paintHaptic.impactOccurred()
            beginLoupe(at: point)
            extendStroke(to: point)
        case .changed:
            moveLoupe(to: point)
            extendStroke(to: point)
        case .ended:
            endLoupe()
            guard var current = stroke, current.kind == .paint else { return }
            let report = current.range.flatMap { report(for: $0) }
            current.isFinished = true
            stroke = current
            // Review Focus 3: a stroke over no word paints nothing.
            if report == nil { clearStroke() }
            onPaint(report)
        default:
            endLoupe()
            clearStroke()
        }
    }

    @objc fileprivate func handleHandleDrag(_ press: UILongPressGestureRecognizer) {
        guard let handle = press.view as? PenHandleView else { return }
        let point = press.location(in: textView)
        switch press.state {
        case .began:
            guard let id = penSelectedID, let decoration = appliedDecorations.decoration(id: id) else { return }
            highlightMenu.dismissMenu()
            // The far end stays put: its last character for the start handle, its first for the end.
            let range = decoration.range
            let anchor = handle.end == .start ? NSRange(location: NSMaxRange(range) - 1, length: 1) : NSRange(location: range.location, length: 1)
            let color = backgroundFills.first { $0.id == id }?.color ?? Palette.accentWash.platformColor
            stroke = PenStroke(kind: .resize(id), anchor: anchor, range: range, color: color)
            suppressedFillID = id
            refreshOverlays()
            beginLoupe(at: point)
        case .changed:
            moveLoupe(to: point)
            extendStroke(to: point)
        case .ended:
            endLoupe()
            guard var current = stroke, case .resize(let id) = current.kind else { return }
            let original = appliedDecorations.decoration(id: id)?.range
            guard let range = current.range, range != original, let report = report(for: range) else {
                clearStroke()
                pendingPenMenu = true
                presentPendingPenMenu()
                return
            }
            current.isFinished = true
            stroke = current
            pendingPenMenu = true
            onResize(report)
        default:
            endLoupe()
            clearStroke()
        }
    }

    /// The system's loupe, from the moment a stroke or handle drag begins, following the finger.
    private func beginLoupe(at point: CGPoint) {
        loupe?.invalidate()
        loupe = UITextLoupeSession.begin(at: point, fromSelectionWidgetView: nil, in: textView)
    }

    private func moveLoupe(to point: CGPoint) {
        loupe?.move(to: point, withCaretRect: .null, trackingCaret: false)
    }

    private func endLoupe() {
        loupe?.invalidate()
        loupe = nil
    }

    /// The stroke from its anchor to the word at `point`, snapped to whole words.
    private func extendStroke(to point: CGPoint) {
        guard var current = stroke, !current.isFinished, let layout, let index = characterIndex(at: point) else { return }
        let start = min(current.anchor.location, max(0, index - 1))
        let end = max(NSMaxRange(current.anchor), index)
        let snapped = ReaderTextLogic.snapToWords(NSRange(location: start, length: end - start), in: layout)
        guard snapped != current.range else { return }
        current.range = snapped
        stroke = current
        drawStroke()
        placeHandles()
    }

    fileprivate func clearStroke() {
        stroke = nil
        let wasSuppressed = suppressedFillID != nil
        suppressedFillID = nil
        if wasSuppressed {
            refreshOverlays()
        } else {
            drawStroke()
            placeHandles()
        }
    }

    /// The stroke's rects in its color, with the fills' radius.
    fileprivate func drawStroke() {
        liveView.subviews.forEach { $0.removeFromSuperview() }
        guard let stroke, let range = stroke.range else { return }
        for rect in segmentFrames(of: [range])[0] {
            let view = UIView(frame: rect)
            view.backgroundColor = stroke.color
            view.layer.cornerRadius = Self.fillRadius
            liveView.addSubview(view)
        }
    }

    /// The handles at the selected mark's ends, or at a dragged stroke's ends while one is drawn;
    /// hidden with nothing selected, while painting, and for a mark from another translation
    /// (drawn on its whole verse, so its words are not this text's).
    fileprivate func placeHandles() {
        var range: NSRange?
        if let stroke, case .resize = stroke.kind {
            range = stroke.range
        } else if stroke == nil, let id = penSelectedID {
            range = appliedDecorations.decoration(id: id)?.range
        }
        let frames = range.map { segmentFrames(of: [$0])[0] } ?? []
        guard isPenOn, let first = frames.first, let last = frames.last, let id = penSelectedID, canResize(id) else {
            startHandle.isHidden = true
            endHandle.isHidden = true
            return
        }
        startHandle.place(atX: first.minX, on: first)
        endHandle.place(atX: last.maxX, on: last)
        startHandle.isHidden = false
        endHandle.isHidden = false
        textView.bringSubviewToFront(startHandle)
        textView.bringSubviewToFront(endHandle)
    }

    /// The menu under the selected mark, once it is drawn.
    fileprivate func presentPendingPenMenu() {
        guard pendingPenMenu, isPenOn, stroke == nil, let id = penSelectedID,
              let decoration = appliedDecorations.decoration(id: id),
              let last = segmentFrames(of: [decoration.range])[0].last
        else { return }
        pendingPenMenu = false
        let configuration = UIEditMenuConfiguration(identifier: nil, sourcePoint: CGPoint(x: last.midX, y: last.maxY))
        configuration.preferredArrowDirection = .up
        highlightMenu.presentEditMenu(with: configuration)
    }
}

private extension UIView {
    var nearestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }
}

/// A container for drawn views that never takes a touch.
private final class PassiveView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
}

/// A margin mark: the glyph keeps its small frame, and the touch lands within `hitArea` around it.
class MarginMarkButton: UIButton {
    static let minimumHitSize: CGFloat = 44
    /// In the button's own coordinates; set each time the marks are placed.
    var hitArea: CGRect = .null

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        (hitArea.isNull ? bounds : hitArea).contains(point)
    }
}

/// The text view's holder, for VoiceOver alone: the text view is one accessibility element, so
/// the views it carries (the margin marks, the chapter-note marks, the footer) are never reached
/// through it. This view lists them beside it, in reading order: the text, the marks from the
/// top down, the footer.
final class ReaderPageView: UIView {
    let textView: UITextView
    /// The marks' views and the footer as they are now; asked each time VoiceOver reads the page,
    /// so it follows the chapter.
    var accessories: () -> (marks: [UIView], footer: UIView?) = { ([], nil) }

    init(textView: UITextView) {
        self.textView = textView
        super.init(frame: .zero)
        textView.frame = bounds
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(textView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var accessibilityElements: [Any]? {
        get {
            let parts = accessories()
            let marks = parts.marks.filter { !$0.isHidden && $0.alpha > 0 }.sorted { $0.frame.minY < $1.frame.minY }
            return [textView] + marks + [parts.footer].compactMap { $0 }
        }
        set {}
    }
}

/// Tells the controller after each layout pass, so the geometry follows the width and the bars,
/// copies verse text only, and undoes with the scene's undo manager.
private final class ReaderTextView: UITextView {
    weak var readerDelegate: PhoneChapterTextController?

    override var undoManager: UndoManager? {
        readerDelegate?.sceneUndoManager ?? super.undoManager
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        readerDelegate?.textViewDidLayout()
    }

    /// The page's own pan does not begin while the chapter switcher is open: a flick anywhere
    /// is the cards'.
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === panGestureRecognizer, readerDelegate?.pageMayPan == false {
            return false
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    /// Only the selection's verse text, never an opening or a heading (Ruling R8).
    override func copy(_ sender: Any?) {
        readerDelegate?.copySelection()
    }

    /// The edit menus offer the reader's own items and the system's Look Up and Translate. The
    /// system's context menus the reader does not offer are taken out where they are built (a
    /// backstop); the delegate keeps only Look Up and Translate of what remains.
    ///
    /// iOS 27 adds one more item, Ask Siri, at the end of the compact bar, and it cannot be taken
    /// out: it is added after both menu delegates return, never appears in this builder, the
    /// suggested actions or `canPerformAction`, and no public API names it (a recording on the
    /// phone in 2026-11 showed this). It is kept. It takes the last of the bar's seven slots, so
    /// the reader's actions are drawn as symbols and ordered (`PhoneMarkupMenu.phoneOrder`) so the
    /// six slots left hold the chip, the note, Delete, the bookmark, Ask and Copy first; the rest
    /// are named rows behind the chevron.
    override func buildMenu(with builder: any UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == .context else { return }
        for menu: UIMenu.Identifier in [.standardEdit, .replace, .open, .format, .learn, .speech, .share, .autoFill, .find] {
            builder.remove(menu: menu)
        }
    }

    /// The standard edit commands the text view answers for: Look Up and Translate, Copy (⌘C with a
    /// keyboard), and Select and Select All, which VoiceOver's Edit rotor offers through this
    /// method. The visual menu still shows only what the delegate keeps. Answering false here only
    /// passes the query up the responder chain, and a `UIAction` the system appends is never
    /// asked about at all, so this is not what keeps a system-added item out of the menu: that is
    /// the `buildMenu` removal above and `writingToolsBehavior = .none`.
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        let name = NSStringFromSelector(action)
        guard Self.answeredSelectors.contains(name) || PhoneChapterTextController.keptSelectors.contains(name) else { return false }
        return super.canPerformAction(action, withSender: sender)
    }

    private static let answeredSelectors: Set<String> = ["copy:", "select:", "selectAll:"]
}
#endif
