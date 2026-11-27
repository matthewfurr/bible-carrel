import ScriptureData
import SwiftUI

/// A person's or place's entry from Easton's Bible Dictionary: the Quote serif (on the Mac's Library, the page
/// face's italic at the reader size), the first paragraph whole (cut at a sentence end when it runs past ten
/// lines), "Show more" and "Show less" with no count, and the source under it.
///
/// Its verse references are links in the accent (`DictionaryReferences`, found once for the entry and the translation
/// being read): on the Mac a click opens the passage in a popover at the pointer, as About's runs do (`VersePreviewView`
/// with Open); with `onShow` (the phone) it is handed over. VoiceOver reaches each as a named action ("Jeremiah 37:13",
/// `VerseLines.spoken`).
public struct DictionaryEntryView: View {
    let text: String
    let subject: String?
    let navigation: NavigationModel
    let onShow: ((Reference) -> Void)?
    let onOpen: (Reference) -> Void

    @Environment(\.pageFace) private var pageFace
    @ScaledMetric(relativeTo: .callout) private var quoteSize = PageFace.baseSize(.callout)
    @Environment(\.libraryType) private var type
    @State private var isExpanded = false
    /// The memo of `DictionaryEntry.shown`: computed when the width, the scaled size, the type or the face
    /// changes, never in `body`. Nil until a width is known, when the first paragraph shows whole.
    @State private var width: CGFloat = 0
    @State private var memo: DictionaryEntry.Shown?
    /// The entry's references, found once for the text and the translation; a reference type, so it invalidates nothing.
    @State private var links = DictionaryLinks()
    #if os(macOS)
    @State private var shownPassage: ReferenceRunsText.ShownPassage?
    /// Where the pointer is over the paragraph, for the popover's arrow.
    @State private var pointer = RunPointer()
    #endif

    /// `subject` is the person's or place's name (`DictionaryReferences.scan`).
    public init(_ text: String, subject: String? = nil, navigation: NavigationModel, onShow: ((Reference) -> Void)? = nil,
                onOpen: @escaping (Reference) -> Void) {
        self.text = text
        self.subject = subject
        self.navigation = navigation
        self.onShow = onShow
        self.onOpen = onOpen
    }

    private var shown: DictionaryEntry.Shown {
        memo ?? DictionaryEntry.unmeasured(text)
    }

    public var body: some View {
        // Worked once a body: until the memo is set it splits the whole entry (David's is 18,900 characters).
        let shown = self.shown
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            // The paragraph and its source can be selected and copied; Show more stays a button.
            linkedEntry(shown)
                .librarySelectable()
                .font(paragraphFont)
                .foregroundStyle(Color.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { measure(width: $0) }
                .onChange(of: quoteSize) { measure() }
                .onChange(of: type) { measure() }
                .onChange(of: pageFace) { measure() }
                .onChange(of: text) { measure() }
            if shown.hidesMore || isExpanded {
                Button(isExpanded ? "Show less" : "Show more") { isExpanded.toggle() }
                    .buttonStyle(.plain)
                    .font(type.font(.callout))
                    .foregroundStyle(Color.accent)
                    .accessibilityLabel(isExpanded ? "Show less of the dictionary entry" : "Show more of the dictionary entry")
                    .help(isExpanded ? "Show less of the dictionary entry" : "Show more of the dictionary entry")
            }
            Text("Easton's Bible Dictionary, 1897")
                .font(type.font(.caption))
                .foregroundStyle(Color.inkSecondary)
                .librarySelectable()
        }
    }

    /// The paragraph's font: the page face's italic at the reader size with the reader's type, else the Quote.
    private var paragraphFont: Font {
        type.readerSize == nil ? pageFace.quoteFont() : type.pageFont(pageFace, .body, italic: true)
    }

    /// The size the paragraph is drawn at, which the ten-line measure takes.
    private var paragraphSize: CGFloat {
        type.readerSize == nil ? quoteSize : type.size(.body)
    }

