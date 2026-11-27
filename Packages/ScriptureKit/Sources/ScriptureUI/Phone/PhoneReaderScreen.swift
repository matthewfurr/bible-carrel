#if os(iOS)
import ScriptureData
import SwiftUI

/// The Read tab: the chapter being read on its page, under a toolbar with the library (or the
/// way back from a lookup), the running head (the open chapter in the page style's voice, the
/// translation under it and the chapter's progress line), the highlighter and a menu. The bar's
/// title is the running head, so the phone draws no strip of its own: it is hidden while the
/// chapter's opening is on screen and appears as the opening scrolls under the bar. The
/// chapter's foot carries its links, "Previous: John 2" and "Next: John 4", which cross into
/// the neighbouring book at either end.
///
/// The book thumb (spec 3.3 and 4.4) lies along the page's right edge, in place of the hidden
/// scroll indicator: a long press there (the text view's, `PhoneChapterTextController.onThumb`)
/// shows the track with the chapter under the finger in the loupe, the grab and each chapter
/// passed are felt (`ThumbHaptics`), and letting go on another chapter opens it at its start (a
/// history entry, as any chapter chosen). VoiceOver reaches it as one adjustable element at that
/// edge.
///
/// The chapter switcher (`ChapterSwitcher`, Matt 2026-11-13; it replaced the carry-through
/// drawer of spec 3.2 and 4.3) is a stack of chapter cards kept inside the page's scroll, past
/// its foot and above its top. Pulling past either end brings them into the space that opens,
/// and letting go past the threshold leaves the page resting there with the cards in view:
/// nothing is laid over the text. A flick on the cards moves through the chapters that way; a
/// tap on the front card turns to its chapter through the history
/// (`NavigationModel.turn(to:atEnd:)`); a tap on the page sends the cards away. The page's text
/// controller owns all of that (`PhoneChapterTextController.openSwitcher`); this screen gives the
/// switcher the book, and closes it when another screen, a sheet or the pen comes up. It never
/// shows while VoiceOver runs. Its state (`ChapterSwitcherModel`) is read only by the cards, so
/// a pull redraws them and never this screen.
public struct PhoneReaderScreen: View {
    private let navigation: NavigationModel
    /// The chapter being read, laid out with its opening. Made once by the app, so recreating
    /// this view never rebuilds it.
    private let document: ReaderDocument
    private let markup: MarkupModel
    private let assistant: AssistantModel
    @Bindable private var shell: PhoneShellModel
    @Environment(\.undoManager) private var undoManager
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Classic's later labels and running head are at the headline size, which the typography
    /// captures when it is made: a new Dynamic Type size makes a new one.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(ReaderSettings.fontSizeKey) private var fontSize = ReaderSettings.defaultFontSize
    @AppStorage(ReaderSettings.lineSpacingKey) private var lineSpacing: LineSpacingChoice = .normal
    @AppStorage(ReaderSettings.pageStyleKey) private var pageStyle: PageStyle = .printed
    @AppStorage(ReaderSettings.pageFaceKey) private var pageFace = ""
    @AppStorage(ReaderSettings.columnWidthKey) private var columnWidth: ColumnWidthChoice = .normal
    @AppStorage(ReaderSettings.verseLayoutKey) private var verseLayout: VerseLayoutChoice = .paragraphs
    @AppStorage(ReaderSettings.showsVerseNumbersKey) private var showsVerseNumbers = true
    @AppStorage(ReaderSettings.showsSectionHeadingsKey) private var showsSectionHeadings = true
    @AppStorage(ReaderSettings.justifiedKey) private var justified = false
    /// This iPhone's own; the app applies it to every window.
    @AppStorage(ReaderSettings.appearanceKey) private var appearance: AppearanceChoice = .system
    /// Made once per setting, not per evaluation: on iOS a palette color is a new dynamic `UIColor`
    /// each time it is made, and those compare unequal, so a freshly made typography never equals
    /// the last one and the text view would lay the chapter out again on every update.
    @State private var typography: ReaderTypography
    /// The pen, made once for the screen.
    @State private var pen: PenModel
    /// A row chosen in Notes in This Chapter, opened once that sheet has gone.
    @State private var chosenRow: NotesColumnItem?
    /// Ask from the selection or the pen: the conversation over the page.
    @State private var isAskSheetShown = false
    /// From its presentation until its dismissal has finished, so the note sheet (Add as Note)
    /// waits for it rather than presenting over it.
    @State private var isAskSheetOnScreen = false
    /// Ask chosen while another sheet was up: shown once that sheet has gone.
    @State private var isAskQueued = false
    /// The page's running head. Only the bar title's fade and progress line read it, so a scroll
    /// redraws the line and never this screen, its toolbar or the title's words.
    @State private var chrome = ReaderChrome()
    /// The navigation bar's bottom below the page's top (the text runs under the bars): the head's
    /// line, where the bar title names the chapter in view. Zero until measured.
    @State private var barBottom: CGFloat = 0
    /// The chapter under the thumb's press, while there is one.
    @State private var thumbDragging: Int?
    /// The thumb's press, while it goes on: the chapter it began on and whether it has left it.
    @State private var thumbPress: PhoneThumbScrub.Press?
    /// The thumb's track in the window's coordinates, where the press's heights are.
    @State private var thumbTrack: CGRect = .zero
    /// The press's haptics, made ready as it begins: a firm tap as the thumb is grabbed, a crisp
    /// one for each chapter passed (Matt, 2026-11-13: the selection tick was too faint to feel).
    @State private var thumbHaptics: ThumbHaptics?
    /// The chapter switcher's state, written by the page's text controller and read only by its
    /// cards (hosted inside the page's scroll), so a pull never re-runs `body`.
    @State private var switcher = ChapterSwitcherModel()
    /// The page behind the thumb's loupe, which the text controller draws for it.
    @State private var backdrop = PageBackdrop()
    /// Where the bar's controls are, in the window: the leading button's label and the first of
    /// the trailing buttons' labels. The bar's title centres itself between them.
    @State private var barLeading: CGRect?
    @State private var barTrailing: CGRect?
    /// The menu's label: the first trailing button while VoiceOver hides the highlighter.
    @State private var barMenu: CGRect?
    /// Where the finger is on the thumb's ruler during its press; read only by the thumb.
    @State private var thumbPointer = ThumbPointer()

