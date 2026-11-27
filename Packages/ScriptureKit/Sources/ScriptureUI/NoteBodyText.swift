import ScriptureData
import SwiftUI

/// What a reference linked in a note leads to (spec 3): the chapter counts that keep a link to a
/// chapter the book lacks from being made, the verses to show, and Open, which shows the
/// passage. Each app puts one in the environment (`noteLinks`) for every view that shows a note.
@MainActor public final class NoteLinks {
    public let chapterCount: (String) -> Int?
    public let preview: (Reference) -> VersePreview?
    public let open: (Reference) -> Void

    public init(chapterCount: @escaping (String) -> Int?, preview: @escaping (Reference) -> VersePreview?,
                open: @escaping (Reference) -> Void) {
        self.chapterCount = chapterCount
        self.preview = preview
        self.open = open
    }

    /// From the reader's navigation: its translation's books and verses.
    public convenience init(navigation: NavigationModel, open: @escaping (Reference) -> Void) {
        self.init(chapterCount: { [weak navigation] in navigation?.chapterCount(ofBook: $0) },
                  preview: { [weak navigation] in navigation?.versePreview($0) },
                  open: open)
    }
}

extension EnvironmentValues {
    /// Where a note's references lead; nil, and a note's references are plain text.
    @Entry public var noteLinks: NoteLinks?
}

/// A note as it reads (spec 3): its markdown rendered (`NoteMarkdown.blocks`, no symbols), each
/// block's references linked by `ReferenceLinker`'s note rules in the accent, found as it is shown
/// and never written into the note. A reference opens through `onOpenReference` when given (the
/// phone's note sheet shows the verse inside itself); otherwise, on the Mac, its verses show in a
/// popover on the note, with Open, as a reference in a reply does. VoiceOver reaches each
/// reference as an action named for it, since a row reads as one element.
public struct NoteBodyText: View {
    let text: String
    /// The note's own book, for a bare "5:3".
    let book: Book?
    let font: Font
    /// A preview of the note: its blocks run on in one text, headings at the row's own size, at most
    /// this many lines.
    let previewLines: Int?
    let onOpenReference: ((Reference) -> Void)?
    @Environment(\.noteLinks) private var links
    @State private var preview: VersePreview?

    public init(_ text: String, book: Book?, font: Font, previewLines: Int? = nil, onOpenReference: ((Reference) -> Void)? = nil) {
        self.text = text
        self.book = book
        self.font = font
        self.previewLines = previewLines
        self.onOpenReference = onOpenReference
    }

    /// The note's blocks with their references linked; plain when there is nowhere to lead.
    nonisolated static func blocks(_ text: String, book: Book?, chapterCount: ((String) -> Int?)?, headingsAtTextSize: Bool = false) -> [AttributedString] {
        let blocks = NoteMarkdown.blocks(text, headingsAtTextSize: headingsAtTextSize)
        guard let chapterCount else { return blocks }
        return blocks.map { ReferenceLinker.linked($0, contextBook: book, rules: .note, chapterCount: chapterCount) }
    }

    /// The note's blocks as one text, a newline between them and no heading size, so a row can cap it.
    nonisolated static func preview(_ text: String, book: Book?, chapterCount: ((String) -> Int?)?) -> AttributedString {
        var result = AttributedString()
        for (index, block) in blocks(text, book: book, chapterCount: chapterCount, headingsAtTextSize: true).enumerated() {
            if index > 0 { result.append(AttributedString("\n")) }
            result.append(block)
        }
        return result
    }

    public var body: some View {
        let blocks = previewLines == nil
            ? Self.blocks(text, book: book, chapterCount: links?.chapterCount)
            : [Self.preview(text, book: book, chapterCount: links?.chapterCount)]
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                Text(block)
                    .font(font)
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(previewLines)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(Color.accent)
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == ReferenceLinker.scheme else { return .systemAction }
            if let reference = ReferenceLinker.reference(from: url) { open(reference) }
            return .handled
        })
        .accessibilityActions {
            ForEach(ChatTurnRow.linkedReferences(in: blocks.reduce(into: AttributedString()) { $0.append($1) }), id: \.self) { reference in
                Button(reference.displayString) { open(reference) }
            }
        }
        #if os(macOS)
        .popover(item: $preview) { preview in
            VersePreviewView(preview: preview, openTitle: "Open") {
                self.preview = nil
                links?.open(preview.reference)
            }
        }
        #endif
    }

    private func open(_ reference: Reference) {
        if let onOpenReference {
            onOpenReference(reference)
        } else {
            preview = links?.preview(reference)
        }
    }
}
