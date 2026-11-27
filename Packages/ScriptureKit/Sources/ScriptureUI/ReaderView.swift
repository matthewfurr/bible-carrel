import ScriptureData
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// What the reader needs from the markup layer: decorations to draw, where to send selection
/// changes, and (on macOS) who builds the context menu.
public struct ReaderMarkup {
    public var decorations: BookDecorations
    public var onSelectionChange: (SelectionReport?) -> Void
    #if os(macOS)
    public var menuProvider: (SelectionReport, ChapterTextController) -> NSMenu?
    /// A reader key beyond the text (`ReaderKeyCommands.perform`), with the selection it acts on;
    /// false leaves the key to the text view.
    public var onKey: (ReaderKeyAction, SelectionReport?, ChapterTextController) -> Bool
    /// Whether the reader's keys act at all (`ReaderKeyCommands.keysAreLive`), asked at each key,
    /// J, K, ⇧J, ⇧K and Esc included; false swallows the key.
    public var keysAreLive: () -> Bool

    public init(
        decorations: BookDecorations,
        onSelectionChange: @escaping (SelectionReport?) -> Void,
        menuProvider: @escaping (SelectionReport, ChapterTextController) -> NSMenu?,
        onKey: @escaping (ReaderKeyAction, SelectionReport?, ChapterTextController) -> Bool = { _, _, _ in false },
        keysAreLive: @escaping () -> Bool = { true }
    ) {
        self.decorations = decorations
        self.onSelectionChange = onSelectionChange
        self.menuProvider = menuProvider
        self.onKey = onKey
        self.keysAreLive = keysAreLive
    }
    #else
    public init(decorations: BookDecorations, onSelectionChange: @escaping (SelectionReport?) -> Void) {
        self.decorations = decorations
        self.onSelectionChange = onSelectionChange
    }
    #endif
}

/// The chapter being read as a page (a `ReaderDocument`'s one chapter), with the running head
/// pinned over its top: the chapter in the page style's label voice, its note mark, and the
/// progress line under it. The chapter's opening line carries its own note mark in the text.
/// The chapter's foot offers the chapter before and after ("Previous: Psalm 72", "Next: Psalm
/// 74", the neighbouring book's at either end) in space kept for them under the text, shown as
/// that space scrolls into view; nothing shows above the top. Head, line and footer share the
/// text column's measure.
public struct ReaderView: View {
    let document: ReaderDocument
    let scrollTarget: ScrollTarget?
    /// The reading position as the reader scrolls (the first visible verse).
    let onReadingPositionChange: (VerseLocation) -> Void
    /// How far the page has scrolled since the last jump landed, in lines of body text.
    let onScrollSinceJump: (Double, ScrollTarget) -> Void
    /// A plain click on the running head: back to this book's chapter grid, as other Bible readers do.
    let onHeadingTap: () -> Void
    /// With it set, the running head's context menu offers "Ask About This Chapter".
    let onAskAboutChapter: (() -> Void)?
    /// The chapter before's name ("Psalm 72"; at a book's first chapter, the book before's last);
    /// nil at the translation's first chapter.
    let previousChapterTitle: String?
    let onPreviousChapter: () -> Void
    /// The chapter after's name ("Psalm 74"; at a book's last chapter, the next book's first);
    /// nil at the translation's last chapter.
    let nextChapterTitle: String?
    let onNextChapter: () -> Void
    let typography: ReaderTypography
    let markup: ReaderMarkup?
    /// The chapter's number of chapter notes, by chapter (a chapter without any may be left out).
    let chapterNoteCounts: [Int: Int]
    /// A click on the chapter-note mark (in the text or the head), with its chapter: show the
    /// notes column on that chapter, where the chapter notes come first.
    let onShowChapterNotes: (Int) -> Void
    /// The book thumb at the reader's right edge (`NavigationModel.bookThumb`); nil, or a
    /// one-chapter book, shows none.
    let bookThumb: BookThumb?
    /// Letting go of the thumb on another chapter, with its number: open it at its start.
    let onThumbLand: (Int) -> Void
    /// Asks the reader's text to take keyboard focus (`ReaderFocusRule`); a new request each time.
    let focusRequest: ReaderFocusRequest?
    /// A verse panel in a popover on its selection's first line (the Mac); nil closes it.
    let versePanel: VersePanelPresentation?
    /// The chapter under the thumb's drag, while there is one.
    @State private var thumbDragging: Int? = ReaderView.debugThumbChapter
    /// The page behind the thumb's loupe, which the text controller draws for it.
    @State private var backdrop = PageBackdrop()
    #if os(macOS)
    /// Follows System Settings' "Show scroll bars".
    @State private var scrollerWidth = Self.thumbTrailingInset
    #endif
    /// The controller's reports as the page scrolls: the running head (its progress and opacity)
    /// and how much of the space reserved under the chapter's text is in view. They change on
    /// nearly every frame, so they are read only by the small views that draw them, never by this
    /// view's `body`: a scroll re-evaluates the progress line, not the reader.
    @State private var chrome = ReaderChrome()
    /// The links' height as `ChapterEndLinks` lays them out across the column now: one row side
    /// by side, two when they stack. Measured from a hidden copy, so it follows the width, the
    /// titles and the text size; 0 until measured.
    @State private var linksHeight: CGFloat = 0

