import SwiftUI

/// The Mac's running head: a strip pinned over the top of the book scroll on `paper.page`, naming
/// the open chapter in the page style's label voice ("JOHN · 3"), with that chapter's
/// note mark at its trailing end. Under it, the progress line across the measure, then a 14 pt
/// fade from the page to clear, so the text scrolls beneath it rather than being cut off. The
/// whole head takes the controller's `headOpacity` (`RunningHeadFade`): invisible over the book's
/// title block and fading in as it scrolls away, so the title block morphs into the head. The
/// opacity and the progress are read from `chrome` by the small views that draw them, so a scroll
/// re-evaluates neither this view nor the reader around it.
///
/// A plain click goes to the book's chapter grid; the context menu offers Ask About This
/// Chapter. VoiceOver reads it as a header ("John, chapter 3").
struct RunningHeadView: View {
    /// The head's text, in the style's own case (`PageStyle.runningHead`).
    let text: String
    /// What VoiceOver reads (`RunningHeadTitle.spokenLabel`).
    let spokenLabel: String
    let typography: ReaderTypography
    /// The page's reports: the head's opacity and the chapter's progress.
    let chrome: ReaderChrome
    /// The open chapter, the one the head names.
    let chapter: Int
    /// The open chapter's chapter notes, and its name for the mark ("John 3").
    let noteCount: Int
    let chapterName: String
    let onTap: () -> Void
    let onAskAboutChapter: (() -> Void)?
    let onShowChapterNotes: () -> Void

    /// The fade under the progress line, from the mockup.
    static let fadeHeight: CGFloat = 14

    /// The strip's height: `xl` of air around one line of the head. The text controller's
    /// `headLineY` is this alone (it adds its own lead-in below).
    static func stripHeight(for typography: ReaderTypography) -> CGFloat {
        let font = typography.runningHeadFont
        return AppSpacing.xl + ceil(font.ascender - font.descender + font.leading)
    }

    /// The whole head over the scroll's top: the strip, the progress line and the fade. The
    /// vertical scroller's track starts below it.
    static func height(for typography: ReaderTypography) -> CGFloat {
        stripHeight(for: typography) + ReadingProgressLine.height + fadeHeight
    }

    var body: some View {
        // While it is still fading in over the title block, clicks reach the text beneath.
        RunningHeadFade(chrome: chrome, chapter: chapter, passesClicksWhileFaint: true) {
            VStack(spacing: 0) {
                strip
                RunningHeadProgressLine(chrome: chrome, chapter: chapter, measure: typography.measure)
                    .padding(.horizontal, AppSpacing.xxl)
                    .frame(maxWidth: .infinity)
                    .background(Color.paperPage)
                // The page fading to clear: a mask, so the fill stays the page token.
                Rectangle()
                    .fill(Color.paperPage)
                    .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                    .frame(height: Self.fadeHeight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private var strip: some View {
        HStack(spacing: AppSpacing.md) {
            if typography.runningHeadIsCentred {
                // A mark with no notes keeps its place unseen: it balances the real one, so a
                // centred head is centred on the measure.
                ChapterNoteMark(count: 0, action: {})
            }
            Button(action: onTap) {
                Text(text)
                    .font(Font(typography.runningHeadFont))
                    // `.kern`, as the page's own labels are set.
                    .kerning(typography.runningHeadKern)
                    .foregroundStyle(inkColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: typography.runningHeadIsCentred ? .center : .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // The chapter text keeps the window's first focus; ⇧⌘H reaches the grid from the keyboard.
            .focusable(false)
            .help("Show All Chapters")
            .accessibilityLabel(spokenLabel)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint("Shows the chapters of this book")
            .contextMenu {
                if let onAskAboutChapter {
                    // No symbol: menus tint it with the accent, and verdigris never stands for the assistant.
                    Button("Ask About This Chapter", action: onAskAboutChapter)
                }
            }
            .accessibilityActions {
                if let onAskAboutChapter {
                    Button("Ask About This Chapter", action: onAskAboutChapter)
                }
            }
            ChapterNoteMark(count: noteCount, chapter: chapterName, action: onShowChapterNotes)
        }
        .frame(maxWidth: typography.measure)
        .padding(.horizontal, AppSpacing.xxl)
        .frame(maxWidth: .infinity)
        .frame(height: Self.stripHeight(for: typography))
        .background(Color.paperPage)
    }

    /// The head's ink: the style's label color, resolved per appearance (Sepia included) like the palette's.
    private var inkColor: Color {
        Color(platform: typography.runningHeadColor)
    }
}

/// The running head at the opacity the page reports for the open `chapter` (`ReaderChrome`), on
/// both apps: the Mac's strip and the phone's bar title. Only this view reads the opacity, so its
/// content is not re-evaluated as the head fades. It follows the scroll without animation, and
/// VoiceOver skips it while it is hidden. With `passesClicksWhileFaint` (the Mac's strip), clicks
/// reach what is beneath until it is half shown.
struct RunningHeadFade<Content: View>: View {
    let chrome: ReaderChrome
    let chapter: Int
    var passesClicksWhileFaint = false
    @ViewBuilder let content: Content

    var body: some View {
        let opacity = chrome.headOpacity(for: chapter)
        content
            .opacity(opacity)
            // No animation: the head follows the scroll, as the progress line does.
            .transaction { $0.animation = nil }
            .allowsHitTesting(!passesClicksWhileFaint || opacity >= 0.5)
            .accessibilityHidden(opacity == 0)
    }
}
