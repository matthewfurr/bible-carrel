import ScriptureData
import SwiftUI

/// A chapter's heading in Places' By chapter list (spec 5.4, 5.5), shared by the Mac's column and the phone's
/// sheet: "Chapter 1" in the group label's voice, its place count trailing. A button: a click or tap chooses the
/// chapter, on the `accent.wash` at radius `md` like a chosen row (`showsWash`, which a chosen row of the chapter
/// takes over; `isChosen` is the selected trait, which stays), reporting its rectangle (the Mac's focus ring)
/// in `coordinateSpace`. Space `md` above (none above the first) and `xxs` below set a chapter apart from the
/// rows of the last. One accessibility element, "Chapter 1, 6 places", with the header trait; its help tag says what a
/// click does ("Show chapter 1 on the map", or, washed, "Show the whole book on the map").
struct PlacesChapterHeading: View {
    let chapter: BookPlaces.Chapter
    let isChosen: Bool
    let showsWash: Bool
    let horizontalPadding: CGFloat
    let onChosenRect: ((CGRect) -> Void)?
    let coordinateSpace: String?
    let isFirst: Bool
    /// The least height of the heading's band (the phone's scaled 44 pt touch target); none on the Mac.
    let minimumHeight: CGFloat
    let onChoose: () -> Void
    @Environment(\.libraryType) private var type

    init(chapter: BookPlaces.Chapter, isChosen: Bool, showsWash: Bool, horizontalPadding: CGFloat, onChosenRect: ((CGRect) -> Void)?,
         coordinateSpace: String?, isFirst: Bool = false, minimumHeight: CGFloat = 0, onChoose: @escaping () -> Void) {
        self.chapter = chapter
        self.isChosen = isChosen
        self.showsWash = showsWash
        self.horizontalPadding = horizontalPadding
        self.onChosenRect = onChosenRect
        self.coordinateSpace = coordinateSpace
        self.isFirst = isFirst
        self.minimumHeight = minimumHeight
        self.onChoose = onChoose
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
            GroupLabel("Chapter \(chapter.number)", size: type.readerSize == nil ? nil : type.size(.caption2))
            Spacer(minLength: AppSpacing.xxs)
            Text(chapter.places.count, format: .number)
                .font(type.font(.caption).monospacedDigit())
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, AppSpacing.xxs)
        .frame(minHeight: minimumHeight)
        .background {
            if showsWash {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(Color.accentWash)
                    .onGeometryChange(for: CGRect.self) { proxy in
                        coordinateSpace.map { proxy.frame(in: .named($0)) } ?? .zero
                    } action: { onChosenRect?($0) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onChoose)
        .help(PlacesChapters.headingHelp(chapter.number, clears: showsWash))
        .padding(.top, isFirst ? 0 : AppSpacing.md)
        .padding(.bottom, AppSpacing.xxs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PlacesChapters.headingSpoken(chapter))
        .accessibilityAddTraits(isChosen ? [.isButton, .isHeader, .isSelected] : [.isButton, .isHeader])
        .accessibilityAction { onChoose() }
    }
}