    public init(
        document: ReaderDocument,
        scrollTarget: ScrollTarget?,
        onReadingPositionChange: @escaping (VerseLocation) -> Void,
        onScrollSinceJump: @escaping (Double, ScrollTarget) -> Void = { _, _ in },
        onHeadingTap: @escaping () -> Void,
        onAskAboutChapter: (() -> Void)? = nil,
        previousChapterTitle: String?,
        onPreviousChapter: @escaping () -> Void,
        nextChapterTitle: String?,
        onNextChapter: @escaping () -> Void,
        typography: ReaderTypography = .default,
        markup: ReaderMarkup? = nil,
        chapterNoteCounts: [Int: Int] = [:],
        onShowChapterNotes: @escaping (Int) -> Void = { _ in },
        bookThumb: BookThumb? = nil,
        onThumbLand: @escaping (Int) -> Void = { _ in },
        focusRequest: ReaderFocusRequest? = nil,
        versePanel: VersePanelPresentation? = nil
    ) {
        self.document = document
        self.scrollTarget = scrollTarget
        self.onReadingPositionChange = onReadingPositionChange
        self.onScrollSinceJump = onScrollSinceJump
        self.onHeadingTap = onHeadingTap
        self.onAskAboutChapter = onAskAboutChapter
        self.previousChapterTitle = previousChapterTitle
        self.onPreviousChapter = onPreviousChapter
        self.nextChapterTitle = nextChapterTitle
        self.onNextChapter = onNextChapter
        self.typography = typography
        self.markup = markup
        self.chapterNoteCounts = chapterNoteCounts
        self.onShowChapterNotes = onShowChapterNotes
        self.bookThumb = bookThumb
        self.onThumbLand = onThumbLand
        self.focusRequest = focusRequest
        self.versePanel = versePanel
    }

    #if os(macOS)
    /// The thumb's inset from the reader's trailing edge: the vertical scroller's width in the
    /// style the system prefers, so the thumb sits just inside the scroller.
    static var thumbTrailingInset: CGFloat {
        NSScroller.scrollerWidth(for: .regular, scrollerStyle: NSScroller.preferredScrollerStyle)
    }
    #endif

    /// The chapter's links show as the space reserved for them under its text comes into view
    /// (`reveal`, from the text controller), so they never lie over the text; only when there
    /// is a link to show.
    static func footOpacity(reveal: Double, hasLinks: Bool) -> Double {
        hasLinks ? min(max(reveal, 0), 1) : 0
    }

    /// The links take clicks and VoiceOver once they are more than half shown.
    static func footIsLive(opacity: Double) -> Bool { opacity > 0.5 }

