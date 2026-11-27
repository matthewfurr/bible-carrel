#if os(iOS)
import ScriptureData
import UIKit

/// The phone's edit menu over a selection, built from `MarkupModel.menuItems(for:)` with the Mac's
/// titles and symbols (`MarkupContextMenu`) but in the phone's own order (`phoneOrder`): one color
/// chip, which opens the list of every color, then the actions, each drawn in the bar as its
/// symbol alone (`iconAction`), Look Up and Translate last. Copy writes
/// the pasteboard; Share hands the text to `share`, which presents the system share sheet.
@MainActor
public enum PhoneMarkupMenu {
    /// `collapse` clears the text view's selection before an action that changes the markup, as
    /// the Mac's menu does, so the selection tint never hides the new color. The chip shows the
    /// color of the highlight the selection is inside, else `penColorID` (the pen's ringed color),
    /// else the first color. The circles are drawn for `traits`, the text view's, so they take its
    /// appearance (`UITraitCollection.current` is not the text view's while the menu is built).
    /// `lookUp` and `translate` present the system's dictionary and translation for the selected
    /// words: the app's own rows rather than the system's commands, whose rows the list sets in
    /// another voice.
    static func make(for report: SelectionReport, model: MarkupModel, penColorID: UUID?, share: @escaping (String) -> Void,
                     lookUp: @escaping (String) -> Void = { _ in }, translate: @escaping (String) -> Void = { _ in },
                     collapse: @escaping () -> Void, traits: UITraitCollection) -> UIMenu {
        let entries = phoneOrder(model.menuItems(for: report))
        let noColor: Bool? = entries.lazy.compactMap { if case .noColor(let isCurrent) = $0 { return isCurrent } else { return nil } }.first
        var children: [UIMenuElement] = []
        for entry in entries {
            switch entry {
            case .swatches(let chips, let current):
                // Inside a highlight (No Color is offered only there) its color leads; otherwise the pen's.
                let shownID = noColor != nil ? current : (penColorID ?? chips.first?.id)
                let clear: NoColorChoice? = noColor.map { isCurrent in
                    NoColorChoice(isCurrent: isCurrent) {
                        collapse()
                        model.clearColor(in: report)
                        if let primary = report.primaryHighlightID, model.isLoaded(highlightID: primary) {
                            model.focus(highlightID: primary)
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
                let chip = colorChip(chips: chips, currentID: shownID, noColor: clear, traits: traits) { id in
                    collapse()
                    if let touched = model.applyColor(id, to: report) { model.focus(highlightID: touched) }
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                if let chip { children.append(chip) }
            case .addColor:
                break   // the phone has no Add Color sheet yet
            case .noColor:
                break   // in the chip's list
            case .addNote(let existing):
                children.append(iconAction(existing ? "Edit Note" : "Add Note", symbol: existing ? "square.and.pencil" : "note.text.badge.plus") {
                    collapse()
                    model.addNote(to: report)
                    if let noteID = model.editingNoteID, let highlightID = model.highlightID(forNote: noteID) {
                        model.focus(highlightID: highlightID)
                    }
                })
            case .removeHighlight:
                children.append(iconAction("Delete Highlight", symbol: "trash", attributes: .destructive) {
                    collapse()
                    model.removeHighlight(in: report)
                })
            case .bookmark(let verse, let isSet):
                children.append(iconAction(isSet ? "Remove Bookmark from Verse \(verse)" : "Bookmark Verse \(verse)",
                                           symbol: isSet ? "bookmark.slash" : "bookmark") {
                    model.toggleBookmark(for: report)
                })
            case .compareTranslations, .crossReferences:
                let kind: VersePanelKind = entry == .compareTranslations ? .compare : .crossReferences
                // The selection stays, as on the Mac: the panel is shown for it.
                children.append(iconAction(kind.title, symbol: kind.symbolName,
                                           attributes: model.onVersePanel == nil ? .disabled : []) {
                    model.onVersePanel?(kind, report)
                })
            case .copy:
                children.append(iconAction("Copy", symbol: "doc.on.doc") {
                    UIPasteboard.general.string = model.copyText(for: report)
                })
            case .copyWithReference:
                children.append(iconAction("Copy with Reference", symbol: "text.quote") {
                    UIPasteboard.general.string = model.copyWithReference(for: report)
                })
            case .copyLink:
                children.append(iconAction("Copy Link", symbol: "link") {
                    write(PassageLinkClipboard(link: model.passageLink(for: report), scheme: PassageLink.appScheme))
                })
            case .share:
                children.append(iconAction("Share…", symbol: "square.and.arrow.up") {
                    share(model.shareText(for: report))
                })
            case .askAboutPassage:
                children.append(iconAction("Ask About This Passage", symbol: "sparkles",
                                           attributes: model.onAskAboutPassage == nil ? .disabled : []) {
                    collapse()
                    model.onAskAboutPassage?(report)
                })
            }
        }
        let words = report.selection.quotedText
        if !words.isEmpty {
            children.append(iconAction("Look Up", symbol: "info.circle") { lookUp(words) })
            children.append(iconAction("Translate", symbol: "translate") { translate(words) })
        }
        return UIMenu(children: children)
    }

    /// One pasteboard item: the link as plain text, rich text (the title carrying the link) and HTML.
    static func write(_ clipboard: PassageLinkClipboard, to pasteboard: UIPasteboard = .general) {
        var item: [String: Any] = [
            "public.utf8-plain-text": clipboard.plain,
            "public.html": clipboard.html,
        ]
        if let rtf = clipboard.rtf() { item["public.rtf"] = rtf }
        pasteboard.items = [item]
    }

    /// The phone's bar order, which differs from the Mac's menu on purpose. The bar holds what
    /// fits before its chevron, so the first places go to what the reader must not lose behind
    /// it: the chip, the note, Delete (inside a highlight), the bookmark, Ask, then Compare Translations,
    /// Cross-References, Copy, Copy with Reference, Copy Link and Share. The entries still come from the shared `menuItems(for:)`.
    static func phoneOrder(_ entries: [MarkupMenuItem]) -> [MarkupMenuItem] {
        func rank(_ entry: MarkupMenuItem) -> Int {
            switch entry {
            case .swatches, .addColor, .noColor: 0
            case .addNote: 1
            case .removeHighlight: 2
            case .bookmark: 3
            case .askAboutPassage: 4
            case .compareTranslations: 5
            case .crossReferences: 6
            case .copy: 7
            case .copyWithReference: 8
            case .copyLink: 9
            case .share: 10
            }
        }
        return entries.enumerated().sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }.map(\.element)
    }

    /// The pen's menu under a selected mark: the color chip in the mark's color, then its note,
    /// its verse's bookmark, Ask and Delete. A color chosen from the chip goes to `chooseColor`,
    /// as a tap on the pen bar does (the mark is recolored and the color becomes the pen's). The
    /// handles have the extent, so the menu does not. `deleted` runs after Delete (the delete is
    /// undoable, so it never asks).
    static func makeUnderMark(highlightID: UUID, report: SelectionReport, model: MarkupModel, traits: UITraitCollection,
                              chooseColor: @escaping (UUID) -> Void, deleted: @escaping () -> Void) -> UIMenu {
        var children: [UIMenuElement] = []
        for entry in model.menuItems(for: report) {
            guard case .swatches(let chips, let current) = entry else { continue }
            let chip = colorChip(chips: chips, currentID: current, noColor: nil, traits: traits) { id in
                chooseColor(id)
                UISelectionFeedbackGenerator().selectionChanged()
            }
            if let chip { children.append(chip) }
        }
        // The selection's chapter: the markup files its items by chapter.
        let chapter = report.selection.chapter
        let hasNote = model.itemsByChapter[chapter]?.first { $0.id == highlightID }?.hasNote ?? false
        let isBookmarked = model.bookmarksByChapter[chapter]?.contains(report.selection.verse) ?? false
        let note = iconAction(hasNote ? "Edit Note" : "Add Note", symbol: hasNote ? "square.and.pencil" : "note.text.badge.plus") {
            model.addNote(to: report)
            model.focus(highlightID: highlightID)
        }
        let bookmark = iconAction(isBookmarked ? "Remove Bookmark" : "Bookmark", symbol: isBookmarked ? "bookmark.slash" : "bookmark") {
            model.toggleBookmark(for: report)
        }
        let ask = iconAction("Ask", symbol: "sparkles", attributes: model.onAskAboutPassage == nil ? .disabled : []) {
            model.onAskAboutPassage?(report)
        }
        let delete = iconAction("Delete", symbol: "trash", attributes: .destructive) {
            model.deleteHighlight(id: highlightID)
            deleted()
        }
        children += [note, bookmark, ask, delete]
        return UIMenu(children: children)
    }

    /// An action the compact bar draws as its symbol alone, so as many as possible fit before the
    /// chevron. The bar shows a title when there is one and the image only when the title is
    /// empty, whatever the element size asks for (tried again 2026-11-12: titled actions left
    /// room for two). The name goes in the subtitle, which the chevron's list shows on the row,
    /// and in the accessibility label. Every row in that list is one of these, Look Up and
    /// Translate included (`make`), so the list speaks in one voice (Matt, 2026-11-12); `spoken`
    /// is a fuller name for VoiceOver.
    private static func iconAction(_ title: String, symbol: String, spoken: String? = nil, attributes: UIMenuElement.Attributes = [],
                                   perform: @escaping @MainActor () -> Void) -> UIAction {
        let action = UIAction(title: "", subtitle: title, image: UIImage(systemName: symbol),
                              discoverabilityTitle: spoken ?? title, attributes: attributes) { _ in perform() }
        action.accessibilityLabel = spoken ?? title
        return action
    }

    /// No Color in the chip's list: whether it is the current choice, and what choosing it does.
    struct NoColorChoice {
        let isCurrent: Bool
        let perform: @MainActor () -> Void
    }

    /// The chip: one filled circle in the current color (No Color's circle when that is current),
    /// with no title, opening the list of every color by its swatch and name, then No Color when
    /// it is offered, the current one checked. Nil when there is no current color to show.
    private static func colorChip(chips: [ColorChip], currentID: UUID?, noColor: NoColorChoice?, traits: UITraitCollection,
                                  choose: @escaping @MainActor (UUID) -> Void) -> UIMenu? {
        var list: [UIMenuElement] = chips.map { chip in
            UIAction(title: chip.name, image: swatchImage(fill: chip.color.platformColor, traits: traits),
                     state: chip.id == currentID ? .on : .off) { _ in choose(chip.id) }
        }
        if let noColor {
            list.append(UIAction(title: "No Color", image: noColorImage(traits: traits),
                                 state: noColor.isCurrent ? .on : .off) { _ in noColor.perform() })
        }
        let shown: (name: String, image: UIImage)
        if noColor?.isCurrent == true {
            shown = ("No Color", noColorImage(traits: traits))
        } else if let chip = chips.first(where: { $0.id == currentID }) {
            shown = (chip.name, swatchImage(fill: chip.color.platformColor, traits: traits))
        } else {
            return nil
        }
        let menu = UIMenu(title: "", image: shown.image, children: list)
        // Named in the chevron's list as the actions are; the bar still draws the circle alone.
        menu.subtitle = shown.name
        menu.accessibilityLabel = "Highlight color"
        menu.accessibilityValue = shown.name
        return menu
    }

    /// A filled circle with the Mac swatch's hairline rim.
    static func swatchImage(fill: UIColor, traits: UITraitCollection) -> UIImage {
        circleImage(traits: traits) { rect in
            fill.setFill()
            UIBezierPath(ovalIn: rect).fill()
            Palette.inkRule.platformColor.setStroke()
            let rim = UIBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
            rim.lineWidth = 1
            rim.stroke()
        } symbol: { nil }
    }

    /// The Mac's No Color circle: a dashed rim around an underline.
    static func noColorImage(traits: UITraitCollection) -> UIImage {
        circleImage(traits: traits) { rect in
            Palette.inkSecondary.platformColor.setStroke()
            let rim = UIBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
            rim.lineWidth = 1
            rim.setLineDash([2, 2], count: 2, phase: 0)
            rim.stroke()
        } symbol: { ("underline", Palette.inkSecondary.platformColor, .regular) }
    }

    /// Drawn with `traits` current, so every dynamic color (the fill, the rim, the checkmark)
    /// resolves to the text view's appearance and contrast.
    private static func circleImage(traits: UITraitCollection, draw: (CGRect) -> Void,
                                    symbol: () -> (name: String, color: UIColor, weight: UIImage.SymbolWeight)?) -> UIImage {
        let size = UIFontMetrics(forTextStyle: .body).scaledValue(for: 20, compatibleWith: traits)
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        var image = UIImage()
        traits.performAsCurrent {
            image = UIGraphicsImageRenderer(size: rect.size, format: UIGraphicsImageRendererFormat(for: traits)).image { _ in
                draw(rect)
                guard let symbol = symbol() else { return }
                let configuration = UIImage.SymbolConfiguration(textStyle: .caption1)
                    .applying(UIImage.SymbolConfiguration(weight: symbol.weight))
                guard let glyph = UIImage(systemName: symbol.name, withConfiguration: configuration)?
                    .withTintColor(symbol.color.resolvedColor(with: traits), renderingMode: .alwaysOriginal) else { return }
                let glyphSize = glyph.size
                glyph.draw(in: CGRect(x: (size - glyphSize.width) / 2, y: (size - glyphSize.height) / 2,
                                      width: glyphSize.width, height: glyphSize.height))
            }
        }
        return image.withRenderingMode(.alwaysOriginal)
    }
}
#endif
