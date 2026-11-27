import Foundation

/// Parses user-typed references such as `"Rom 8"`, `"John 3:16"`, `"1 Cor 13:4-7"`, `"matt.5.3"`.
public enum ReferenceParser {
    /// `exactBook`: the book must be exactly a book's name, short name or alias ("John", "Jn"),
    /// not the palette's guess from a prefix ("ma" for Mark). A passage link asks for it.
    public static func parse(_ input: String, exactBook: Bool = false) -> Reference? {
        let text = normalise(input)
        guard !text.isEmpty else { return nil }

        // Split into the book part (optional leading digit + letters/spaces) and the numeric remainder.
        var bookPart = ""
        var rest = Substring(text)
        if let first = rest.first, first.isNumber {
            bookPart.append(first)
            rest = rest.dropFirst()
        }
        let letters = rest.prefix { $0.isLetter || $0 == " " }
        bookPart += letters
        rest = rest.dropFirst(letters.count)
        guard bookPart.contains(where: \.isLetter), let book = resolveBook(bookPart, exact: exactBook) else { return nil }

        let remainder = rest.trimmingCharacters(in: .whitespaces)
        if remainder.isEmpty { return Reference(book: book) }

        // chapter[:verse[-endVerse]]
        let chapterAndVerses = remainder.split(separator: ":", omittingEmptySubsequences: false)
        guard chapterAndVerses.count <= 2, let chapter = Int(chapterAndVerses[0]), chapter >= 1 else { return nil }
        guard chapterAndVerses.count == 2 else { return Reference(book: book, chapter: chapter) }

        let verses = chapterAndVerses[1].split(separator: "-", omittingEmptySubsequences: false)
        guard verses.count <= 2, let verse = Int(verses[0]), verse >= 1 else { return nil }
        guard verses.count == 2 else { return Reference(book: book, chapter: chapter, verse: verse) }
        guard let endVerse = Int(verses[1]), endVerse > verse else { return nil }
        return Reference(book: book, chapter: chapter, verse: verse, endVerse: endVerse)
    }

    /// Books whose name, short name or an alias starts with `prefix`, in canon order.
    public static func matchBooks(prefix: String) -> [Book] {
        let key = bookKey(prefix)
        guard !key.isEmpty else { return [] }
        return BookCatalog.all.filter { book in
            candidates(for: book).contains { $0.hasPrefix(key) }
        }
    }

    // MARK: - Helpers

    private static func normalise(_ input: String) -> String {
        var text = input.lowercased()
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
        // "matt.5.3" → "matt 5:3": a dot between digits is a chapter/verse separator, any other dot is a space.
        var chars = Array(text)
        for i in chars.indices where chars[i] == "." {
            let before = i > 0 ? chars[i - 1] : " "
            let after = i + 1 < chars.count ? chars[i + 1] : " "
            chars[i] = (before.isNumber && after.isNumber) ? ":" : " "
        }
        text = String(chars)
        return text.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" }).joined(separator: " ")
    }

    /// Lowercase alphanumerics only: `"1 Cor"` → `"1cor"`, `"Song of Solomon"` → `"songofsolomon"`.
    private static func bookKey(_ text: String) -> String {
        String(text.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    private static func candidates(for book: Book) -> [String] {
        ([book.name, book.shortName] + book.aliases).map(bookKey)
    }

    /// Each book with its keys, in canon order, worked out once.
    private static let keyedBooks: [(book: Book, keys: [String])] = BookCatalog.all.map { ($0, candidates(for: $0)) }
    /// A key's book: the first in canon order that has it.
    private static let bookByKey: [String: Book] = {
        var byKey: [String: Book] = [:]
        for entry in keyedBooks {
            for key in entry.keys where byKey[key] == nil { byKey[key] = entry.book }
        }
        return byKey
    }()

    private static func resolveBook(_ bookPart: String, exact: Bool) -> Book? {
        let key = bookKey(bookPart)
        guard !key.isEmpty else { return nil }
        if let match = bookByKey[key] {
            return match
        }
        guard !exact else { return nil }
        let prefixMatches = keyedBooks.filter { entry in entry.keys.contains { $0.hasPrefix(key) } }.map(\.book)
        // Ambiguous prefix: prefer the shortest name, then canon order (already the catalog order).
        return prefixMatches.min { a, b in
            a.name.count != b.name.count ? a.name.count < b.name.count : a.order < b.order
        }
    }
}