    public init(navigation: NavigationModel, document: ReaderDocument, markup: MarkupModel, assistant: AssistantModel,
                shell: PhoneShellModel) {
        self.navigation = navigation
        self.document = document
        self.markup = markup
        self.assistant = assistant
        self.shell = shell
        let defaults = UserDefaults.standard
        _typography = State(initialValue: ReaderSettings.typography(ReaderPreferences.load(from: defaults)))
        _pen = State(initialValue: PenModel(markup: markup))
    }

    /// The typography for `prefs` at the environment's Dynamic Type size.
    private func makeTypography(_ prefs: ReaderPreferences) -> ReaderTypography {
        ReaderSettings.typography(prefs, headlineSize: ReaderTypography.headlineSize(for: UIContentSizeCategory(dynamicTypeSize)))
    }

    /// The stored reading preferences, as the settings the page is laid out from.
    private var preferences: ReaderPreferences {
        ReaderPreferences(
            style: pageStyle, face: PageFace(rawValue: pageFace), fontSize: fontSize, lineSpacing: lineSpacing,
            columnWidth: columnWidth, layout: verseLayout, showsVerseNumbers: showsVerseNumbers,
            showsSectionHeadings: showsSectionHeadings, justified: justified)
    }

    /// What the markup model is loaded for; any change reloads it.
    private struct ChapterKey: Equatable {
        let location: ChapterLocation?
        let translationID: String
        let verses: [Verse]
    }

    private var chapterKey: ChapterKey {
        ChapterKey(location: navigation.location, translationID: navigation.translationID, verses: navigation.verses)
    }

    /// What the document shows: the book being read, the open chapter and the typography.
    /// `BookText`'s own `==` compares only the book and the translation, so this never compares
    /// verses. The document rebuilds when the book, translation, chapter or typography changes.
    private struct DocumentKey: Equatable {
        let book: BookText?
        let location: ChapterLocation?
        let typography: ReaderTypography
    }

    /// The book and translation the page shows; the pen's selection goes when they change.
    private struct BookKey: Equatable {
        let book: String?
        let translationID: String?
    }

    /// The markup is for the book and translation the document shows: between a new layout and
    /// the markup that follows it, the old book's marks would land on the new book's chapters.
    private var markupMatchesLayout: Bool {
        guard let id = document.layout?.id else { return false }
        return markup.book == id.book && markup.translationID == id.translationID
    }

    /// The chapter's chapter notes, by chapter, for the mark on the opening line.
    private var chapterNoteCounts: [Int: Int] {
        guard markupMatchesLayout else { return [:] }
        return markup.notesByChapter.compactMapValues { notes in
            let count = notes.count { $0.isChapterNote }
            return count > 0 ? count : nil
        }
    }

    #if DEBUG
    /// How many times `body` has been evaluated, in debug builds only, as `ReaderView`'s: the
    /// iOS suite checks that the page's scroll reports and the drawer's deck never re-run it.
    @MainActor static var bodyEvaluations = 0
    #endif

