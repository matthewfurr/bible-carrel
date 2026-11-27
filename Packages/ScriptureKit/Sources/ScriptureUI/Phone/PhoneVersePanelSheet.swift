#if os(iOS)
import ScriptureData
import SwiftUI

/// One of the two verse panels over the page (spec 7): a sheet at half height, draggable to full,
/// on the page's paper, with the panel's name as its inline title (the panel's own header names the
/// reference, which Cross-References' chevrons move) and Done. In Cross-References a tapped
/// reference pushes its verses inside the sheet, with Back and **Open in Read**, as the note sheet
/// does. A compare row, and Open in Read, hand the place to `onOpen` (which closes the sheet and
/// looks it up), but the row being read only closes the sheet; Ask is handed to `onAsk`, which queues it and closes the sheet.
public struct PhoneVersePanelSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let request: VersePanelRequest
    private let navigation: NavigationModel
    private let onOpen: (ChapterLocation, Int?, String?) -> Void
    private let onAsk: (VerseComparison) -> Void
    private let onAskAboutThese: (CrossReferences) -> Void
    /// The references opened from the list, pushed over it.
    @State private var path: [Reference] = []

    /// `onOpen` takes the chapter, the verse and the translation to show it in; a nil translation
    /// is the one being read, and a passage from Cross-References, which is recorded as looked up.
    public init(request: VersePanelRequest, navigation: NavigationModel,
                onOpen: @escaping (ChapterLocation, Int?, String?) -> Void,
                onAsk: @escaping (VerseComparison) -> Void,
                onAskAboutThese: @escaping (CrossReferences) -> Void) {
        self.request = request
        self.navigation = navigation
        self.onOpen = onOpen
        self.onAsk = onAsk
        self.onAskAboutThese = onAskAboutThese
    }

    public var body: some View {
        NavigationStack(path: $path) {
            panel
                .containerBackground(Color.paperPage, for: .navigation)
                .navigationTitle(request.kind.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", systemImage: "checkmark") { dismiss() }
                    }
                }
                .navigationDestination(for: Reference.self) { reference in
                    verses(reference)
                }
        }
        .presentationDetents([.medium, .large])
        .tint(Color.accent)
    }

    @ViewBuilder private var panel: some View {
        let selection = request.selection
        switch request.kind {
        case .compare:
            CompareTranslationsPanel(
                selection: selection, navigation: navigation,
                // The row being read only closes the sheet.
                onOpen: { row in
                    if row.looksUp { onOpen(selection.chapterLocation, selection.verse, row.translationID) } else { dismiss() }
                },
                onAsk: onAsk)
        case .crossReferences:
            CrossReferencesPanel(
                verse: request.verse, navigation: navigation, showsPassageInPlace: false,
                onShowPassage: { path.append($0) },
                onOpen: openPassage,
                onAsk: onAskAboutThese)
        }
    }

    private func openPassage(_ reference: Reference) {
        guard let chapter = reference.chapter else { return }
        onOpen(ChapterLocation(book: reference.book.id, chapter: chapter), reference.verse, nil)
    }

    @ViewBuilder private func verses(_ reference: Reference) -> some View {
        if let preview = navigation.versePreview(reference) {
            ScrollView {
                VersePreviewView(preview: preview, openTitle: "Open in Read") { openPassage(reference) }
                    .padding(AppSpacing.md)
            }
            .navigationBarTitleDisplayMode(.inline)
            .containerBackground(Color.paperPage, for: .navigation)
        } else {
            ContentUnavailableView("Not in This Translation", systemImage: "book",
                                   description: Text("\(reference.displayString) is not in the translation being read."))
        }
    }
}
#endif
