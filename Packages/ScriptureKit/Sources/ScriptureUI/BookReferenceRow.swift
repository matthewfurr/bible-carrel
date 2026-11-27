import SwiftUI

/// Under a book's name in the Library (spec 5, Matt chose the rounded-square outlines with
/// `play.rectangle`): four outlined icons, each with its label beneath, in four equal columns
/// across the row, each icon centred in its column (Matt, 2026-11-16: "evenly spaced across and
/// centered"). BibleProject opens the
/// book's overview video, or offers a menu of them when the book has more than one; People,
/// Places and About open that view of the book when the book has it (`availableTopics`), the open
/// one on the accent wash, and are drawn quiet, and read "not available for this book", when it
/// has not. The outline is a stroke round a button, with no fill: not a card.
public struct BookReferenceRow: View {
    let bookCode: String
    let bookName: String
    /// The views the book has; the others are drawn quiet.
    let availableTopics: Set<LibraryTopic>
    /// The view open now, on the accent wash.
    let activeTopic: LibraryTopic?
    let onOpenTopic: (LibraryTopic) -> Void
    /// Opens a video's page: a Safari sheet on the phone, the default browser on the Mac.
    let onOpenVideo: (BookVideo) -> Void

    public init(bookCode: String, bookName: String, availableTopics: Set<LibraryTopic>, activeTopic: LibraryTopic?,
                onOpenTopic: @escaping (LibraryTopic) -> Void, onOpenVideo: @escaping (BookVideo) -> Void) {
        self.bookCode = bookCode
        self.bookName = bookName
        self.availableTopics = availableTopics
        self.activeTopic = activeTopic
        self.onOpenTopic = onOpenTopic
        self.onOpenVideo = onOpenVideo
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            bibleProject.frame(maxWidth: .infinity)
            topic(.people, kind: .people)
            topic(.places, kind: .places)
            topic(.about, kind: .about)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private func topic(_ topic: LibraryTopic, kind: BookReferenceIcon.Kind) -> some View {
        Group {
            if availableTopics.contains(topic) {
                Button { onOpenTopic(topic) } label: {
                    BookReferenceIcon(kind: kind, isAvailable: true, isActive: activeTopic == topic)
                }
                .buttonStyle(.plain)
            } else {
                BookReferenceIcon(kind: kind, isAvailable: false)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var bibleProject: some View {
        let videos = BibleProjectVideos.videos(forBook: bookCode)
        switch videos.count {
        case 0:
            BookReferenceIcon(kind: .bibleProject, isAvailable: false)
        case 1:
            Button { onOpenVideo(videos[0]) } label: {
                BookReferenceIcon(kind: .bibleProject, isAvailable: true)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens BibleProject's video on \(bookName)")
        default:
            Menu {
                ForEach(videos, id: \.self) { video in
                    Button(video.title) { onOpenVideo(video) }
                }
            } label: {
                BookReferenceIcon(kind: .bibleProject, isAvailable: true)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityHint("Lists BibleProject's videos on \(bookName)")
        }
    }
}

/// One of the row's icons: the symbol in a rounded-square outline, its label beneath. The open
/// view's sits on the accent wash. One not available is drawn quieter, its outline the rule, and
/// VoiceOver says so.
struct BookReferenceIcon: View {
    enum Kind {
        case bibleProject, people, places, about

        var title: String {
            switch self {
            case .bibleProject: "BibleProject"
            case .people: "People"
            case .places: "Places"
            case .about: "About"
            }
        }

        var symbol: String {
            switch self {
            case .bibleProject: "play.rectangle"
            case .people: "person.2"
            case .places: "map"
            case .about: "info.circle"
            }
        }
    }

    let kind: Kind
    let isAvailable: Bool
    var isActive = false
    @ScaledMetric(relativeTo: .title3) private var side: CGFloat = 36
    @ScaledMetric(relativeTo: .title3) private var outline: CGFloat = 1.25
    @ScaledMetric(relativeTo: .title3) private var radius: CGFloat = AppRadius.xxl

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        VStack(spacing: AppSpacing.xxs) {
            Image(systemName: kind.symbol)
                .font(.body)
                .foregroundStyle(isAvailable ? Color.accent : Color.inkTertiary)
                .frame(width: side, height: side)
                .background(isActive ? Color.accentWash : Color.clear, in: shape)
                .overlay { shape.strokeBorder(isAvailable ? Color.accent : Color.inkRule, lineWidth: outline) }
                .contentShape(shape)
            Text(kind.title)
                .font(.caption2)
                .foregroundStyle(isAvailable ? Color.inkSecondary : Color.inkTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.title)
        .accessibilityValue(isAvailable ? "" : "not available for this book")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : isAvailable ? .isButton : [])
    }
}