    public var body: some View {
        #if DEBUG
        let _ = Self.bodyEvaluations += 1
        #endif
        NavigationStack {
            page(typography: typography)
                .background(Color.paperPage)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .toolbar {
                    if pen.isOn { PenBar(pen: pen, chips: markup.colorChips) }
                }
                // With the pen on, its colors take the tab bar's place.
                .toolbarVisibility(pen.isOn ? .hidden : .visible, for: .tabBar)
        }
        // ⌘[ and ⌘] with a hardware keyboard, as the Mac's Go menu. The tab view keeps this screen
        // alive behind the others, so they act only while Read shows.
        .background {
            Group {
                // During a Library lookup, Back returns to the Library page as the bar's button does.
                Button("Back") { shell.goBack(navigation) }
                    .keyboardShortcut("[", modifiers: .command)
                    .disabled(!navigation.canGoBack || shell.tab != .read)
                Button("Forward") { navigation.goForward() }
                    .keyboardShortcut("]", modifiers: .command)
                    .disabled(!navigation.canGoForward || shell.tab != .read)
            }
            .hidden()
        }
        .onChange(of: DocumentKey(book: navigation.bookText, location: navigation.location, typography: typography), initial: true) { _, key in
            guard let book = key.book, let location = key.location, location.book == book.book else { return }
            document.show(book, target: location, typography: key.typography)
        }
        // A new book, translation, chapter or typography: the chapter's markup, mapped onto the
        // new layout.
        .onChange(of: document.layout?.id, initial: true) { _, _ in markup.follow(navigation.location, in: document.layout) }
        // The pen stays on across books; its selection does not.
        .onChange(of: BookKey(book: document.layout?.id.book, translationID: document.layout?.id.translationID)) {
            pen.select(highlightID: nil)
        }
        // Another book: the bar title waits for the new text's report.
        .onChange(of: document.layout?.id.book) { chrome.bookChanged() }
        // The open chapter moved (a navigation; the page holds one chapter, so a scroll never
        // moves it): Notes in This Chapter and the assistant follow.
        .onChange(of: chapterKey, initial: true) { _, key in
            // A verse panel belongs to the verse it was asked on.
            shell.versePanel = nil
            if let location = key.location {
                markup.follow(location, in: document.layout)
            } else {
                // No chapter (the translation lacks it): an edit ends and the selection clears.
                markup.clear(translationID: key.translationID)
            }
            assistant.setLocation(key.location, translationID: key.translationID, verses: key.verses)
        }
        // A change to any reading preference (size, spacing, page style, face...) re-lays the chapter out; stay at the verse being read.
        .onChange(of: preferences) { _, prefs in
            typography = makeTypography(prefs)
            navigation.resumeReading()
        }
        .onChange(of: dynamicTypeSize) { _, _ in
            let made = makeTypography(preferences)
            guard made.headlineSize != typography.headlineSize || made.layoutHash != typography.layoutHash else { return }
            let relays = made.layoutHash != typography.layoutHash
            typography = made
            if relays { navigation.resumeReading() }
        }
        // The scene's undo manager, so a deleted highlight comes back with shake or a three-finger swipe.
        .onChange(of: undoManager, initial: true) { _, manager in
            markup.undoManager = manager
        }
        // The pen turns off when Library opens or the Read tab is left, and is not offered to VoiceOver.
        .onChange(of: shell.isLibraryShown) { _, shown in
            if shown { pen.turnOff() }
        }
        .onChange(of: shell.tab) { _, tab in
            if tab != .read { pen.turnOff() }
        }
        .onChange(of: voiceOverEnabled, initial: true) { _, enabled in
            if enabled { pen.turnOff() }
        }
        // Add Note and Edit Note (the selection menu's and the pen's) start editing a note: show it
        // in its editor.
        .onChange(of: markup.editorFocusRequest) {
            if let noteID = markup.editingNoteID, shell.noteSheet != noteID { shell.openNote(noteID, editing: true) }
        }
        .sheet(isPresented: isNoteSheetShown, onDismiss: showQueuedAsk) {
            if let noteID = shell.noteSheet {
                PhoneNoteSheet(noteID: noteID, markup: markup, startsEditing: shell.noteSheetStartsEditing).id(noteID)
            }
        }
        // Compare Translations and Cross-References, from the selection menu's two items.
        .sheet(item: $shell.versePanel, onDismiss: runQueuedVersePanelAsk) { request in
            PhoneVersePanelSheet(
                request: request, navigation: navigation,
                onOpen: { location, verse, translationID in
                    shell.versePanel = nil
                    navigation.lookUp(location, verse: verse, translationID: translationID)
                    // A compare row is a plain lookup; a passage from Cross-References is recorded
                    // in Recents as a reference in a note is.
                    if translationID == nil { navigation.recordLookup(location, verse: verse) }
                },
                onAsk: { comparison in
                    // Kept while the sheet goes; `runQueuedVersePanelAsk` runs it once it has.
                    shell.queuedVersePanelAsk = {
                        assistant.compareTranslations(comparison.selection, translationIDs: comparison.otherTranslationIDs)
                        shell.askSheetThreadID = nil
                        showAskSheet()
                    }
                    shell.versePanel = nil
                },
                onAskAboutThese: { references in
                    guard let selection = references.selection, let question = navigation.crossReferenceQuestion(references) else { return }
                    shell.queuedVersePanelAsk = {
                        assistant.ask(about: selection, sending: question, shownAs: CrossReferences.askTitle)
                        shell.askSheetThreadID = nil
                        showAskSheet()
                    }
                    shell.versePanel = nil
                })
            .id(request.id)
        }
        .sheet(isPresented: $shell.isChapterNotesShown, onDismiss: {
            openChosenRow()
            // The sheet's chapter goes back to the open one, should a mark have shown another (an
            // edit begun there keeps it until it ends).
            markup.follow(navigation.location, in: document.layout)
            showQueuedAsk()
        }) {
            PhoneChapterNotesSheet(markup: markup) { chosenRow = $0 }
        }
        .sheet(isPresented: $isAskSheetShown, onDismiss: {
            isAskSheetOnScreen = false
            shell.askSheetThreadID = nil
            // Open Settings in the sheet: shown now that the sheet has gone.
            if shell.isSettingsQueued {
                shell.isSettingsQueued = false
                shell.isSettingsShown = true
            }
        }) {
            NavigationStack {
                PhoneChatScreen(assistant: assistant, navigation: navigation, shell: shell, presentsVersePreview: true)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done", systemImage: "checkmark") { isAskSheetShown = false }
                        }
                    }
            }
            .presentationDetents([.large])
        }
        .onAppear {
            markup.onAskAboutPassage = { report in askOverPage(report) }
            markup.onVersePanel = { kind, report in shell.showVersePanel(VersePanelRequest(kind: kind, report: report)) }
        }
        // The conversation over the page, once its first message makes it one.
        .onChange(of: assistant.thread?.id) { _, id in
            if isAskSheetShown, let id { shell.askSheetThreadID = id }
        }
        // `showInReader` (Open in Read, Add as Note) closes it.
        .onChange(of: shell.askSheetThreadID) { old, new in
            if old != nil, new == nil { isAskSheetShown = false }
        }
    }

    /// What can come over the page: another tab or screen, a sheet, the pen or VoiceOver.
    private struct Covering: Equatable {
        let tab: PhoneTab
        let library: Bool
        let settings: Bool
        let note: Bool
        let chapterNotes: Bool
        let ask: Bool
        let versePreview: Bool
        let versePanel: Bool
        let pen: Bool
        let voiceOver: Bool
    }

    private var covering: Covering {
        Covering(tab: shell.tab, library: shell.isLibraryShown, settings: shell.isSettingsShown,
                 note: shell.noteSheet != nil, chapterNotes: shell.isChapterNotesShown, ask: isAskSheetShown,
                 versePreview: shell.versePreview != nil, versePanel: shell.versePanel != nil, pen: pen.isOn, voiceOver: voiceOverEnabled)
    }

    private var translationSelection: Binding<String> {
        Binding(get: { navigation.translationID }, set: { navigation.setTranslation($0) })
    }

    /// One step of the reader's size setting, held to the range Settings allows; the typography
    /// key re-lays the page out once.
    private func stepFontSize(by step: Double) {
        fontSize = ReaderSettings.clampedFontSize(ReaderSettings.clampedFontSize(fontSize) + step)
    }

    private var isNoteSheetShown: Binding<Bool> {
        Binding(get: { shell.noteSheet != nil && !isAskSheetOnScreen }, set: { if !$0 { shell.noteSheet = nil } })
    }

    /// Ask about the selection, in a sheet over the page; one sheet at a time, so a note or
    /// Notes in This Chapter goes first.
    private func askOverPage(_ report: SelectionReport) {
        assistant.ask(about: report)
        shell.askSheetThreadID = nil
        if shell.noteSheet != nil || shell.isChapterNotesShown {
            isAskQueued = true
            shell.noteSheet = nil
            shell.isChapterNotesShown = false
        } else {
            showAskSheet()
        }
    }

    /// The verse panel's Ask, run now that its sheet has gone.
    private func runQueuedVersePanelAsk() {
        guard let ask = shell.queuedVersePanelAsk else { return }
        shell.queuedVersePanelAsk = nil
        ask()
    }

    private func showQueuedAsk() {
        guard isAskQueued else { return }
        isAskQueued = false
        showAskSheet()
    }

    private func showAskSheet() {
        isAskSheetOnScreen = true
        isAskSheetShown = true
    }

    /// Notes in This Chapter for `chapter`: the open chapter's, from the menu or the mark on its
    /// opening line.
    private func showChapterNotes(chapter: Int?) {
        if let chapter { markup.showChapterNotes(chapter: chapter) }
        shell.isChapterNotesShown = true
    }

    /// Opens the chosen row's note, as the Mac column's edit does; a highlight without a note gets
    /// one, removed again if it is left empty. A row on a highlight first goes to it as a lookup
    /// (the way back showing, ended by reading on five lines), in the sheet's chapter; a chapter
    /// note leaves the page and the place being read where they are.
    private func openChosenRow() {
        guard let row = chosenRow else { return }
        chosenRow = nil
        let highlightID: UUID? = switch row {
        case .note(let card): card.highlightID
        case .compactHighlight(let compact): compact.id
        }
        if let highlightID, let verse = markup.items.first(where: { $0.id == highlightID })?.verse,
           let location = markup.chapter ?? navigation.location {
            navigation.lookUp(location, verse: verse)
        }
        if let highlightID { markup.focus(highlightID: highlightID) }
        switch row {
        case .note(let card) where card.isDraft:
            if let highlightID { markup.beginEditingDraft(highlightID: highlightID) }
        case .note(let card):
            // A note opens to read, as a tap on its mark does (spec 3.3).
            shell.openNote(card.id, editing: false)
        case .compactHighlight(let compact):
            markup.beginEditingDraft(highlightID: compact.id)
        }
    }

    @ViewBuilder
    private func page(typography: ReaderTypography) -> some View {
        if navigation.location != nil {
            PhoneChapterTextView(
                layout: document.layout,
                typography: typography,
                scrollTarget: navigation.scrollTarget,
                decorations: markup.bookDecorations,
                marginMarks: marginMarks,
                onReadingPositionChange: { navigation.reportReadingPosition($0) },
                headLineY: barBottom > 0 ? barBottom : nil,
                // Reports from a book since replaced are dropped on the way (`PhoneChapterTextView`).
                onRunningHeadChange: { [chrome] in chrome.report($0) },
                onScrollSinceJump: { navigation.reportLinesScrolledSinceJump($0, from: $1) },
                onSelectionChange: { markup.setSelection($0) },
                onSelectionDropped: { markup.forgetSelection() },
                onMarginMarkTap: { mark in
                    // A note's mark opens the note to read, as a tap on its highlight does.
                    if case .note(let noteID, _) = mark.kind { shell.openNote(noteID, editing: false) }
                },
                onOpenNote: { shell.openNote($0, editing: false) },
                chapterNoteCounts: chapterNoteCounts,
                onShowChapterNotes: { showChapterNotes(chapter: $0) },
                markup: markup,
                pen: pen,
                footer: footer,
                onThumb: thumbGesture,
                switcher: readiedSwitcher,
                backdrop: backdrop)
            // The text view is the scroll view: it runs under the bars, which follow it.
            .ignoresSafeArea()
            .overlay(alignment: .trailing) { thumb }
            // Anything coming over the page closes the switcher; it never shows while VoiceOver
            // runs (the foot's links and the thumb serve). A new size, another chapter or the
            // thumb's press close it in the text controller.
            .onChange(of: covering) { switcher.close() }
            .onChange(of: voiceOverEnabled, initial: true) { switcher.allow(!voiceOverEnabled) }
            // The bars' bottom below the page's top: the safe area the page reaches under.
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { barBottom = $0 }

            // A reader view recreated resumes at the last visible verse, as on the Mac.
            .onAppear { navigation.resumeReading() }
        } else {
            // Nothing read yet and no position from iCloud: one line on the paper says where to start.
            Text("Open Library to choose a chapter.")
                .font(.callout)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The book thumb at the page's right edge, from just under the bars to just above the tab
    /// bar (the overlay keeps to the safe area), centred in the press's edge zone. None for a
    /// one-chapter book. It takes no touches: the text view's press drives it, so a margin mark
    /// under it still gets its tap.
    @ViewBuilder
    private var thumb: some View {
        if let bookThumb = navigation.bookThumb, bookThumb.isShown {
            BookThumbView(thumb: bookThumb, typography: typography, isRevealed: false, dragging: $thumbDragging,
                          pointer: thumbPointer, onLand: landThumb)
                .environment(\.pageBackdrop, backdrop)
                // In the window's coordinates, as the press's heights are.
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { thumbTrack = $0 }
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.lg)
                .padding(.trailing, AppSpacing.xxs)
        }
    }

    /// The thumb's press: the chapter under the finger, a tap as it is grabbed and for each
    /// chapter passed, and on letting go the chapter landed on (`PhoneThumbScrub`): none for a
    /// press that never left the chapter it began on.
    private func thumbGesture(_ gesture: ThumbGesture) {
        guard let bookThumb = navigation.bookThumb, bookThumb.isShown else {
            thumbDragging = nil
            thumbPress = nil
            return
        }
        if case .began = gesture { thumbHaptics = ThumbHaptics() }
        let step = PhoneThumbScrub.step(gesture, dragging: thumbDragging, press: thumbPress, thumb: bookThumb, track: thumbTrack)
        if let haptic = step.haptic { thumbHaptics?.play(haptic) }
        // The loupe and the ruler's swell follow the finger itself, not the chapter's tick.
        switch gesture {
        case .began(let y), .moved(let y): thumbPointer.y = min(max(y - thumbTrack.minY, 0), thumbTrack.height)
        case .ended, .cancelled: thumbPointer.y = nil
        }
        thumbDragging = step.dragging
        thumbPress = step.press
        if step.dragging == nil { thumbHaptics = nil }
        if let chapter = step.landing { landThumb(on: chapter) }
    }

    /// Letting go of the thumb (or VoiceOver's double-tap) on another chapter: open it at its
    /// start, as any chapter chosen.
    private func landThumb(on chapter: Int) {
        guard let book = navigation.location?.book else { return }
        navigation.open(ChapterLocation(book: book, chapter: chapter))
    }

    // MARK: - The chapter switcher

    /// The switcher with the book as it is now: its chapters, the one being read, each chapter's
    /// opening words and where a tap on a card lands (a turn through the history, as the foot's
    /// links make). Handed to the page on every update; none of it is observed, so the page's
    /// reports never re-run this body.
    private var readiedSwitcher: ChapterSwitcherModel {
        let thumb = navigation.bookThumb
        // The books either side, by the chapter of each the switcher's last card opens: the
        // next book's first, the previous book's last, wherever in this book the reader is. (Not
        // the chapter next to the one being read, which is another book's only at this book's
        // own ends: with that, the stack stopped at the book's last chapter from anywhere before
        // it. Matt, 2026-11-13.)
        func end(_ neighbour: ChapterLocation?) -> ChapterSwitcher.BookEnd? {
            guard let neighbour else { return nil }
            return .init(book: neighbour.book, name: BookCatalog.book(code: neighbour.book)?.name ?? neighbour.book, chapter: neighbour.chapter)
        }
        switcher.show(book: navigation.location.map { "\($0.book) \(navigation.translationID)" },
                      chapters: thumb?.chapters ?? [], current: thumb?.current ?? 0,
                      previous: end(navigation.previousBookEnd), next: end(navigation.nextBook))
        // The stack runs on past this book through the books beyond it, chapter by chapter, in
        // reading order (Matt, 2026-11-13: it stopped at the next book's first chapter).
        switcher.cardsBeyond = { [navigation] edge in
            let books = navigation.books
            guard let here = navigation.location?.book, let index = books.firstIndex(where: { $0.book.id == here }) else { return [] }
            switch edge {
            case .bottom:
                return books[(index + 1)...].flatMap { entry in
                    (1...max(entry.chapterCount, 1)).map { ChapterSwitcher.BookEnd(book: entry.book.id, name: entry.book.name, chapter: $0) }
                }
            case .top:
                return books[..<index].reversed().flatMap { entry in
                    (1...max(entry.chapterCount, 1)).reversed().map { ChapterSwitcher.BookEnd(book: entry.book.id, name: entry.book.name, chapter: $0) }
                }
            }
        }
        switcher.openingVerses = { [document] in document.openingVerses(ofChapter: $0) }
        switcher.bookOpeningVerses = { [document, translation = navigation.translationID] in
            document.openingVerses(of: ChapterLocation(book: $0.book, chapter: $0.chapter), translationID: translation)
        }
        switcher.onLand = { [navigation] other, chapter, atEnd in
            guard let book = other ?? navigation.location?.book else { return }
            navigation.turn(to: ChapterLocation(book: book, chapter: chapter), atEnd: atEnd)
        }
        return switcher
    }

    /// Every margin mark of the chapter, on the document's layout.
    private var marginMarks: [MarginMark] {
        guard let layout = document.layout, markupMatchesLayout else { return [] }
        return MarginMark.build(notesByChapter: markup.notesByChapter, itemsByChapter: markup.itemsByChapter,
                                bookmarksByChapter: markup.bookmarksByChapter, layout: layout)
    }

    /// The chapter's foot, as on `main`: Previous at the leading edge and Next at the trailing
    /// edge (`ChapterEndLinks`, in `.callout` `ink.secondary`), one above the other where they do
    /// not fit side by side. Each crosses into the neighbouring book at either end ("Next: Acts 1"
    /// at John 21). None when there is nowhere to go.
    private var footer: AnyView? {
        let previous = navigation.previousChapter.map(navigation.title(for:))
        let next = navigation.nextChapter.map(navigation.title(for:))
        guard previous != nil || next != nil else { return nil }
        return AnyView(ChapterEndLinks(previousTitle: previous, nextTitle: next,
                                       onPrevious: { navigation.goToPreviousChapter() },
                                       onNext: { navigation.goToNextChapter() }))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if navigation.isLookingUp {
                // One begun in the Library reopens it on its page, or Search for a page reached by name.
                Button { shell.returnFromLookup(navigation) } label: {
                    // A plain stack: the bar draws a Label as its icon alone, even with the
                    // title-and-icon style, and the name (a chapter, a Library page) is the point of the button.
                    HStack(spacing: AppSpacing.xxs) {
                        Image(systemName: "chevron.left")
                        Text(navigation.lookupBackTitle ?? "")
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .accessibilityElement(children: .combine)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { barLeading = $0 }
                }
            } else {
                Button { shell.isLibraryShown = true } label: {
                    Label("Library", systemImage: "books.vertical")
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { barLeading = $0 }
                }
            }
        }
        ToolbarItem(placement: .principal) {
            if let book = document.layout?.id.book ?? navigation.location?.book {
                PhoneBarTitle(chrome: chrome, book: book,
                              chapter: document.layout?.chapters.lowerBound ?? navigation.location?.chapter ?? 1,
                              translation: navigation.translationID, typography: typography,
                              gap: voiceOverEnabled
                                ? PhoneBarTitle.gap(leading: barLeading, trailing: barMenu, trailingIsLone: true)
                                : PhoneBarTitle.gap(leading: barLeading, trailing: barTrailing))
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            // VoiceOver reaches every action through the selection menu instead.
            if !voiceOverEnabled {
                Button {
                    if pen.isOn { pen.turnOff() } else { pen.turnOn() }
                } label: {
                    Label("Highlighter", systemImage: "highlighter")
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { barTrailing = $0 }
                }
                .tint(pen.isOn ? Color.accent : nil)
                .accessibilityAddTraits(pen.isOn ? .isSelected : [])
            }
            Menu {
                // The page's own settings first; the rest live in Settings › Reading.
                // Each setting a row of buttons, as Text Size is (Matt, 2026-11-12); the chosen one
                // carries the menu's selection.
                Section("Page Style") {
                    Picker("Page Style", selection: $pageStyle) {
                        ForEach(PageStyle.allCases, id: \.self) { style in
                            Label { Text(style.title) } icon: { Image(uiImage: ReaderMenuGlyphs.pageStyle(style)) }
                                .tag(style)
                        }
                    }
                    .pickerStyle(.palette)
                }
                Section {
                    ControlGroup {
                        Button("Smaller", systemImage: "textformat.size.smaller") {
                            stepFontSize(by: -ReaderSettings.fontSizeStep)
                        }
                        .disabled(ReaderSettings.clampedFontSize(fontSize) <= ReaderSettings.fontSizeRange.lowerBound)
                        Button("Larger", systemImage: "textformat.size.larger") {
                            stepFontSize(by: ReaderSettings.fontSizeStep)
                        }
                        .disabled(ReaderSettings.clampedFontSize(fontSize) >= ReaderSettings.fontSizeRange.upperBound)
                    } label: {
                        Text("Text Size")
                    }
                    // The menu stays open, so the size can be stepped more than once.
                    .menuActionDismissBehavior(.disabled)
                }
                Section("Line Spacing") {
                    Picker("Line Spacing", selection: $lineSpacing) {
                        ForEach(LineSpacingChoice.allCases, id: \.self) { choice in
                            Label { Text(choice.title) } icon: { Image(uiImage: ReaderMenuGlyphs.lineSpacing(choice)) }
                                .tag(choice)
                        }
                    }
                    .pickerStyle(.palette)
                }
                // Light, Sepia and Dark only: following the system is a choice for Settings.
                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(ReaderMenuGlyphs.appearances, id: \.self) { choice in
                            Label(choice.title, systemImage: ReaderMenuGlyphs.symbol(for: choice)).tag(choice)
                        }
                    }
                    .pickerStyle(.palette)
                }
                Section {
                    Picker(selection: translationSelection) {
                        ForEach(navigation.translations) { translation in
                            Text(translation.title).tag(translation.id)
                        }
                    } label: {
                        Text("Translation")
                    }
                    .pickerStyle(.menu)
                    Button("Notes in This Chapter", systemImage: "note.text") {
                        showChapterNotes(chapter: navigation.location?.chapter)
                    }
                    if navigation.isLookingUp {
                        Button("Read From Here") { navigation.keepLookup() }
                    }
                    Button("Settings", systemImage: "gearshape") { shell.openSettings() }
                }
            } label: {
                Label("More", systemImage: "ellipsis")
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { barMenu = $0 }
            }
        }
    }
}