    /// The entry with its links: a click is the page's (the popover on the Mac, handed over on the phone).
    private func linkedEntry(_ shown: DictionaryEntry.Shown) -> some View {
        links.update(text, subject: subject, translationID: navigation.translationID, lastVerses: navigation.lastVerses(ofBook:))
        return entry(shown)
            // The links take the accent; the rest of the paragraph keeps `ink.primary`.
            .tint(Color.accent)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == ReferenceLinker.scheme else { return .systemAction }
                #if os(macOS)
                if let reference = ReferenceLinker.reference(from: url) { show(reference, pointer: pointer.location) }
                #else
                if let reference = ReferenceLinker.reference(from: url) { show(reference) }
                #endif
                return .handled
            })
            #if os(macOS)
            .coordinateSpace(.named(Self.space))
            .onContinuousHover(coordinateSpace: .named(Self.space)) { phase in
                switch phase {
                case .active(let location): pointer.location = location
                case .ended: pointer.location = nil
                }
            }
            .popover(item: $shownPassage,
                     attachmentAnchor: .rect(shownPassage?.anchor.map { Anchor<CGRect>.Source.rect($0) } ?? .bounds)) { shown in
                LibraryPassageView(passage: shown.passage) {
                    shownPassage = nil
                    onOpen(shown.reference)
                }
            }
            #endif
    }

    @ViewBuilder private func entry(_ shown: DictionaryEntry.Shown) -> some View {
        if isExpanded {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                ForEach(Array(DictionaryEntry.paragraphs(text).enumerated()), id: \.offset) { paragraph($0.element) }
            }
        } else {
            paragraph(shown.text)
                .lineLimit(shown.endsInEllipsis ? DictionaryEntry.shownLines : nil)
                .truncationMode(.tail)
        }
    }

    /// One paragraph (or the cut first one) with its links; VoiceOver has each as an action named for it.
    private func paragraph(_ shownText: String) -> some View {
        let linked = links.linked(shownText)
        return Text(linked.text)
            .accessibilityActions {
                ForEach(Array(linked.references.enumerated()), id: \.offset) { _, reference in
                    Button(VerseLines.spoken(reference)) { show(reference) }
                }
            }
    }

    #if os(macOS)
    private static let space = "dictionary-entry"
    #endif

    private func show(_ reference: Reference, pointer location: CGPoint? = nil) {
        if let onShow {
            onShow(reference)
            return
        }
        #if os(macOS)
        shownPassage = ReferenceRunsText.ShownPassage(passage: LibraryPassage.load(reference, navigation: navigation), reference: reference,
                                                      anchor: ReferenceRunsText.anchorRect(pointer: location))
        #else
        onOpen(reference)
        #endif
    }

    private func measure(width newWidth: CGFloat? = nil) {
        if let newWidth { width = newWidth }
        guard width > 0 else { return }
        let font = pageFace.font(size: paragraphSize, italic: true)
        memo = DictionaryEntry.shown(text) {
            DictionaryEntry.lineCount($0, font: font, width: width) <= DictionaryEntry.shownLines
        }
    }
}

/// An entry's references, found once for its text, subject and the translation being read, and each shown text with its
/// links in the accent, kept while the entry stays. Only the first paragraph is scanned until more of the entry is
/// shown (then the whole entry, once): David's entry is 18,900 characters, his first paragraph 331. A reference type
/// held in `@State`.
@MainActor final class DictionaryLinks {
    struct Linked {
        let text: AttributedString
        /// The references linked in `text`, in order.
        let references: [Reference]
    }

    private struct Key: Equatable {
        let text: String, subject: String?, translationID: String
    }

    private var key: Key?
    private var entry = ""
    private var lastVerses: (String) -> [Int: Int] = { _ in [:] }
    /// How many of the entry's characters have been scanned: none, its first paragraph, or all of it.
    private var scanned = 0
    private var found: [DictionaryReferences.Link] = []
    private var shown: [String: Linked] = [:]

    /// A new text, subject or translation forgets what was found; the same ones change nothing.
    func update(_ text: String, subject: String?, translationID: String, lastVerses: @escaping (String) -> [Int: Int]) {
        let key = Key(text: text, subject: subject, translationID: translationID)
        guard key != self.key else { return }
        self.key = key
        entry = text
        self.lastVerses = lastVerses
        (scanned, found, shown) = (0, [], [:])
    }

    /// `text` (a paragraph of the entry, or the first one's cut) with the links that fall wholly inside it.
    func linked(_ text: String) -> Linked {
        if let linked = shown[text] { return linked }
        guard let range = entry.range(of: text) else { return Linked(text: AttributedString(text), references: []) }
        let offset = entry.distance(from: entry.startIndex, to: range.lowerBound)
        if offset + text.count > scanned { scan(through: range.upperBound) }
        let linked = Self.linked(text, at: offset, found: found)
        shown[text] = linked
        return linked
    }

    /// The first paragraph (to its line's end: a chain never runs past one) when `upper` is in it, else the whole entry.
    private func scan(through upper: String.Index) {
        let firstEnd = entry.firstIndex(of: "\n") ?? entry.endIndex
        let scope = upper <= firstEnd && scanned == 0 ? String(entry[..<firstEnd]) : entry
        found = DictionaryReferences.scan(scope, subject: key?.subject) { lastVerses($0.id) }.links
        scanned = scope == entry ? Int.max : scope.count
    }

    /// `text`, found at character `offset` of the entry, with the links in `found` that fall wholly inside it.
    nonisolated static func linked(_ text: String, at offset: Int, found: [DictionaryReferences.Link]) -> Linked {
        var result = AttributedString(text)
        let length = text.count
        var references: [Reference] = []
        for link in found where link.range.lowerBound >= offset && link.range.upperBound <= offset + length {
            let lower = result.characters.index(result.startIndex, offsetBy: link.range.lowerBound - offset)
            let upper = result.characters.index(lower, offsetBy: link.range.count)
            result[lower..<upper].link = ReferenceLinker.url(for: link.reference)
            result[lower..<upper].foregroundColor = Color.accent
            references.append(link.reference)
        }
        return Linked(text: result, references: references)
    }
}
