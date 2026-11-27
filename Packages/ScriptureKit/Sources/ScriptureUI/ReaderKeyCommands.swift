#if os(macOS)
import AppKit

/// What the reader's keys do beyond its text: a number, 0 and N do what the context menu's
/// swatch, No Color and Add Note do (the same code), B toggles the verse's bookmark, the arrows
/// turn chapters and ? shows the shortcuts.
@MainActor public enum ReaderKeyCommands {
    /// Whether the reader's keys act: not while ⌘K is showing (its field may not have the keyboard
    /// yet) or a note is being edited (its editor may not be in the window yet), when the letters
    /// are meant as typing. `ChapterTextController.keysAreLive` asks this for every reader key.
    public static func keysAreLive(markup: MarkupModel, navigation: NavigationModel) -> Bool {
        !navigation.isPaletteShown && markup.editingNoteID == nil
    }

    /// True for every action it handles, even when there is nothing to do (a number past the
    /// last color, 0 outside a highlight, any key while `keysAreLive` is false); false for the
    /// verse keys, which the controller handles.
    public static func perform(_ action: ReaderKeyAction, report: SelectionReport?, markup: MarkupModel,
                               navigation: NavigationModel, controller: ChapterTextController) -> Bool {
        guard keysAreLive(markup: markup, navigation: navigation) else { return true }
        switch action {
        case .color(let number):
            guard let report, markup.colorChips.indices.contains(number - 1) else { return true }
            MarkupContextMenu.pickColor(markup.colorChips[number - 1].id, report: report, model: markup, controller: controller)
        case .noColor:
            guard let report, markup.menuItems(for: report).contains(where: { if case .noColor = $0 { true } else { false } })
            else { return true }
            MarkupContextMenu.pickNoColor(report: report, model: markup, controller: controller)
        case .note:
            guard let report else { return true }
            MarkupContextMenu.addNote(report: report, model: markup, controller: controller)
        case .bookmark:
            guard let report else { return true }
            markup.toggleBookmark(for: report)
        case .compareTranslations:
            guard let report else { return true }
            markup.onVersePanel?(.compare, report)
        case .crossReferences:
            guard let report else { return true }
            markup.onVersePanel?(.crossReferences, report)
        case .previousChapter:
            navigation.goToPreviousChapter()
        case .nextChapter:
            navigation.goToNextChapter()
        case .showShortcuts:
            navigation.isShortcutsShown.toggle()
        case .nextVerse, .previousVerse, .extendDown, .extendUp, .clearSelection:
            return false
        }
        return true
    }
}
#endif
