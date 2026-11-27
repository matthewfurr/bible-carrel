import SwiftUI

/// The quiet mark on a note with kept versions ("2 versions"), or on a kept version whose note is
/// gone ("Kept version") (spec 4.1, 4.2): `square.on.square` and the words in `.caption`
/// `ink.secondary`, on a tonal step of overlay paper in a capsule. No stroke, never red, never
/// the accent: it reports that nothing was lost and asks for nothing.
public struct VersionsMark: View {
    let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            Image(systemName: VersionText.symbolName)
                .accessibilityHidden(true)
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(Color.inkSecondary)
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, AppSpacing.xxs)
        .background(Color.paperOverlay, in: Capsule())
    }
}

#if os(macOS)
/// The mark as a button that shows the versions in a system popover on itself: the versions view
/// in a scroll view, padded `sm`, a scaled 380 pt wide (its content 356 pt, room for a note's three
/// choices in one row at 24 pt) and at most a scaled 420 pt tall. The popover closes once nothing
/// is left to settle. Its choices undo through `undoManager`, the
/// window's, which the popover's own window would not have.
struct VersionsMarkButton: View {
    let text: String
    let subject: VersionsSubject
    @Binding var isShown: Bool
    let undoManager: UndoManager?

    @Environment(\.noteVersions) private var versions
    @ScaledMetric(relativeTo: .caption) private var hitHeight: CGFloat = 24

    var body: some View {
        Button { isShown = true } label: {
            VersionsMark(text: text)
                .frame(minHeight: hitHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(VersionText.help(for: subject))
        .accessibilityLabel(text)
        .popover(isPresented: $isShown, arrowEdge: .bottom) {
            if let versions {
                NoteVersionsPopover(subject: subject, model: versions, undoManager: undoManager) { isShown = false }
            }
        }
    }
}

/// The popover's content: the versions view, scrolling once it is taller than the popover may be.
struct NoteVersionsPopover: View {
    let subject: VersionsSubject
    let model: NoteVersionsModel
    let undoManager: UndoManager?
    let onSettled: () -> Void

    @ScaledMetric(relativeTo: .callout) private var width: CGFloat = 380
    @ScaledMetric(relativeTo: .callout) private var maxHeight: CGFloat = 420

    var body: some View {
        // As tall as the versions up to the limit, then the scroll view takes over.
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
        .frame(width: width)
        .frame(maxHeight: maxHeight, alignment: .top)
    }

    private var content: some View {
        NoteVersionsView(subject: subject, model: model, undoManager: undoManager, onSettled: onSettled)
            .padding(AppSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
