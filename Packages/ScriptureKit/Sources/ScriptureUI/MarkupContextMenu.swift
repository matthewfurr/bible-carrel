#if os(macOS)
import AppKit
import ScriptureData
import SwiftUI

/// Builds the selection context menu from `MarkupModel.menuItems(for:)`: a hosted swatch row
/// first, then the actions. Copy writes the pasteboard; Share shows the system picker anchored
/// on the selection.
@MainActor
public enum MarkupContextMenu {
    private static var sharingPicker: NSSharingServicePicker?

    public static func make(for report: SelectionReport, model: MarkupModel, controller: ChapterTextController) -> NSMenu {
        let menu = MarkupMenu()
        menu.autoenablesItems = false
        let entries = model.menuItems(for: report)
        let noColor: Bool? = entries.lazy.compactMap { if case .noColor(let isCurrent) = $0 { return isCurrent } else { return nil } }.first
        for entry in entries {
            switch entry {
            case .swatches(let chips, let current):
                let item = NSMenuItem()
                let row = SwatchRowView(
                    chips: chips,
                    current: current,
                    onPick: { [weak menu] id in
                        menu?.rowActed = true
                        menu?.cancelTracking()
                        pickColor(id, report: report, model: model, controller: controller)
                    },
                    onNoColor: noColor == nil ? nil : { [weak menu] in
                        menu?.rowActed = true
                        menu?.cancelTracking()
                        pickNoColor(report: report, model: model, controller: controller)
                    },
                    noColorIsCurrent: noColor ?? false,
                    onAdd: { [weak menu] in
                        menu?.rowActed = true
                        menu?.cancelTracking()
                        model.pendingColorReport = report
                        model.isAddColorSheetShown = true
                    })
                // Its own SwiftUI root, so it takes the app's Sepia itself.
                let host = NSHostingView(rootView: row.followsSepia())
                host.frame = NSRect(origin: .zero, size: host.fittingSize)
                item.view = host
                menu.addItem(item)
                menu.addItem(.separator())
            case .addColor:
                menu.addItem(action("Add Color…", symbol: "plus.circle") {
                    controller.collapseSelection()
                    model.pendingColorReport = report
                    model.isAddColorSheetShown = true
                })
            case .noColor:
                break   // in the swatch row
            case .addNote(let existing):
                menu.addItem(action(existing ? "Edit Note" : "Add Note", symbol: existing ? "square.and.pencil" : "note.text.badge.plus") {
                    addNote(report: report, model: model, controller: controller)
                })
            case .removeHighlight:
                menu.addItem(action("Delete Highlight", symbol: "trash") {
                    model.removeHighlight(in: report)
                })
            case .bookmark(let verse, let isSet):
                menu.addItem(action(isSet ? "Remove Bookmark from Verse \(verse)" : "Bookmark Verse \(verse)", symbol: isSet ? "bookmark.slash" : "bookmark") {
                    model.toggleBookmark(for: report)
                })
            case .compareTranslations, .crossReferences:
                let kind: VersePanelKind = entry == .compareTranslations ? .compare : .crossReferences
                // The selection stays: the panel's popover hangs from it.
                let item = action(kind.title, symbol: kind.symbolName) {
                    model.onVersePanel?(kind, report)
                }
                item.isEnabled = model.onVersePanel != nil
                menu.addItem(item)
            case .copy:
                menu.addItem(.separator())
                menu.addItem(action("Copy", symbol: "doc.on.doc") {
                    write(model.copyText(for: report))
                })
            case .copyWithReference:
                menu.addItem(action("Copy with Reference", symbol: "text.quote") {
                    write(model.copyWithReference(for: report))
                })
            case .copyLink:
                menu.addItem(action("Copy Link", symbol: "link") {
                    write(PassageLinkClipboard(link: model.passageLink(for: report), scheme: PassageLink.appScheme))
                })
            case .share:
                menu.addItem(action("Share…", symbol: "square.and.arrow.up") {
                    let text = model.shareText(for: report)
                    let anchor = controller.frameOfFirstSegment(of: report.range) ?? controller.textView.visibleRect
                    // After the menu has closed, so the picker is not dismissed with it. The picker
                    // is kept alive until the next share: `show` presents asynchronously.
                    DispatchQueue.main.async {
                        let picker = NSSharingServicePicker(items: [text])
                        sharingPicker = picker
                        picker.show(relativeTo: anchor, of: controller.textView, preferredEdge: .minY)
                    }
                })
            case .askAboutPassage:
                menu.addItem(.separator())
                let item = action("Ask About This Passage", symbol: "sparkles") {
                    controller.collapseSelection()
                    model.onAskAboutPassage?(report)
                }
                item.isEnabled = model.onAskAboutPassage != nil
                menu.addItem(item)
            }
        }
        return menu
    }

    /// A swatch, or a number key: collapse first (the selection color would hide the new color),
    /// then outline the highlight as if it had been clicked.
    static func pickColor(_ id: UUID, report: SelectionReport, model: MarkupModel, controller: ChapterTextController) {
        controller.collapseSelection()
        if let touched = model.applyColor(id, to: report) { model.focus(highlightID: touched) }
    }

    /// No Color, or 0: underline only (a noteless highlight goes), the highlight outlined if it stays.
    static func pickNoColor(report: SelectionReport, model: MarkupModel, controller: ChapterTextController) {
        controller.collapseSelection()
        model.clearColor(in: report)
        if let primary = report.primaryHighlightID, model.isLoaded(highlightID: primary) {
            model.focus(highlightID: primary)
        }
    }

    /// Add Note or Edit Note, or N: the note in the column's editor, its highlight outlined.
    static func addNote(report: SelectionReport, model: MarkupModel, controller: ChapterTextController) {
        controller.collapseSelection()
        model.addNote(to: report)
        if let noteID = model.editingNoteID, let highlightID = model.highlightID(forNote: noteID) {
            model.focus(highlightID: highlightID)
        }
    }

    private static func action(_ title: String, symbol: String, _ perform: @escaping @MainActor () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(MenuAction.runAction), keyEquivalent: "")
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        let target = MenuAction(perform)
        item.target = target
        // `target` is weak on NSMenuItem; the represented object keeps the action alive.
        item.representedObject = target
        return item
    }

    /// The link as plain text, rich text (the title carrying the link) and HTML.
    public static func write(_ clipboard: PassageLinkClipboard, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.declareTypes([.string, .rtf, .html], owner: nil)
        pasteboard.setString(clipboard.plain, forType: .string)
        if let rtf = clipboard.rtf() { pasteboard.setData(rtf, forType: .rtf) }
        pasteboard.setString(clipboard.html, forType: .html)
    }

    private static func write(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

/// The markup menu: its swatch row closes it itself after a pick (`cancelTracking`, which
/// `popUp` reports as no choice), so the row marks it here; the reader then reads the closing as
/// a choice, not a click away (`ChapterTextController.popUpMenu`).
final class MarkupMenu: NSMenu {
    var rowActed = false
}

@MainActor
private final class MenuAction: NSObject {
    private let action: @MainActor () -> Void

    init(_ action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    @objc func runAction() {
        action()
    }
}
#endif
