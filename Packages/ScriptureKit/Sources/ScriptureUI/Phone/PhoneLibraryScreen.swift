#if os(iOS)
import SafariServices
import ScriptureData
import SwiftUI

/// Library, over the page: Old Testament and New Testament over the books of one, each a plain
/// row; a tapped book opens under its name (one book at a time) its reference icons and its
/// chapters, a book of one chapter included. It opens on the book being read, open with its
/// chapter on the wash. Choosing a chapter reads it, so it moves the place being read and ends a lookup, and
/// Library closes. The decisions are `LibraryList`'s; this view draws them. It is the screen to the
/// left of Read: the root slides it in and out (`PhoneLibraryLayer`).
///
/// A book's People, Places and About are pages pushed inside it (`PhoneLibraryPageView`). Its path
/// starts as the Library's place (`navigation.libraryPlace`), so a way back from a lookup reopens it
/// on its page, and each push or pop writes the place back. Places' own pages are pushed inside its
/// sheet, so Library's stack shows the path only as far as Places.
public struct PhoneLibraryScreen: View {
    private let navigation: NavigationModel
    private let markup: MarkupModel
    private let shell: PhoneShellModel
    private let onClose: () -> Void
    @State private var list: LibraryList
    /// Every page pushed, Places' sheet's included.
    @State private var path: [PhoneLibraryPage]
    @State private var memory: PhoneLibraryPageMemory
    /// The chapter rings. The holder SwiftUI keeps is the first one made; it queries on its first
    /// read, before any cell is built, so there is one query per opening (the holders later inits
    /// make are dropped unread). Setting the marks on appearance instead left the first-built
    /// cells without their ring.
    @State private var marks: MarkedChapters
    /// A BibleProject video being watched, in a Safari sheet over Library.
    @State private var video: BookVideo?

    /// - Parameter onClose: closes Library: Close, and after a chosen chapter is opened.
    public init(navigation: NavigationModel, markup: MarkupModel, shell: PhoneShellModel, onClose: @escaping () -> Void) {
        self.navigation = navigation
        self.markup = markup
        self.shell = shell
        self.onClose = onClose
        _list = State(initialValue: LibraryList(navigation: navigation))
        _marks = State(initialValue: MarkedChapters(markup: markup))
        _path = State(initialValue: navigation.libraryPlace?.pages ?? [])
        _memory = State(initialValue: PhoneLibraryPageMemory(opening: navigation.libraryPlace))
    }

    /// The path as Library's own stack shows it: up to Places, whose pages are in its sheet. A pop
    /// on it drops the sheet's pages with Places.
    private var stackPath: Binding<[PhoneLibraryPage]> {
        Binding(
            get: { Self.stackPages(of: path) },
            set: { pages in
                if pages != Self.stackPages(of: path) { path = pages }
            })
    }

    nonisolated static func stackPages(of path: [PhoneLibraryPage]) -> [PhoneLibraryPage] {
        guard let places = path.firstIndex(where: { if case .topic(_, .places) = $0 { true } else { false } }) else { return path }
        return Array(path[...places])
    }

    /// The row to bring into view: the open book, else the book being read, when this testament has it.
    private func anchorBookID(in shown: [TranslationBook]) -> String? {
        [list.openBookID, list.readingBookID].compactMap { $0 }.first { id in shown.contains { $0.book.id == id } }
    }