/// The bar title, read from the page's reports: the running head for the open chapter
/// (`RunningHeadTitle`, as the Mac's strip). Its words come from the chapter; only its fade and
/// progress line read `chrome`, so a scroll redraws the line alone.
struct PhoneBarTitle: View {
    let chrome: ReaderChrome
    /// The book the page shows (its code).
    let book: String
    /// The open chapter: the page's, else navigation's before the page has one.
    let chapter: Int
    let translation: String
    let typography: ReaderTypography
    /// The space between the bar's controls, as the window's x from the leading button's edge to
    /// the trailing buttons' (`gap(leading:trailing:)`); nil until both are known.
    var gap: ClosedRange<CGFloat>?

    #if DEBUG
    /// How many times `body` has been evaluated, in debug builds only: a scroll's head reports
    /// reach the fade and the progress line inside it, never this.
    @MainActor static var bodyEvaluations = 0
    #endif

    var body: some View {
        #if DEBUG
        let _ = Self.bodyEvaluations += 1
        #endif
        // The head's words alone: its opacity and progress are read from `chrome` inside it.
        let head = RunningHeadTitle(style: typography.style, book: book, head: nil, chapter: chapter)
        // Matt, 2026-11-13: the book and chapter are centred between the library button and the
        // buttons on the right, not on the screen. The bar hands its title a space of its own
        // that is centred on neither (it keeps more air before the trailing buttons than after
        // the leading one), so the title takes that space and places itself by where the
        // buttons themselves are: on the middle of the gap between them, as wide as the gap less
        // a little air at each end, shrinking to fit.
        let title = PhoneChapterTitle(title: head.text, spokenLabel: head.spokenLabel, translation: translation,
                                      chrome: chrome, chapter: chapter, typography: typography)
        // A hidden copy asks the bar for the title's height and all the width it has to give;
        // the title itself is laid over it, placed by where that space turned out to be.
        title
            .hidden()
            .accessibilityHidden(true)
            .frame(maxWidth: .infinity)
            .overlay {
                GeometryReader { proxy in
                    let slot = proxy.frame(in: .global)
                    let placing = Self.placing(slot: slot, gap: gap)
                    title
                        .frame(width: placing.width)
                        .position(x: placing.midX - slot.minX, y: proxy.size.height / 2)
                }
            }
            // The inline bar holds the stack only so far; past it, the large content viewer.
            .dynamicTypeSize(...PhoneBarTitleType.largestDynamicTypeSize)
            .accessibilityShowsLargeContentViewer {
                Text(head.text)
            }
    }
}

