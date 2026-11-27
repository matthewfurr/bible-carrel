#if os(macOS)
import AppKit
import ScriptureData
import ScriptureModel
import SwiftUI
@testable import ScriptureUI

/// The Mac's reader as `MainWindowView` hosts it on the reader screen, built from the package's
/// own models as `AppModels` builds them: a `NavigationModel` on the store, a `MarkupModel` on an
/// in-memory markup store, and one `ReaderDocument`. `ReaderView` gets the same inputs and
/// closures the window gives it (the scroll target, the reading position and the scroll since a
/// jump reported to navigation, the chapter's neighbours for the foot links, the markup's
/// decorations and selection, the chapter-note counts, the book thumb), and the host reads the
/// window title (`chapterTitle`) and follows the open chapter into the document and the markup
/// as the window does. Left out: the toolbar, the ⌘K palette and the notes column's inspector
/// (it needs the assistant), none of which a scroll changes.
struct BenchmarkReaderHost: View {
    @Bindable var navigation: NavigationModel
    @Bindable var markup: MarkupModel
    let document: ReaderDocument
    let typography: ReaderTypography
    /// Each evaluation of `body`, for the test to count.
    var onBody: () -> Void = {}

    private var chapterNoteCounts: [Int: Int] {
        guard let id = document.layout?.id, markup.book == id.book, markup.translationID == id.translationID else { return [:] }
        return markup.notesByChapter.compactMapValues { notes in
            let count = notes.count { $0.isChapterNote }
            return count > 0 ? count : nil
        }
    }

    var body: some View {
        let _ = onBody()
        ReaderView(
            document: document,
            scrollTarget: navigation.scrollTarget,
            onReadingPositionChange: { navigation.reportReadingPosition($0) },
            onScrollSinceJump: { navigation.reportLinesScrolledSinceJump($0, from: $1) },
            onHeadingTap: { navigation.goHome() },
            onAskAboutChapter: {},
            previousChapterTitle: navigation.previousChapter.map(navigation.title(for:)),
            onPreviousChapter: { navigation.goToPreviousChapter() },
            nextChapterTitle: navigation.nextChapter.map(navigation.title(for:)),
            onNextChapter: { navigation.goToNextChapter() },
            typography: typography,
            markup: ReaderMarkup(
                decorations: markup.bookDecorations,
                onSelectionChange: { markup.setSelection($0) },
                menuProvider: { _, _ in nil }),
            chapterNoteCounts: chapterNoteCounts,
            onShowChapterNotes: { markup.showChapterNotes(chapter: $0) },
            bookThumb: navigation.bookThumb,
            onThumbLand: { chapter in
                guard let book = navigation.location?.book else { return }
                navigation.open(ChapterLocation(book: book, chapter: chapter))
            })
        .navigationTitle(navigation.chapterTitle ?? "Bible Carrel")
        .onChange(of: navigation.location, initial: true) { _, location in
            guard let book = navigation.bookText, let location, location.book == book.book else { return }
            document.show(book, target: location, typography: typography)
            markup.follow(location, in: document.layout)
        }
    }
}
#endif

