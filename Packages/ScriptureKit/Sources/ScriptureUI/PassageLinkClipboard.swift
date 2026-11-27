import Foundation
import ScriptureData
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// What Copy Link puts on the pasteboard.
public struct PassageLinkClipboard: Equatable, Sendable {
    public let url: URL
    /// The URL as text: what a plain-text paste gives.
    public let plain: String
    /// The reference with an en dash in a range ("John 3:16–18"): what a rich-text paste shows.
    public let title: String
    /// `<a href="…">title</a>`, the title escaped.
    public let html: String

    public init(link: PassageLink, scheme: String) {
        let url = link.url(scheme: scheme)
        var title = link.reference.displayString
        if let endVerse = link.reference.endVerse {
            let first = Reference(book: link.reference.book, chapter: link.reference.chapter, verse: link.reference.verse)
            title = "\(first.displayString)\u{2013}\(endVerse)"
        }
        self.url = url
        self.plain = url.absoluteString
        self.title = title
        self.html = "<a href=\"\(Self.escaped(url.absoluteString))\">\(Self.escaped(title))</a>"
    }

    /// The title carrying the link, as RTF.
    public func rtf() -> Data? {
        let linked = NSAttributedString(string: title, attributes: [.link: url])
        return try? linked.data(from: NSRange(location: 0, length: linked.length),
                                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    private static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