extension PhoneBarTitle {
    /// The air kept between the title and the button at either end of the gap.
    nonisolated static let air: CGFloat = AppSpacing.xs
    /// The system bar's glass around a button, measured on the iPhone (iOS 26): a lone button's
    /// is a 44 pt circle on its label's centre and reaches 9 pt past a wider label; a group's
    /// first button has 26 pt of it before its label's centre, 14 pt before a wider label.
    nonisolated static let loneButtonHalf: CGFloat = 22
    nonisolated static let loneButtonPad: CGFloat = 9
    nonisolated static let groupButtonHalf: CGFloat = 26
    nonisolated static let groupButtonPad: CGFloat = 14

    /// The space between the bar's controls, from the labels of the leading button and of the
    /// first trailing button (the window's coordinates): from the edge of the one's glass to the
    /// edge of the other's. The trailing button leads a group (the highlighter before the menu),
    /// or stands alone (`trailingIsLone`: the menu, while VoiceOver hides the highlighter). Nil
    /// until both are known and there is space between them.
    nonisolated static func gap(leading: CGRect?, trailing: CGRect?, trailingIsLone: Bool = false) -> ClosedRange<CGFloat>? {
        guard let leading, let trailing else { return nil }
        let from = max(leading.midX + loneButtonHalf, leading.maxX + loneButtonPad)
        let to = trailingIsLone
            ? min(trailing.midX - loneButtonHalf, trailing.minX - loneButtonPad)
            : min(trailing.midX - groupButtonHalf, trailing.minX - groupButtonPad)
        return from < to ? from...to : nil
    }

