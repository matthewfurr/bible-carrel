import Foundation

/// What a piece of the page is, for drawing and accessibility: the opening paragraphs and section
/// headings carry a role on their characters (under `NSAttributedString.Key.readerRole`). Classify
/// text by a section's `openingRange` and the layout's spans, never by `role != nil`.
public enum ReaderRole: Hashable, Sendable {
    case title, subtitle, ornament
    /// The text naming a chapter in its opening ("CHAPTER 3", "John 3", "JOHN 3").
    case chapterLabel(Int)
    case sectionHeading
    /// Lectern: the chapter's hairline opening, a word joiner a point tall, beside whose text the
    /// chapter's drop numeral is drawn (`DropNumeral`).
    case dropNumeral(Int)
    /// A later chapter's opening in the styles with no numeral (Matt, 2026-11-13: the running
    /// head names the chapter, so the page carries no label): a word joiner a point tall, with
    /// nothing drawn. It gives the chapter an opening of its own, as Lectern's hairline does.
    case chapterStart(Int)
    /// A paragraph holding a single no-break space, over which the text controller draws a hairline.
    case rule
}

/// An `NSObject` wrapper, so the attribute survives `NSAttributedString` copying and is compared
/// by value (a bare Swift enum is bridged opaquely and never compares equal).
public final class ReaderRoleBox: NSObject {
    public let role: ReaderRole

    public init(_ role: ReaderRole) { self.role = role }

    public override func isEqual(_ object: Any?) -> Bool {
        (object as? ReaderRoleBox)?.role == role
    }

    public override var hash: Int { role.hashValue }
}

public extension NSAttributedString.Key {
    static let readerRole = NSAttributedString.Key("ReaderRole")
}

public extension NSAttributedString {
    /// The role tagged at `index`, if any.
    func readerRole(at index: Int) -> ReaderRole? {
        (attribute(.readerRole, at: index, effectiveRange: nil) as? ReaderRoleBox)?.role
    }
}
