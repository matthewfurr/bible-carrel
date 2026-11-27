import Foundation

/// The book thumb's track (spec 3.3 and 4.4): the whole book along the reader's right edge, cut
/// into one equal band per chapter the translation has, top to bottom. A drag reads the chapter
/// under the finger or pointer from its fraction of the track; letting go lands at that chapter's
/// start, unless it is the chapter being read. A one-chapter book has no thumb.
public struct BookThumb: Equatable, Sendable {
    /// The chapters this translation has, ascending. A chapter it lacks has no band.
    public let chapters: [Int]
    /// The chapter being read: its tick is lit.
    public let current: Int

    public init(chapters: [Int], current: Int) {
        self.chapters = chapters
        self.current = current
    }

    public var isShown: Bool { chapters.count > 1 }

    /// The chapter whose band holds `fraction` (0 is the top of the track, 1 the bottom); a
    /// fraction beyond either end clamps to the first or last chapter.
    public func chapter(atFraction fraction: Double) -> Int {
        guard !chapters.isEmpty else { return current }
        let count = chapters.count
        let band = fraction.isFinite ? Int((fraction * Double(count)).rounded(.down)) : 0
        return chapters[min(max(band, 0), count - 1)]
    }

    /// Where `chapter`'s tick sits: its band's centre. A chapter the translation lacks takes the
    /// band of the next one it has (the last band past the end).
    public func fraction(of chapter: Int) -> Double {
        guard !chapters.isEmpty else { return 0 }
        let index = chapters.firstIndex { $0 >= chapter } ?? chapters.count - 1
        return (Double(index) + 0.5) / Double(chapters.count)
    }

    /// A press on the track, from the chapter it came down on: whether it has since been on
    /// another. A press that never leaves its first chapter is no choice (it came down wherever
    /// the pointer or finger happened to be) and lands nowhere; once it has moved to another
    /// chapter it is choosing, and letting go lands on the chapter under it, the first included
    /// (Matt, 2026-11-13: away and back is a choice). Both apps, so a click on the Mac's ruler
    /// no longer jumps at once.
    public struct Press: Equatable, Sendable {
        public let start: Int
        public private(set) var hasLeftStart = false

        public init(start: Int, hasLeftStart: Bool = false) {
            self.start = start
            self.hasLeftStart = hasLeftStart
        }

        /// The press is over `chapter` now.
        public mutating func moved(to chapter: Int) {
            if chapter != start { hasLeftStart = true }
        }

        /// Whether letting go on `chapter` is a choice.
        public func chooses(releasingOn chapter: Int) -> Bool {
            hasLeftStart || chapter != start
        }
    }

    /// Where letting go on `chapter` lands: its first verse. Nil on the chapter being read, where
    /// letting go does nothing.
    public func landing(on chapter: Int) -> ScrollTarget? {
        chapter == current ? nil : ScrollTarget(chapter: chapter, verse: 1)
    }
}