    /// Where the title goes, for the space `slot` the bar gives it and the `gap` between the
    /// bar's controls (the window's coordinates): on the gap's middle, as wide as the gap less
    /// the air at each end. Before the controls are known, the slot itself.
    nonisolated static func placing(slot: CGRect, gap: ClosedRange<CGFloat>?) -> (midX: CGFloat, width: CGFloat) {
        guard let gap else { return (slot.midX, slot.width) }
        return ((gap.lowerBound + gap.upperBound) / 2, max(gap.upperBound - gap.lowerBound - 2 * air, 0))
    }
}

/// The bar title's type: the page style's running-head voice (its face, weight, case, features,
/// tracking and color, `ReaderTypography.runningHead*`) at a Dynamic Type size, as chrome is set.
/// Printed's and Study's small labels take `.footnote`, Classic's and Lectern's heads `.headline`,
/// so the title always stands above the `.caption` translation under it; the tracking keeps its
/// ratio to the size, and shrinking to fit never goes below the caption.
struct PhoneBarTitleType {
    let font: UIFont
    let kern: CGFloat
    let minimumScaleFactor: CGFloat

    static func textStyle(for style: PageStyle) -> UIFont.TextStyle {
        switch style {
        case .printed, .study: .footnote
        case .lectern, .classic: .headline
        }
    }