    /// The footer's height (`ChapterEndLinks`): one line of its text style with `sm` above and
    /// below.
    static var footHeight: CGFloat {
        let font = PlatformFont.preferredFont(forTextStyle: ChapterEndLinks.platformTextStyle)
        return ceil(font.ascender - font.descender + font.leading) + 2 * AppSpacing.sm
    }

    /// The space every chapter keeps under its text: the links' height as laid out (`linksHeight`,
    /// two rows when they stack), and at least one row (`footHeight`) before they are measured,
    /// when the chapter has a link; so the links, laid over the scroll's foot, never cover the
    /// last line and showing them never changes the scroll's geometry.
    static func bottomInset(hasLinks: Bool, linksHeight: CGFloat = 0) -> CGFloat {
        hasLinks ? max(footHeight, ceil(linksHeight)) : 0
    }

    private var hasLinks: Bool { previousChapterTitle != nil || nextChapterTitle != nil }

    /// The foot's height for the links as they lie now.
    private var footSpace: CGFloat { Self.bottomInset(hasLinks: hasLinks, linksHeight: linksHeight) }

    #if DEBUG
    /// How many times `body` has been evaluated, in debug builds only: the scroll benchmark checks
    /// that scrolling re-evaluates the head's small views and never the reader.
    @MainActor static var bodyEvaluations = 0
    #endif

    public var body: some View {
        #if DEBUG
        let _ = Self.bodyEvaluations += 1
        #endif
        chapterText
            // The links as they would lie across the column, never drawn: their height is what
            // the foot keeps under the text.
            .background(alignment: .bottom) {
                if hasLinks {
                    links
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { linksHeight = $0 }
                        .hidden()
                        .accessibilityHidden(true)
                }
            }
            .overlay(alignment: .top) {
                if let layout = document.layout {
                    runningHead(layout)
                }
            }
            .overlay(alignment: .bottom) {
                ChapterFootReveal(chrome: chrome, hasLinks: hasLinks, footSpace: footSpace) { footer }
            }
            #if os(macOS)
            .overlay(alignment: .trailing) { thumb }
            #endif
            .background(Color.paperPage)
            #if os(macOS)
            // System Settings' "Show scroll bars" changes the scroller's width.
            .onReceive(NotificationCenter.default.publisher(for: NSScroller.preferredScrollerStyleDidChangeNotification)) { _ in
                scrollerWidth = Self.thumbTrailingInset
            }
            #endif
        // Another book: the head waits for the new text's first report rather than naming a
        // chapter of the old one.
        .onChange(of: document.layout?.id.book) { _, _ in
            chrome.bookChanged()
        }
        // New text (another chapter, translation or size): the old text's foot does not offer
        // the new one's links; the controller reports the new reveal afresh.
        .onChange(of: document.layout?.id) { _, _ in
            chrome.textChanged()
        }
    }

    #if os(macOS)
    /// The book thumb at the reader's right edge, just inside the vertical scroller (beside the
    /// notes column when that is open), from under the running head to near the foot. None for
    /// a one-chapter book.
    @ViewBuilder
    private var thumb: some View {
        if let bookThumb, bookThumb.isShown {
            RevealedBookThumb(chrome: chrome, thumb: bookThumb, typography: typography,
                              dragging: $thumbDragging, onLand: onThumbLand)
                .environment(\.pageBackdrop, backdrop)
                .padding(.top, RunningHeadView.height(for: typography) + AppSpacing.xs)
                .padding(.bottom, AppSpacing.lg)
                .padding(.trailing, scrollerWidth)
        }
    }
    #endif

