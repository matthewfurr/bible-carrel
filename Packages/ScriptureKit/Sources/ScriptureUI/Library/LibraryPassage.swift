import ScriptureData
import SwiftUI

/// What a reference clicked in the Library shows: its verses in the translation being read, or
/// the one line that says the translation has none (the CPDV's Psalms, a verse the ESV leaves
/// out). Loading it changes nothing in the model; only Open does.
public enum LibraryPassage: Equatable, Sendable {
    case verses(VersePreview), missing(Reference)

    @MainActor public static func load(_ reference: Reference, navigation: NavigationModel) -> LibraryPassage {
        navigation.versePreview(reference).map { .verses($0) } ?? .missing(reference)
    }

    /// "John 1:1 is not in the translation being read."; nil when there are verses.
    public var missingLine: String? {
        guard case .missing(let reference) = self else { return nil }
        return "\(reference.displayString) is not in the translation being read."
    }
}

/// A passage in a popover: the verses with Open, or the missing line with no button.
struct LibraryPassageView: View {
    let passage: LibraryPassage
    let onOpen: () -> Void

    @ScaledMetric(relativeTo: .body) private var width: CGFloat = 280

    var body: some View {
        switch passage {
        case .verses(let preview):
            VersePreviewView(preview: preview, openTitle: "Open", onOpen: onOpen)
        case .missing:
            Text(passage.missingLine ?? "")
                .font(.callout)
                .foregroundStyle(Color.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(AppSpacing.sm)
                .frame(width: width, alignment: .leading)
        }
    }
}