    /// The inline bar's height holds the title, caption and progress line only this far; past it
    /// the bar title stops growing and the large content viewer shows it instead.
    static let largestSize: UIContentSizeCategory = .extraExtraExtraLarge
    static let largestDynamicTypeSize: DynamicTypeSize = .xxxLarge

    init(typography: ReaderTypography, contentSize: UIContentSizeCategory) {
        let traits = UITraitCollection(preferredContentSizeCategory: min(contentSize, Self.largestSize))
        let size = UIFont.preferredFont(forTextStyle: Self.textStyle(for: typography.style), compatibleWith: traits).pointSize
        let voice = typography.runningHeadFont
        font = voice.withSize(size)
        kern = voice.pointSize > 0 ? typography.runningHeadKern / voice.pointSize * size : 0
        let caption = UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: traits).pointSize
        // A long name shrinks to stay on the screen's centre, as far as the caption's size and a
        // little under it.
        minimumScaleFactor = min(1, caption / size) * 0.8
    }
}

/// The top bar's principal item, the phone's running head: the chapter in view in the page
/// style's label voice (Printed's "JOHN · 3") at a Dynamic Type size
/// (`PhoneBarTitleType`), the translation in caption under it, and
/// under both the Mac's progress line (`ReadingProgressLine`, its value, token and thickness),
/// restarting for each chapter. The whole title takes the head's opacity, so it is hidden while
/// the chapter's opening (chapter 1's title block, a later chapter's label or Lectern hairline)
/// is on screen and appears as the opening scrolls under the bar, like a large title collapsing. VoiceOver reads it as a header, "John, chapter 3", with the
/// translation as its value; not at all while it is hidden.
private struct PhoneChapterTitle: View {
    let title: String
    let spokenLabel: String
    let translation: String
    /// The page's reports: the title's opacity and the chapter's progress (`RunningHeadFade`,
    /// `RunningHeadProgressLine`).
    let chrome: ReaderChrome
    let chapter: Int
    let typography: ReaderTypography
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The line's span, so a short title still gets a line long enough to read; grows with the text.
    @ScaledMetric(relativeTo: .headline) private var lineWidth = AppSpacing.xxxl * 2

    var body: some View {
        let type = PhoneBarTitleType(typography: typography, contentSize: UIContentSizeCategory(dynamicTypeSize))
        // At the head's opacity, without animation: the title follows the scroll.
        RunningHeadFade(chrome: chrome, chapter: chapter) {
            VStack(spacing: AppSpacing.xxs) {
                VStack(spacing: 0) {
                    Text(title)
                        // The page style's label voice at a Dynamic Type size.
                        .font(Font(type.font))
                        .kerning(type.kern)
                        // Tracking follows every letter, the last too: as much before the first
                        // keeps the words themselves on the centre.
                        .padding(.leading, type.kern)
                        .foregroundStyle(Color(platform: typography.runningHeadColor))
                        .lineLimit(1)
                        .minimumScaleFactor(type.minimumScaleFactor)
                    Text(translation)
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spokenLabel)
                .accessibilityValue(translation)
                .accessibilityAddTraits(.isHeader)
                RunningHeadProgressLine(chrome: chrome, chapter: chapter, measure: lineWidth)
                    .frame(width: lineWidth)
            }
        }
    }
}
#endif
