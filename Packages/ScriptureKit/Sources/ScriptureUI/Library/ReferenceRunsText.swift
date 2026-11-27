import ScriptureData
import SwiftUI

/// References as one run of links with a middle dot between them. Without `onShow`, a click shows
/// the passage in a popover where it was clicked, with Open (the Mac); with it, the click is
/// handed over (the phone pushes). Under a book's own heading the book's name is left out
/// ("1:18-19 · 2:1"); VoiceOver hears each reference in full and reaches it as a named action,
/// as `NoteBodyText` does.
public struct ReferenceRunsText: View {
    let references: [Reference]
    let book: Book?
    let font: Font
    let navigation: NavigationModel
    let onShow: ((Reference) -> Void)?
    let onOpen: (Reference) -> Void

    @State private var shown: ShownPassage?
    /// Where the pointer is over the run, for the popover's arrow; a reference type, so tracking it
    /// invalidates nothing.
    @State private var pointer = RunPointer()

    public init(_ references: [Reference], inBook book: Book?, font: Font = .callout, navigation: NavigationModel,
                onShow: ((Reference) -> Void)? = nil, onOpen: @escaping (Reference) -> Void) {
        self.references = references
        self.book = book
        self.font = font
        self.navigation = navigation
        self.onShow = onShow
        self.onOpen = onOpen
    }

    struct ShownPassage: Identifiable, Equatable {
        let passage: LibraryPassage
        let reference: Reference
        /// Where the popover's arrow points, in the run's space; nil points at the run.
        let anchor: CGRect?
        var id: String { reference.displayString }
    }

    /// The arrow's rect: a small one at the pointer's last place over the run, else (VoiceOver, the
    /// keyboard) nil, which is the run's bounds.
    nonisolated static func anchorRect(pointer: CGPoint?) -> CGRect? {
        pointer.map { CGRect(x: $0.x - 1, y: $0.y - 1, width: 2, height: 2) }
    }

    /// The references as linked text: each in the short form when it is in `book`, a middle dot between.
    nonisolated static func text(_ references: [Reference], inBook book: Book?) -> AttributedString {
        var result = AttributedString()
        for (index, reference) in references.enumerated() {
            if index > 0 {
                var dot = AttributedString(" \u{00B7} ")
                dot.foregroundColor = Color.inkPrimary
                result.append(dot)
            }
            var piece = AttributedString(short(reference, inBook: book))
            piece.link = ReferenceLinker.url(for: reference)
            piece.foregroundColor = Color.accent
            result.append(piece)
        }
        return result
    }

    /// "1:18-19" in the reference's own book, else `displayString`.
    nonisolated static func short(_ reference: Reference, inBook book: Book?) -> String {
        guard let book, reference.book == book, let chapter = reference.chapter else { return reference.displayString }
        guard let verse = reference.verse else { return "\(chapter)" }
        return "\(chapter):\(verse)" + (reference.endVerse.map { "-\($0)" } ?? "")
    }

    public var body: some View {
        runs
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(references.map(\.displayString).joined(separator: ", "))
            .accessibilityActions {
                ForEach(references, id: \.self) { reference in
                    Button(reference.displayString) { show(reference) }
                }
            }
    }

    /// The run is one `Text` of links, one view however many references it holds (a view for each
    /// made a page of hundreds slow to build). On the Mac one popover serves it, its arrow at the
    /// pointer's place when a link was clicked.
    private var runs: some View {
        Text(Self.text(references, inBook: book))
            .font(font)
            // The links take the tint; the dots carry their own ink in `text`.
            .tint(Color.accent)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == ReferenceLinker.scheme else { return .systemAction }
                if let reference = ReferenceLinker.reference(from: url) { show(reference, pointer: pointer.location) }
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
            .popover(item: $shown, attachmentAnchor: .rect(shown?.anchor.map { Anchor<CGRect>.Source.rect($0) } ?? .bounds)) { shown in
                LibraryPassageView(passage: shown.passage) {
                    self.shown = nil
                    onOpen(shown.reference)
                }
            }
            #endif
    }

    #if os(macOS)
    private nonisolated static let space = "reference-runs"
    #endif

    private func show(_ reference: Reference, pointer: CGPoint? = nil) {
        if let onShow {
            onShow(reference)
            return
        }
        #if os(macOS)
        shown = ShownPassage(passage: LibraryPassage.load(reference, navigation: navigation), reference: reference,
                             anchor: Self.anchorRect(pointer: pointer))
        #else
        onOpen(reference)
        #endif
    }
}

/// The pointer's last place over a run, nil once it leaves. A reference type held in `@State`.
@MainActor final class RunPointer {
    var location: CGPoint?
}