    private func runningHead(_ layout: BookLayout) -> some View {
        // The head's words alone: its opacity and progress are read from `chrome` inside it.
        let title = RunningHeadTitle(style: typography.style, book: layout.id.book, head: nil,
                                     chapter: layout.chapters.lowerBound)
        let chapter = title.chapter
        return RunningHeadView(
            text: title.text,
            spokenLabel: title.spokenLabel,
            typography: typography,
            chrome: chrome,
            chapter: chapter,
            noteCount: chapterNoteCounts[chapter] ?? 0,
            chapterName: "\(BookCatalog.book(code: layout.id.book)?.chapterName ?? layout.id.book) \(chapter)",
            onTap: onHeadingTap,
            onAskAboutChapter: onAskAboutChapter,
            onShowChapterNotes: { onShowChapterNotes(chapter) })
    }

    /// The end of the chapter, across the column: Previous at the leading edge, Next at the
    /// trailing edge. No rule; the page's own whitespace separates it.
    private var footer: some View {
        ChapterEndLinks(previousTitle: previousChapterTitle, nextTitle: nextChapterTitle,
                        onPrevious: onPreviousChapter, onNext: onNextChapter)
            .frame(maxWidth: typography.measure)
            // The space the text keeps for it: one row, or two when the links stack.
            .frame(height: footSpace)
            // On the page across the measure only: the text it may lie over is there, and the
            // scroller at the window's edge stays clear.
            .background(Color.paperPage)
            .padding(.horizontal, AppSpacing.xxl)
    }

    /// The footer's links across the column, as the footer lays them out, for measuring.
    private var links: some View {
        ChapterEndLinks(previousTitle: previousChapterTitle, nextTitle: nextChapterTitle,
                        onPrevious: {}, onNext: {})
            .frame(maxWidth: typography.measure)
            .padding(.horizontal, AppSpacing.xxl)
    }

    @ViewBuilder
    private var chapterText: some View {
        #if os(macOS)
        ChapterTextView(
            layout: document.layout,
            typography: typography,
            scrollTarget: scrollTarget,
            onReadingPositionChange: onReadingPositionChange,
            markup: markup,
            headLineY: RunningHeadView.stripHeight(for: typography),
            onRunningHeadChange: { [chrome] in chrome.report($0) },
            onScrollSinceJump: onScrollSinceJump,
            chapterNoteCounts: chapterNoteCounts,
            onShowChapterNotes: onShowChapterNotes,
            scrollerTopInset: RunningHeadView.height(for: typography),
            bottomInset: footSpace,
            onFootReveal: { [chrome] in chrome.reportFoot($0) },
            onThumbReveal: { [chrome] in chrome.reportThumbReveal($0) },
            backdrop: backdrop,
            focusRequest: focusRequest,
            versePanel: versePanel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #else
        ScrollView {
            Text(document.layout?.attributedString.string ?? "")
                .font(Font(typography.bodyFont))
                .foregroundStyle(Color.inkPrimary)
                .frame(maxWidth: typography.measure, alignment: .leading)
                .padding(AppSpacing.xxl)
        }
        #endif
    }
}

#if os(macOS)
/// The Mac's book thumb, revealed as the page reports (`ReaderChrome.thumbRevealed`, the
/// controller's `ThumbRevealTracker`). Only this view reads the reveal, so the scroll that brings
/// the track out (its first frame) and the linger that hides it re-evaluate it alone, not the reader.
struct RevealedBookThumb: View {
    let chrome: ReaderChrome
    let thumb: BookThumb
    let typography: ReaderTypography
    @Binding var dragging: Int?
    let onLand: (Int) -> Void

    var body: some View {
        BookThumbView(thumb: thumb, typography: typography, isRevealed: chrome.thumbRevealed,
                      dragging: $dragging, onLand: onLand)
    }
}
#endif

/// The chapter's foot links (`content`) as the space kept for them under the text scrolls into
/// view (`ReaderChrome.footReveal`): shown by the reveal, riding in with that space so they never
/// lie over the last line, and live once more than half shown. Only this view reads the reveal,
/// so the frames that bring the foot into view re-evaluate it alone, not the reader.
struct ChapterFootReveal<Content: View>: View {
    let chrome: ReaderChrome
    let hasLinks: Bool
    /// The space kept for the links under the text (`ReaderView.bottomInset`).
    let footSpace: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        let opacity = ReaderView.footOpacity(reveal: chrome.footReveal, hasLinks: hasLinks)
        if opacity > 0 {
            content
                .opacity(opacity)
                // Rides in with the space kept for it, so it never lies over the last line.
                .offset(y: (1 - opacity) * footSpace)
                // It follows the scroll, as the head does.
                .transaction { $0.animation = nil }
                .allowsHitTesting(ReaderView.footIsLive(opacity: opacity))
                .accessibilityHidden(!ReaderView.footIsLive(opacity: opacity))
        }
    }
}