    public var body: some View {
        NavigationStack(path: stackPath) {
            ScrollViewReader { proxy in
                ScrollView {
                    // Not lazy: a lazy stack places unbuilt rows by estimate, so a jump to a book
                    // (on opening, or on switching testament) lands short at large text sizes.
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(list.shownSections, id: \.group) { section in
                            GroupLabel(section.group.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, AppSpacing.lg)
                                .padding(.top, AppSpacing.md)
                                .padding(.bottom, AppSpacing.xxs)
                            ForEach(section.books, id: \.book.id) { entry in
                                bookRow(entry)
                                    .id(entry.book.id)
                                // A hairline between rows, none after a group's last.
                                if entry.book.id != section.books.last?.book.id { Divider() }
                            }
                        }
                    }
                }
                .background(Color.paperPage)
                // A bar of the system's, so the list scrolls under it with the bar's edge effect.
                .safeAreaBar(edge: .top, spacing: 0) {
                    Picker("Testament", selection: $list.testament) {
                        ForEach(LibraryList.Testament.allCases, id: \.self) { testament in
                            Text(testament.title).tag(testament)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.xs)
                }
                // The other testament starts at its open or marked book if it has one, else at its first.
                .onChange(of: list.testament) {
                    let shown = list.shownBooks
                    if let id = anchorBookID(in: shown) ?? shown.first?.book.id { proxy.scrollTo(id, anchor: .top) }
                }
                .onAppear {
                    guard let id = anchorBookID(in: list.shownBooks) else { return }
                    proxy.scrollTo(id, anchor: .top)
                    // The bar's inset is not applied at appearance; placed again once it is.
                    Task { @MainActor in
                        await Task.yield()
                        proxy.scrollTo(id, anchor: .top)
                    }
                }
            }
            .sheet(item: $video) { video in
                SafariSheet(url: video.url).ignoresSafeArea()
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", action: onClose)
                }
            }
            .navigationDestination(for: PhoneLibraryPage.self) { page in
                PhoneLibraryPageView(page: page, navigation: navigation, shell: shell, path: $path)
            }
        }
        .environment(memory)
        .onChange(of: path) { navigation.libraryPlace = memory.place(for: path) }
    }

    /// The book's name as a full-width plain button, and under it, when it is open, its
    /// reference icons and its chapters.
    private func bookRow(_ entry: TranslationBook) -> some View {
        let id = entry.book.id
        let isOpen = list.openBookID == id
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                list.tap(bookID: id)
            } label: {
                Text(entry.book.name)
                    .font(.body)
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
            if isOpen {
                BookReferenceRow(bookCode: id, bookName: entry.book.name, availableTopics: Self.topics(of: entry.book), activeTopic: nil,
                                 onOpenTopic: { path.append(.topic(book: id, $0)) }) { video = $0 }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.sm)
                LibraryChapterGrid(
                    chapterCount: entry.chapterCount,
                    currentChapter: navigation.location?.book == id ? navigation.location?.chapter : nil,
                    marks: marks.byBook[id] ?? [:]
                ) { chapter in
                    read(ChapterLocation(book: id, chapter: chapter))
                }
            }
        }
    }

    /// People, Places and About for the 66; the Apocrypha has none.
    nonisolated static func topics(of book: Book) -> Set<LibraryTopic> {
        book.canon == .apocrypha ? [] : Set(LibraryTopic.allCases)
    }

    private func read(_ location: ChapterLocation) {
        navigation.open(location)
        onClose()
    }
}

/// A web page in Safari's own sheet, inside the app.
private struct SafariSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safari = SFSafariViewController(url: url)
        safari.preferredControlTintColor = Palette.accent.platformColor
        return safari
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// The marked chapters and their colours by book, read from the store on first use.
@MainActor
private final class MarkedChapters {
    private let markup: MarkupModel
    private(set) lazy var byBook: [String: [Int: ChapterMarks]] =
        Dictionary(grouping: markup.chapterMarks(), by: \.key.book).mapValues { entries in
            Dictionary(uniqueKeysWithValues: entries.map { ($0.key.chapter, $0.value) })
        }

    init(markup: MarkupModel) { self.markup = markup }
}

/// An open book's chapter cells, as many across as fit at the current text size.
private struct LibraryChapterGrid: View {
    let chapterCount: Int
    let currentChapter: Int?
    let marks: [Int: ChapterMarks]
    let onSelect: (Int) -> Void
    @ScaledMetric(relativeTo: .title3) private var cellWidth: CGFloat = 56

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: cellWidth, maximum: cellWidth), spacing: AppSpacing.xs)],
                  alignment: .leading, spacing: AppSpacing.xs) {
            ForEach(1...max(chapterCount, 1), id: \.self) { chapter in
                ChapterCell(chapter: chapter, isCurrent: chapter == currentChapter, marks: marks[chapter],
                            accessibilityName: "Chapter \(chapter)") {
                    onSelect(chapter)
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.md)
    }
}
#endif
