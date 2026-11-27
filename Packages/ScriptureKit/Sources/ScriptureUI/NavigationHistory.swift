import ScriptureData

/// Browser-style back and forward stacks over chapter locations, each remembering the verse read there.
public struct NavigationHistory: Equatable, Sendable {
    public static let maximumBackEntries = 50

    private struct Entry: Equatable, Sendable {
        var location: ChapterLocation
        var verse: Int
    }

    private var currentEntry: Entry?
    private var back: [Entry] = []
    private var forward: [Entry] = []

    public init() {}

    public var current: ChapterLocation? { currentEntry?.location }
    /// The verse last read at `current`; 1 when nothing was reported.
    public var currentVerse: Int { currentEntry?.verse ?? 1 }
    public var canGoBack: Bool { !back.isEmpty }
    public var canGoForward: Bool { !forward.isEmpty }

    /// Makes `location` current, remembering the previous location. No-op when already there.
    public mutating func go(to location: ChapterLocation, verse: Int = 1) {
        guard location != current else { return }
        if let currentEntry {
            back.append(currentEntry)
            if back.count > Self.maximumBackEntries {
                back.removeFirst(back.count - Self.maximumBackEntries)
            }
        }
        forward.removeAll()
        currentEntry = Entry(location: location, verse: verse)
    }

    /// Records the verse being read at the current location, so Back and Forward return there.
    public mutating func updateCurrentVerse(_ verse: Int) {
        currentEntry?.verse = verse
    }

    @discardableResult
    public mutating func goBack() -> ChapterLocation? {
        guard let previous = back.popLast() else { return nil }
        if let currentEntry { forward.append(currentEntry) }
        currentEntry = previous
        return previous.location
    }

    @discardableResult
    public mutating func goForward() -> ChapterLocation? {
        guard let next = forward.popLast() else { return nil }
        if let currentEntry { back.append(currentEntry) }
        currentEntry = next
        return next.location
    }
}