/// The way on from a chapter's foot, on both apps: "Previous: Psalm 72" with `arrow.left`
/// leading, and "Next: Psalm 74" with `arrow.right` trailing (`TrailingIconLabelStyle`), plain
/// buttons with `sm` above and below (`ReaderView.footHeight`), Previous at the leading edge and
/// Next at the trailing one, or one above the other at the leading edge where they do not fit
/// side by side. The ⌥⌘ shortcuts are named in the Mac's help tags. The phone sets them in
/// `.callout` `ink.secondary`, under the text in the page's scroll. The Mac lays them
/// over the scroll's foot, where they are the only way on in a wide window of paper, so they
/// speak up: `.body` medium in the `accent`, the color of what can be followed.
struct ChapterEndLinks: View {
    let previousTitle: String?
    let nextTitle: String?
    let onPrevious: () -> Void
    let onNext: () -> Void

    #if os(macOS)
    static let platformTextStyle = NSFont.TextStyle.body
    private static let font = Font.body.weight(.medium)
    private static let ink = Color.accent
    #else
    static let platformTextStyle = UIFont.TextStyle.callout
    private static let font = Font.callout
    private static let ink = Color.inkSecondary
    #endif

    var body: some View {
        // Side by side where they fit; where they do not (a phone, two long names), side by side
        // still without "Previous:" and "Next:", which the arrows already say (Matt, 2026-11-13:
        // "why are these on different lines?"); only then one above the other at the leading edge.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.md) {
                previousLink(named: true)
                Spacer(minLength: 0)
                nextLink(named: true)
            }
            HStack(spacing: AppSpacing.md) {
                previousLink(named: false)
                Spacer(minLength: 0)
                nextLink(named: false)
            }
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                previousLink(named: true)
                nextLink(named: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.plain)
        .font(Self.font)
        .foregroundStyle(Self.ink)
    }

    /// The link back; `named` says "Previous:" before the chapter. VoiceOver always hears it.
    @ViewBuilder
    private func previousLink(named: Bool) -> some View {
        if let previousTitle {
            Button(action: onPrevious) {
                Label(named ? "Previous: \(previousTitle)" : previousTitle, systemImage: "arrow.left")
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .padding(.vertical, AppSpacing.sm)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Previous: \(previousTitle)")
            #if os(macOS)
            .help("Previous Chapter (⌥⌘←)")
            #endif
        }
    }

    /// The link on; `named` says "Next:" before the chapter. VoiceOver always hears it.
    @ViewBuilder
    private func nextLink(named: Bool) -> some View {
        if let nextTitle {
            Button(action: onNext) {
                Label(named ? "Next: \(nextTitle)" : nextTitle, systemImage: "arrow.right")
                    .labelStyle(.trailingIcon)
                    .lineLimit(1)
                    .padding(.vertical, AppSpacing.sm)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Next: \(nextTitle)")
            #if os(macOS)
            .help("Next Chapter (⌥⌘→)")
            #endif
        }
    }
}

extension ReaderView {
    /// Debug builds only: a chapter to show the thumb's loupe on from launch, as if the thumb
    /// were held there (`defaults write … DebugThumbChapter -int 4`), so the loupe can be looked
    /// at in a picture of the window without a drag. Nil in Release, and when unset.
    static var debugThumbChapter: Int? {
        #if DEBUG
        UserDefaults.standard.object(forKey: "DebugThumbChapter") as? Int
        #else
        nil
        #endif
    }
}
