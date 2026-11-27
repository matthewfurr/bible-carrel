import Foundation

/// One Server-Sent Event: its `event:` name, if any, and its `data:` lines joined with newlines.
public struct SSEEvent: Equatable, Sendable {
    public let name: String?
    public let data: String

    public init(name: String?, data: String) {
        self.name = name
        self.data = data
    }
}

/// Incremental parsing of a `text/event-stream` body (WHATWG EventSource rules): chunks may split
/// anywhere, even inside a multibyte character; a blank line dispatches the event being built;
/// `event:` names it, several `data:` lines join with `\n`, one space after the colon is dropped,
/// `:` lines are comments, `id:` and `retry:` are ignored, and an event with no data is not
/// dispatched.
public struct SSEParser: Sendable {
    private var pendingBytes: [UInt8] = []
    private var pendingText = ""
    private var name: String?
    private var dataLines: [String] = []

    public init() {}

    /// Feeds raw bytes; an incomplete UTF-8 sequence at the end waits for the next chunk.
    public mutating func feed(_ bytes: some Sequence<UInt8>) -> [SSEEvent] {
        pendingBytes.append(contentsOf: bytes)
        let complete = Self.completeUTF8Prefix(pendingBytes)
        let text = String(decoding: pendingBytes[..<complete], as: UTF8.self)
        pendingBytes.removeFirst(complete)
        return feed(text)
    }

    public mutating func feed(_ chunk: String) -> [SSEEvent] {
        pendingText += chunk
        var events: [SSEEvent] = []
        while let line = nextLine() {
            if let event = consume(line: line) { events.append(event) }
        }
        return events
    }

    /// Dispatches a last event that had no trailing blank line.
    public mutating func finish() -> [SSEEvent] {
        var events: [SSEEvent] = []
        if !pendingText.isEmpty {
            let rest = pendingText
            pendingText = ""
            if let event = consume(line: rest) { events.append(event) }
        }
        if let event = dispatch() { events.append(event) }
        return events
    }

    // MARK: - Lines

    /// The next complete line, ended by `\n`, `\r\n` or `\r`. A lone `\r` at the very end waits,
    /// since an `\n` may follow it.
    private mutating func nextLine() -> String? {
        let scalars = Array(pendingText.unicodeScalars)
        for (index, scalar) in scalars.enumerated() {
            switch scalar {
            case "\n":
                let line = String(String.UnicodeScalarView(scalars[..<index]))
                pendingText = String(String.UnicodeScalarView(scalars[(index + 1)...]))
                return line
            case "\r":
                guard index + 1 < scalars.count else { return nil }
                let line = String(String.UnicodeScalarView(scalars[..<index]))
                let skip = scalars[index + 1] == "\n" ? 2 : 1
                pendingText = String(String.UnicodeScalarView(scalars[(index + skip)...]))
                return line
            default:
                continue
            }
        }
        return nil
    }

    private mutating func consume(line: String) -> SSEEvent? {
        if line.isEmpty { return dispatch() }
        if line.hasPrefix(":") { return nil }
        let field: String
        var value: String
        if let colon = line.firstIndex(of: ":") {
            field = String(line[..<colon])
            value = String(line[line.index(after: colon)...])
            if value.hasPrefix(" ") { value.removeFirst() }
        } else {
            field = line
            value = ""
        }
        switch field {
        case "event": name = value
        case "data": dataLines.append(value)
        default: break
        }
        return nil
    }

    private mutating func dispatch() -> SSEEvent? {
        defer { name = nil; dataLines = [] }
        guard !dataLines.isEmpty else { return nil }
        return SSEEvent(name: name, data: dataLines.joined(separator: "\n"))
    }

    /// The length of the longest prefix that ends on a character boundary.
    private static func completeUTF8Prefix(_ bytes: [UInt8]) -> Int {
        var end = bytes.count
        // Walk back over continuation bytes to the last lead byte and check its sequence is whole.
        var i = end - 1
        while i >= 0, i >= end - 4 {
            let byte = bytes[i]
            if byte & 0xC0 != 0x80 {
                let needed: Int
                switch byte {
                case 0x00...0x7F: needed = 1
                case 0xC0...0xDF: needed = 2
                case 0xE0...0xEF: needed = 3
                case 0xF0...0xF7: needed = 4
                default: needed = 1
                }
                if end - i < needed { end = i }
                return end
            }
            i -= 1
        }
        return end
    }
}
