import Foundation
import ScriptureData

/// Where the reader should go to show a markup item: the chapter, the verse to scroll to, the
/// translation it was made in (nil keeps the current one) and the highlight to light and outline
/// (nil for bookmarks and chapter notes), or the conversation to open in the assistant's panel.
public struct MarkupTarget: Hashable, Codable, Sendable {
    public let location: ChapterLocation
    public let verse: Int
    public let translationID: String?
    public let highlightID: UUID?
    /// Set for a conversation; the app opens it in the panel once the chapter is shown.
    public let threadID: UUID?

    public init(location: ChapterLocation, verse: Int, translationID: String?, highlightID: UUID?, threadID: UUID? = nil) {
        self.location = location
        self.verse = verse
        self.translationID = translationID
        self.highlightID = highlightID
        self.threadID = threadID
    }

    /// A chapter note or a chapter conversation (verse 0) targets verse 1; a bookmark keeps the
    /// current translation; a kept version with no note is its chapter and verse, with no highlight.
    public init(entry: NotesBrowserEntry) {
        var highlightID: UUID?
        var threadID: UUID?
        switch entry.kind {
        case .note(_, let anchor): highlightID = anchor
        case .highlight(let id): highlightID = id
        case .bookmark, .keptVersion: break
        case .thread(let id): threadID = id
        }
        self.init(
            location: ChapterLocation(book: entry.book, chapter: entry.chapter),
            verse: max(entry.verse, 1),
            translationID: entry.translationID,
            highlightID: highlightID,
            threadID: threadID)
    }
}

/// Takes the reader to a markup item the way a click on its card does: the chapter is looked up
/// (shown with a way back, the place being read kept) in the item's translation at its verse, and
/// once that chapter's markup is loaded the highlight is selected (card lit) and outlined.
public enum MarkupNavigation {
    @MainActor
    public static func show(_ target: MarkupTarget, navigation: NavigationModel, markup: MarkupModel) {
        navigation.lookUp(target.location, verse: target.verse, translationID: target.translationID)
        markup.focusWhenLoaded(target)
    }

    /// The assistant's Add as Note and Show Note, on both apps once each has shown the reader
    /// (`target` is `AssistantModel.noteTarget(noteID:)`): the note opens in the editor with its
    /// highlight lit. A note in another chapter (or translation) than the one loaded is shown as
    /// `show` shows one, and its editor opens once that chapter loads; one in the loaded chapter
    /// opens at once. A translation the app does not bundle keeps the current one, as the Notes
    /// browser does.
    @MainActor
    public static func openSavedNote(_ noteID: UUID, at target: MarkupTarget?, navigation: NavigationModel, markup: MarkupModel) {
        markup.reload()
        // Add as Note may have appended to the note open in the editor: its draft is reloaded.
        markup.reloadEditor(noteID: noteID)
        if var target {
            if let id = target.translationID, !navigation.translations.contains(where: { $0.id == id }) {
                target = MarkupTarget(location: target.location, verse: target.verse, translationID: nil, highlightID: target.highlightID)
            }
            if !markup.isLoaded(target) {
                show(target, navigation: navigation, markup: markup)
                markup.editWhenLoaded(noteID: noteID, target: target)
                return
            }
            // Loaded, but the column shows another chapter (an edit kept it on its note's): the
            // reader goes there as `show` takes it, and the editor opens at once.
            if target.location != markup.chapter {
                show(target, navigation: navigation, markup: markup)
            }
        }
        markup.beginEditing(noteID: noteID)
        if let highlightID = markup.highlightID(forNote: noteID) { markup.focus(highlightID: highlightID) }
    }
}
