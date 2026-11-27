import Foundation
import ScriptureData

/// One stop of the reader's VoiceOver Headings rotor: a run of the book layout's text and what
/// the rotor names it.
struct BookHeadingItem: Equatable {
    let range: NSRange
    let label: String
}

/// The Headings rotor's stops over a book layout, shared by the Mac's and the phone's text views.
enum BookHeadings {
    /// The book's title, every chapter's opening (its label, or Lectern's hairline opening) and the
    /// section headings, in text order. Labels name chapters as the rest of the app does ("John 3").
    static func items(in layout: BookLayout?) -> [BookHeadingItem] {
        guard let layout else { return [] }
        let string = layout.attributedString
        let text = string.string as NSString
        let bookName = BookCatalog.book(code: layout.id.book)?.chapterName ?? layout.id.book
        var runs: [(role: ReaderRole, range: NSRange)] = []
        string.enumerateAttribute(.readerRole, in: NSRange(location: 0, length: string.length)) { value, range, _ in
            guard let role = (value as? ReaderRoleBox)?.role else { return }
            if let last = runs.last, last.role == role, NSMaxRange(last.range) == range.location {
                runs[runs.count - 1].range.length += range.length
            } else {
                runs.append((role, range))
            }
        }
        return runs.compactMap { run -> BookHeadingItem? in
            var range = run.range
            while range.length > 0, let scalar = UnicodeScalar(text.character(at: NSMaxRange(range) - 1)),
                  CharacterSet.whitespacesAndNewlines.contains(scalar) {
                range.length -= 1
            }
            guard range.length > 0 else { return nil }
            switch run.role {
            case .title, .sectionHeading:
                return BookHeadingItem(range: range, label: text.substring(with: range))
            case .chapterLabel(let chapter), .dropNumeral(let chapter), .chapterStart(let chapter):
                return BookHeadingItem(range: range, label: "\(bookName) \(chapter)")
            case .subtitle, .ornament, .rule:
                return nil
            }
        }
    }

    /// The next (or previous) item from the one starting at `current` (VoiceOver's cursor, nil at
    /// the start of a search), among those whose label contains `filter` when it is not empty.
    static func item(from current: Int?, forward: Bool, filter: String = "", in items: [BookHeadingItem]) -> BookHeadingItem? {
        let candidates = filter.isEmpty ? items : items.filter { $0.label.localizedCaseInsensitiveContains(filter) }
        let current = current.flatMap { $0 == NSNotFound ? nil : $0 }
        if forward {
            guard let current else { return candidates.first }
            return candidates.first { $0.range.location > current }
        }
        guard let current else { return candidates.last }
        return candidates.last { $0.range.location < current }
    }
}
