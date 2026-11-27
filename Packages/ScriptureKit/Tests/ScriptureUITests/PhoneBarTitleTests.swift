#if os(iOS)
import Testing
import UIKit
@testable import ScriptureUI

/// The bar title (the phone's running head) keeps each page style's voice but takes its size from
/// Dynamic Type, as chrome does, and always stands above the translation's caption under it.
@MainActor @Suite struct PhoneBarTitleTests {
    /// Up to the cap, where the inline bar still holds the title, caption and progress line.
    private let sizes: [UIContentSizeCategory] = [.extraSmall, .large, .extraLarge, .extraExtraExtraLarge]

    /// Fix round 2: past xxxLarge the title stops growing (the large content viewer takes over).
    @Test(arguments: PageStyle.allCases)
    func theTitleStopsGrowingAtTheAccessibilitySizes(style: PageStyle) {
        var prefs = ReaderPreferences.default
        prefs.style = style
        let typography = ReaderTypography.styled(prefs)
        let cap = PhoneBarTitleType(typography: typography, contentSize: .extraExtraExtraLarge)
        for category in [UIContentSizeCategory.accessibilityMedium, .accessibilityExtraExtraExtraLarge] {
            let type = PhoneBarTitleType(typography: typography, contentSize: category)
            #expect(type.font.pointSize == cap.font.pointSize && type.kern == cap.kern
                    && type.minimumScaleFactor == cap.minimumScaleFactor, "\(style) \(category.rawValue)")
        }
        #expect(PhoneBarTitleType.largestSize == .extraExtraExtraLarge && PhoneBarTitleType.largestDynamicTypeSize == .xxxLarge)
    }

    private func size(_ style: UIFont.TextStyle, _ category: UIContentSizeCategory) -> CGFloat {
        UIFont.preferredFont(forTextStyle: style, compatibleWith: UITraitCollection(preferredContentSizeCategory: category)).pointSize
    }

    @Test(arguments: PageStyle.allCases)
    func theTitleFollowsDynamicTypeInItsStylesVoice(style: PageStyle) {
        var prefs = ReaderPreferences.default
        prefs.style = style
        prefs.fontSize = 14
        let typography = ReaderTypography.styled(prefs)
        let textStyle = PhoneBarTitleType.textStyle(for: style)
        #expect(textStyle == ((style == .printed || style == .study) ? .footnote : .headline))
        var last: CGFloat = 0
        for category in sizes {
            let type = PhoneBarTitleType(typography: typography, contentSize: category)
            #expect(type.font.pointSize == size(textStyle, category), "\(style) \(category.rawValue)")
            #expect(type.font.pointSize > last)
            last = type.font.pointSize
            // The style's face and features, at the new size.
            #expect(type.font.fontName == typography.runningHeadFont.fontName)
            // The tracking keeps its ratio to the size.
            let ratio = typography.runningHeadKern / typography.runningHeadFont.pointSize
            #expect(abs(type.kern - ratio * type.font.pointSize) < 0.001)
            // Never smaller than the caption under it, even when shrunk to fit.
            // A long name may shrink a little under the caption to stay on the screen's centre.
            #expect(type.font.pointSize * type.minimumScaleFactor >= size(.caption1, category) * 0.8 - 0.001)
            #expect(type.minimumScaleFactor <= 1)
        }
    }

    /// Fix round 2: a head report queued for one book is dropped if another book shows when it
    /// arrives, whatever its chapter number.
    @Test func aHeadReportFromAReplacedBookIsDropped() {
        #expect(PhoneChapterTextView.isCurrent(reportedFor: "JHN", showing: "JHN"))
        #expect(!PhoneChapterTextView.isCurrent(reportedFor: "JHN", showing: "ACT"))
        #expect(!PhoneChapterTextView.isCurrent(reportedFor: nil, showing: "ACT"))
    }

    /// The reader's own size no longer sets it: 14 pt and 28 pt give the same title.
    @Test func theReaderSizeDoesNotSizeTheTitle() {
        var small = ReaderPreferences.default
        small.fontSize = 14
        var large = ReaderPreferences.default
        large.fontSize = 28
        let a = PhoneBarTitleType(typography: .styled(small), contentSize: .large)
        let b = PhoneBarTitleType(typography: .styled(large), contentSize: .large)
        #expect(a.font.pointSize == b.font.pointSize && abs(a.kern - b.kern) < 0.05)
    }

    /// Matt, 2026-11-13: the book and chapter are centred between the library button and the two
    /// buttons on the right, not on the screen and not in the space the bar happens to give its
    /// title. On his phone the library button's glass ends 64 points in and the right-hand
    /// buttons' begins at 316: the title's middle is 190, whatever its length, and it may be as
    /// wide as that gap less the air at each end. Before the buttons are known it keeps to the
    /// space it was given.
    @Test func theTitleIsCentredBetweenTheBarsButtons() throws {
        // The labels as measured: the library's books, the highlighter's pen.
        let library = CGRect(x: 29, y: 60, width: 26, height: 24)
        let pen = CGRect(x: 330, y: 60, width: 22, height: 24)
        let gap = try #require(PhoneBarTitle.gap(leading: library, trailing: pen))
        #expect(gap.lowerBound == 64 && gap.upperBound == 315, "\(gap)")
        let slot = CGRect(x: 72, y: 60, width: 208, height: 44)
        let placing = PhoneBarTitle.placing(slot: slot, gap: gap)
        #expect(placing.midX == 189.5)
        #expect(placing.width == 251 - 2 * PhoneBarTitle.air)
        // A wide leading button (back from a lookup, "‹ John 3") ends its glass past its label.
        let back = CGRect(x: 30, y: 60, width: 80, height: 24)
        #expect(PhoneBarTitle.gap(leading: back, trailing: pen)?.lowerBound == 119)
        // Not yet measured, or no space between them: the bar's own space.
        #expect(PhoneBarTitle.gap(leading: nil, trailing: pen) == nil)
        #expect(PhoneBarTitle.gap(leading: CGRect(x: 30, y: 60, width: 300, height: 24), trailing: pen) == nil)
        let unknown = PhoneBarTitle.placing(slot: slot, gap: nil)
        #expect(unknown.midX == slot.midX && unknown.width == slot.width)
    }

    /// Under VoiceOver the highlighter is hidden and the menu stands alone at the right: the title
    /// is centred between the library button and the menu's own glass, a lone button's 44 pt
    /// circle, not left in the bar's slot (parked 2026-11-13).
    @Test func underVoiceOverTheTitleIsCentredBeforeTheMenuAlone() throws {
        let library = CGRect(x: 29, y: 60, width: 26, height: 24)
        let menu = CGRect(x: 363, y: 60, width: 22, height: 24)
        let gap = try #require(PhoneBarTitle.gap(leading: library, trailing: menu, trailingIsLone: true))
        #expect(gap.lowerBound == 64 && gap.upperBound == 352, "\(gap)")
    }
}
#endif
