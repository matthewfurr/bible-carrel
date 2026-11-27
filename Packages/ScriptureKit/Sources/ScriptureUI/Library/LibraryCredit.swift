import Foundation
import SwiftUI

/// The credit for Theographic's tables and the sources inside them (spec 7), shown in About and
/// under the Library's pages.
public enum LibraryCredit {
    public static let text = "People, places and events from Theographic Bible Metadata by Robert Rouse (viz.bible), CC BY-SA 4.0, changed: converted to this app's tables. It includes data from STEPBible (CC BY 4.0), OpenBible.info (CC BY 4.0) and Easton's Bible Dictionary (1897)."

    /// Each linked phrase, in the order it first appears in `text`.
    private static let links: [(phrase: String, url: String)] = [
        ("Theographic Bible Metadata", "https://github.com/robertrouse/theographic-bible-metadata"),
        ("viz.bible", "https://viz.bible"),
        ("CC BY-SA 4.0", "https://creativecommons.org/licenses/by-sa/4.0/"),
        ("STEPBible", "https://github.com/STEPBible/STEPBible-Data"),
        ("CC BY 4.0", "https://creativecommons.org/licenses/by/4.0/"),
        ("OpenBible.info", "https://www.openbible.info/geo/"),
        ("CC BY 4.0", "https://creativecommons.org/licenses/by/4.0/"),
    ]

    /// `text` with its links.
    public static var linked: AttributedString {
        var result = AttributedString(text)
        var from = result.startIndex
        for (phrase, url) in links {
            guard let range = result[from...].range(of: phrase), let target = URL(string: url) else { continue }
            result[range].link = target
            from = range.upperBound
        }
        return result
    }
}

/// The credit as a paragraph: `.caption`, secondary ink, the links in the accent.
public struct LibraryCreditLine: View {
    @Environment(\.libraryType) private var type

    public init() {}

    public var body: some View {
        Text(LibraryCredit.linked)
            .font(type.font(.caption))
            .foregroundStyle(Color.inkSecondary)
            .tint(Color.accent)
            .fixedSize(horizontal: false, vertical: true)
    }
}
