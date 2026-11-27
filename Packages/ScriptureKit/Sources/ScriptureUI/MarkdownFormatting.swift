import Foundation

public enum MarkdownStyle: CaseIterable, Sendable {
    case bold, italic, heading, bulletedList, link

    public var symbolName: String {
        switch self {
        case .bold: "bold"
        case .italic: "italic"
        case .heading: "textformat.size"
        case .bulletedList: "list.bullet"
        case .link: "link"
        }
    }

    public var title: String {
        switch self {
        case .bold: "Bold"
        case .italic: "Italic"
        case .heading: "Heading"
        case .bulletedList: "Bulleted List"
        case .link: "Link"
        }
    }
}

/// Toggles markdown syntax for the note editor's toolbar: pressing a button twice returns the
/// text to what it was. Offsets are UTF-16 (`NSRange`).
public enum MarkdownFormatting {
    public static func apply(_ style: MarkdownStyle, to text: String, selection: NSRange) -> (text: String, selection: NSRange) {
        let source = text as NSString
        let safeLocation = min(max(selection.location, 0), source.length)
        let selection = NSRange(location: safeLocation, length: min(max(selection.length, 0), source.length - safeLocation))
        switch style {
        case .bold:
            return toggleWrapOrWord(source, selection, marker: "**")
        case .italic:
            return toggleWrapOrWord(source, selection, marker: "*")
        case .heading:
            return toggleLinePrefix(source, selection, prefix: "# ", everyLine: false)
        case .bulletedList:
            return toggleLinePrefix(source, selection, prefix: "- ", everyLine: true)
        case .link:
            let label = selection.length > 0 ? source.substring(with: selection) : "text"
            let replaced = source.replacingCharacters(in: selection, with: "[\(label)](url)")
            return (replaced, NSRange(location: selection.location + (label as NSString).length + 3, length: 3))
        }
    }

    // MARK: - Inline

    /// The word a caret touches: inside it, or at its start or end (letters or digits on at least
    /// one side). Nil between two spaces, on an empty line, or in an empty document.
    static func wordRange(in text: String, around caret: Int) -> NSRange? {
        let source = text as NSString
        guard caret >= 0, caret <= source.length else { return nil }
        func isWord(_ index: Int) -> Bool {
            guard index >= 0, index < source.length else { return false }
            return UnicodeScalar(source.character(at: index)).map { CharacterSet.alphanumerics.contains($0) } ?? false
        }
        guard isWord(caret - 1) || isWord(caret) else { return nil }
        var start = caret, end = caret
        while isWord(start - 1) { start -= 1 }
        while isWord(end) { end += 1 }
        return NSRange(location: start, length: end - start)
    }

    /// With no selection: a caret touching a word formats that word and stays on the same
    /// character; a caret touching no word gets an empty marker pair with the caret between.
    private static func toggleWrapOrWord(_ source: NSString, _ selection: NSRange, marker: String) -> (text: String, selection: NSRange) {
        guard selection.length == 0 else { return toggleWrap(source, selection, marker: marker) }
        let m = marker.utf16.count
        guard let word = wordRange(in: source as String, around: selection.location) else {
            let replaced = source.replacingCharacters(in: selection, with: marker + marker)
            return (replaced, NSRange(location: selection.location + m, length: 0))
        }
        let result = toggleWrap(source, word, marker: marker)
        let delta = (result.text as NSString).length - source.length
        let caret = selection.location + (delta > 0 ? m : -m)
        return (result.text, NSRange(location: max(0, caret), length: 0))
    }

    private static func toggleWrap(_ source: NSString, _ selection: NSRange, marker: String) -> (text: String, selection: NSRange) {
        let m = marker.utf16.count
        let selected = source.substring(with: selection)
        // The selection includes the markers.
        if selection.length >= 2 * m, selected.hasPrefix(marker), selected.hasSuffix(marker) {
            let inner = (selected as NSString).substring(with: NSRange(location: m, length: selection.length - 2 * m))
            return (source.replacingCharacters(in: selection, with: inner), NSRange(location: selection.location, length: inner.utf16.count))
        }
        // The markers sit just outside the selection.
        let before = NSRange(location: selection.location - m, length: m)
        let after = NSRange(location: NSMaxRange(selection), length: m)
        if before.location >= 0, NSMaxRange(after) <= source.length,
           source.substring(with: before) == marker, source.substring(with: after) == marker {
            let outer = NSRange(location: before.location, length: selection.length + 2 * m)
            return (source.replacingCharacters(in: outer, with: selected), NSRange(location: before.location, length: selection.length))
        }
        let inner = selection.length > 0 ? selected : "text"
        let replaced = source.replacingCharacters(in: selection, with: marker + inner + marker)
        return (replaced, NSRange(location: selection.location + m, length: inner.utf16.count))
    }

    // MARK: - Lines

    /// Adds `prefix` to the selected lines (the caret's line, or every line the selection
    /// touches when `everyLine`), or removes it when every one of them already has it.
    private static func toggleLinePrefix(_ source: NSString, _ selection: NSRange, prefix: String, everyLine: Bool) -> (text: String, selection: NSRange) {
        let p = prefix.utf16.count
        var lineStarts = [lineStart(in: source, before: selection.location)]
        if everyLine, selection.length > 0 {
            var cursor = lineStarts[0]
            while true {
                let newline = source.range(of: "\n", range: NSRange(location: cursor, length: source.length - cursor))
                guard newline.location != NSNotFound, NSMaxRange(newline) < NSMaxRange(selection) else { break }
                cursor = NSMaxRange(newline)
                lineStarts.append(cursor)
            }
        }
        let allPrefixed = lineStarts.allSatisfy { start in
            start + p <= source.length && source.substring(with: NSRange(location: start, length: p)) == prefix
        }
        let result = source.mutableCopy() as! NSMutableString
        var location = selection.location
        var end = NSMaxRange(selection)
        // Edit from the last line backwards so earlier offsets stay valid.
        for start in lineStarts.reversed() {
            if allPrefixed {
                result.deleteCharacters(in: NSRange(location: start, length: p))
                if start < location { location = max(start, location - p) }
                if start < end { end = max(start, end - p) }
            } else {
                result.insert(prefix, at: start)
                if start <= location { location += p }
                if start < end { end += p }
            }
        }
        if end < location { end = location }
        return (result as String, NSRange(location: location, length: end - location))
    }

    private static func lineStart(in source: NSString, before index: Int) -> Int {
        let newline = source.range(of: "\n", options: .backwards, range: NSRange(location: 0, length: index))
        return newline.location == NSNotFound ? 0 : NSMaxRange(newline)
    }
}

/// Which key finishes a note edit. By default Return inserts a newline and ⌘Return commits;
/// the `finishEditingWithReturn` setting makes Return commit and Shift-Return insert a newline.
public enum NoteEditingKeys {
    public static let settingKey = "finishEditingWithReturn"

    public enum Action: Equatable, Sendable {
        case finish
        case newline
    }

    public static func action(command: Bool, shift: Bool, finishWithReturn: Bool) -> Action {
        if command { return .finish }
        if finishWithReturn { return shift ? .newline : .finish }
        return .newline
    }

    /// Return (36) and keypad Enter (76), the keys the editor intercepts before AppKit's bindings.
    public static func isReturn(keyCode: UInt16) -> Bool {
        keyCode == 36 || keyCode == 76
    }
}
