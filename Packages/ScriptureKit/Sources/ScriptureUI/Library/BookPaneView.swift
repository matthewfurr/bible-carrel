import ScriptureData
import SwiftUI

/// The contents page's trailing pane (spec 4.2): the chosen book's name in Display, its subtitle
/// in the page face's italic and the reference icon row stay put at the top; under them its
/// chapters, at the reader's page size and as many across as the pane holds, scroll on their own.
/// The open Library view's icon sits on the accent wash, so in a long book (Psalms) it is always
/// in sight. A chapter's cell opens it.
/// The front page sets the pane's width and its `paper.panel` ground.
public struct BookPaneView: View {
    let navigation: NavigationModel
    let book: TranslationBook
    let marks: [Int: ChapterMarks]
    let ringedChapter: Int?
    /// The cells' sizes at the reader's page size, and how many sit across the pane's width.
    let paneMetrics: ChapterPaneMetrics
    let gridColumns: Int
    /// The Library's views this book has, the one open, and what opens one.
    let availableTopics: Set<LibraryTopic>
    let activeTopic: LibraryTopic?
    let onOpenTopic: (LibraryTopic) -> Void
    /// Each change moves the keyboard to the grid (Return or Space on the contents).
    let focusRequests: Int

    @Environment(\.pageFace) private var pageFace
    /// A book's BibleProject video opens in the default browser.
    @Environment(\.openURL) private var openURL

    public init(navigation: NavigationModel, book: TranslationBook, marks: [Int: ChapterMarks], ringedChapter: Int?,
                paneMetrics: ChapterPaneMetrics, gridColumns: Int,
                availableTopics: Set<LibraryTopic> = [], activeTopic: LibraryTopic? = nil,
                onOpenTopic: @escaping (LibraryTopic) -> Void = { _ in }, focusRequests: Int = 0) {
        self.navigation = navigation
        self.book = book
        self.marks = marks
        self.ringedChapter = ringedChapter
        self.paneMetrics = paneMetrics
        self.gridColumns = gridColumns
        self.availableTopics = availableTopics
        self.activeTopic = activeTopic
        self.onOpenTopic = onOpenTopic
        self.focusRequests = focusRequests
    }

    public var body: some View {
        let id = book.book.id
        let name = book.book.name
        VStack(spacing: 0) {
            header(id: id, name: name)
            ScrollViewReader { proxy in
                ScrollView {
                    ChapterGridView(
                        bookName: name,
                        chapterCount: book.chapterCount,
                        currentChapter: navigation.location?.book == id ? navigation.location?.chapter : nil,
                        marks: marks,
                        ringedChapter: ringedChapter,
                        metrics: paneMetrics,
                        columnCount: gridColumns,
                        // The arrows can walk a tall grid (Psalms) past the pane; the cursor stays in view.
                        onRevealChapter: { chapter in
                            proxy.scrollTo(ChapterGridView.cellID(bookName: name, chapter: chapter))
                        },
                        focusRequests: focusRequests
                    ) { chapter in
                        navigation.open(ChapterLocation(book: id, chapter: chapter))
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    // Room for a searched first-row chapter's ring, which sits outside its cell;
                    // the scroll view would cut it at its top edge.
                    .padding(.top, paneMetrics.searchRingWidth)
                    .padding(.bottom, AppSpacing.lg)
                }
                .scrollIndicators(.automatic)
            }
        }
        // A new book is a new grid: its cursor starts again.
        .id(id)
    }

    /// The name, the subtitle and the icons: outside the scroll view, so they stay in sight.
    private func header(id: String, name: String) -> some View {
        VStack(spacing: 0) {
            Text(name)
                .font(pageFace.displayFont())
                .foregroundStyle(Color.inkPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            if let subtitle = navigation.bookSubtitle(id) {
                Text(subtitle)
                    .font(pageFace.swiftUIFont(.callout, italic: true))
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, AppSpacing.xxs)
            }
            // The icons sit `xs` under the name and `sm` over the grid (spec 5.2).
            BookReferenceRow(
                bookCode: id, bookName: name, availableTopics: availableTopics, activeTopic: activeTopic,
                onOpenTopic: onOpenTopic, onOpenVideo: { video in openURL(video.url) })
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.md)
        .padding(.horizontal, AppSpacing.sm)
    }
}
