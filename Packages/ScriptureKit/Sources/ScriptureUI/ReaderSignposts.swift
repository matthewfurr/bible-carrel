import os

/// Signpost intervals around the reader's expensive work, for Instruments (os_signpost, subsystem
/// below, category `reader`). They cost nothing when no one records, so they stay in release builds.
enum ReaderSignposts {
    static let signposter = OSSignposter(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "reader")

    static let layoutBuild: StaticString = "ChapterLayout.build"
    static let replaceText: StaticString = "replaceText"
    static let sizeToLayout: StaticString = "sizeToLayout"
    static let applyBackgrounds: StaticString = "applyBackgrounds"
    static let reportReadingPosition: StaticString = "reportReadingPosition"
    static let columnWidthDidChange: StaticString = "columnWidthDidChange"
}
