import ScriptureData
import SwiftUI

/// The names a book is most about as one line of links: "God, Jacob, Abraham, Joseph, Isaac and 347 more",
/// or the writers, "David and Solomon (by tradition)". Names and "347 more" are in the accent, "and " and the
/// tail in `ink.secondary`. One `Text`, however many names; a click is handed to `onWalk` or `onMore`.
struct LibraryNameRun: View {
    struct Name: Equatable {
        let entity: LibraryEntity
        let name: String
    }

    let names: [Name]
    let more: Int
    let tail: String?
    let onWalk: (LibraryEntity) -> Void
    let onMore: (() -> Void)?
    @Environment(\.libraryType) private var type

    init(_ names: [Name], more: Int = 0, tail: String? = nil, onWalk: @escaping (LibraryEntity) -> Void,
         onMore: (() -> Void)? = nil) {
        self.names = names
        self.more = more
        self.tail = tail
        self.onWalk = onWalk
        self.onMore = onMore
    }

    private nonisolated static let scheme = "libraryname"

    private nonisolated static func url(_ entity: LibraryEntity) -> URL? {
        switch entity {
        case .person(let id): URL(string: "\(scheme)://person/\(id)")
        case .place(let id): URL(string: "\(scheme)://place/\(id)")
        }
    }

    private nonisolated static let moreURL = URL(string: "\(scheme)://more")

    private nonisolated static func entity(from url: URL) -> LibraryEntity? {
        guard url.scheme == scheme, let id = Int(url.lastPathComponent) else { return nil }
        switch url.host() {
        case "person": return .person(id)
        case "place": return .place(id)
        default: return nil
        }
    }

    /// The line as one run: names (and the "n more") linked in `accent`, "and " and the tail secondary.
    nonisolated static func text(_ names: [Name], more: Int = 0, tail: String? = nil) -> AttributedString {
        var result = AttributedString()
        func plain(_ string: String, ink: Color) {
            var piece = AttributedString(string)
            piece.foregroundColor = ink
            result.append(piece)
        }
        func link(_ string: String, to url: URL?) {
            var piece = AttributedString(string)
            piece.link = url
            piece.foregroundColor = Color.accent
            result.append(piece)
        }
        let moreText = "\(more.formatted()) more"
        let count = names.count + (more > 0 ? 1 : 0)
        for (index, name) in names.enumerated() {
            if index > 0 { plain(index == count - 1 ? " " : ", ", ink: .inkPrimary) }
            if index > 0, index == count - 1 { plain("and ", ink: .inkSecondary) }
            link(name.name, to: url(name.entity))
        }
        if more > 0 {
            if !names.isEmpty {
                plain(" ", ink: .inkPrimary)
                plain("and ", ink: .inkSecondary)
            }
            link(moreText, to: moreURL)
        }
        if let tail {
            plain(" ", ink: .inkPrimary)
            plain(tail, ink: .inkSecondary)
        }
        return result
    }

    nonisolated static func spoken(_ names: [Name], more: Int = 0, tail: String? = nil) -> String {
        String(text(names, more: more, tail: tail).characters)
    }

    var body: some View {
        Text(Self.text(names, more: more, tail: tail))
            .font(type.font(type.reading))
            .tint(Color.accent)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == Self.scheme else { return .systemAction }
                if let entity = Self.entity(from: url) {
                    onWalk(entity)
                } else if url == Self.moreURL {
                    onMore?()
                }
                return .handled
            })
    }
}
