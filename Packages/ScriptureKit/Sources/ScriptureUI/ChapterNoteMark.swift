import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// The chapter's own notes, as one mark at the far right of the chapter heading's line: the
/// outline paper (`doc`) in the accent with the count inside it ("9+" above nine). It is a
/// button: the Mac opens the notes column, the phone Notes in This Chapter. With no chapter notes
/// it keeps its place on the line but shows nothing and is not offered, so the heading never
/// changes height when a note comes or goes. The Mac's book scroll puts one on every chapter's
/// opening line and one in the running head, so there each names its chapter ("John 3").
public struct ChapterNoteMark: View {
    let count: Int
    /// The chapter the notes belong to, for VoiceOver and the help tag; nil where only one
    /// chapter is ever on the page (the phone).
    let chapter: String?
    let action: () -> Void
    /// The touch area, grown with the heading's text size.
    @ScaledMetric(relativeTo: .title) private var hitSize: CGFloat = Self.minimumHitSize
    /// The count's inset from the page's sides and foot, grown with the paper.
    @ScaledMetric(relativeTo: .title) private var countInset: CGFloat = AppSpacing.xxs
    /// The count's size: the caption size on the phone (the body size on the Mac) at the default
    /// text size, grown with the heading (`.title`) rather than with the caption, which grows
    /// faster at the accessibility sizes and would run into the folded corner.
    @ScaledMetric(relativeTo: .title) private var countSize: CGFloat = Self.countBaseSize

    #if os(iOS)
    static let minimumHitSize: CGFloat = 44
    static let paperScale: Image.Scale = .medium
    static let countBaseSize = UIFont.preferredFont(
        forTextStyle: .caption1, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)).pointSize
    #else
    static let minimumHitSize: CGFloat = AppSpacing.lg
    static let paperScale: Image.Scale = .large
    /// The Mac has no Dynamic Type to grow a caption, so its count starts at the body size.
    static let countBaseSize = NSFont.preferredFont(forTextStyle: .body).pointSize
    #endif

    public init(count: Int, chapter: String? = nil, action: @escaping () -> Void) {
        self.count = count
        self.chapter = chapter
        self.action = action
    }

    /// The number drawn inside the paper.
    static func countText(_ count: Int) -> String {
        count > 9 ? "9+" : "\(count)"
    }

    /// What VoiceOver reads, and the Mac's help tag.
    static func label(_ count: Int) -> String {
        count == 1 ? "1 chapter note" : "\(count) chapter notes"
    }

    /// The same, naming the chapter: "2 chapter notes in John 3".
    static func label(_ count: Int, chapter: String) -> String {
        "\(label(count)) in \(chapter)"
    }

    private var spokenLabel: String {
        chapter.map { Self.label(count, chapter: $0) } ?? Self.label(count)
    }

    public var body: some View {
        Button(action: action) {
            // The paper takes the heading's text style, so it and the number scale with it.
            Image(systemName: "doc")
                .font(.title)
                // A page tall enough to hold its number below the folded corner: the Mac's
                // `.title` is smaller than the phone's, so the Mac takes the large scale.
                .imageScale(Self.paperScale)
                // In the lower part of the page, clear of the folded corner.
                .overlay(alignment: .bottom) {
                    Text(Self.countText(count))
                        .font(.system(size: countSize, weight: .semibold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, countInset)
                        .padding(.bottom, countInset)
                }
                .foregroundStyle(Color.accent)
                .frame(minWidth: hitSize, minHeight: hitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // As the heading: the chapter text keeps the window's first focus.
        .focusable(false)
        .help(spokenLabel)
        .accessibilityLabel(spokenLabel)
        .opacity(count > 0 ? 1 : 0)
        .disabled(count == 0)
        .accessibilityHidden(count == 0)
    }
}
