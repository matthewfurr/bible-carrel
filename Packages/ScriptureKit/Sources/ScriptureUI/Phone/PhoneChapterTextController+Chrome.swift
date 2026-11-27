#if os(iOS)
import ScriptureData
import UIKit

/// What the phone's page carries besides the text and its markup: a chapter-note mark on the
/// chapter's opening line, and the VoiceOver Headings rotor over the opening and the section
/// headings.
extension PhoneChapterTextController {
    // MARK: - Chapter-note marks

    /// Makes, updates or removes the chapter's mark when it has chapter notes, and places it on
    /// the opening line. Positioned from line fragments, so it is re-run whenever the text
    /// reflows.
    func refreshChapterNoteMarks() {
        let counts = layout == nil ? [:] : chapterNoteCounts.filter { $0.value > 0 && layout?.section(for: $0.key) != nil }
        for (chapter, button) in chapterNoteMarkViews where counts[chapter] == nil {
            button.removeFromSuperview()
            chapterNoteMarkViews[chapter] = nil
        }
        guard let layout, !counts.isEmpty else { return }
        let bookName = BookCatalog.book(code: layout.id.book)?.chapterName ?? layout.id.book
        for (chapter, count) in counts {
            guard let section = layout.section(for: chapter) else { continue }
            let button: ChapterNoteMarkButton
            if let existing = chapterNoteMarkViews[chapter] {
                button = existing
            } else {
                button = ChapterNoteMarkButton(chapter: chapter)
                button.addAction(UIAction { [weak self, weak button] _ in
                    guard let self, let button else { return }
                    controlTapped(button) { self.onShowChapterNotes(chapter) }
                }, for: .primaryActionTriggered)
                textView.addSubview(button)
                chapterNoteMarkViews[chapter] = button
            }
            button.update(count: count, chapterName: "\(bookName) \(chapter)")
            button.isHidden = !placeOnOpeningLine(button, section: section)
        }
        applyOpeningNoteMarkAlpha()
    }

    /// The page's mark (beside its opening's label, or above Lectern's hairline) fades out as the
    /// bar's title fades in: drawn at the opening label's alpha, and hidden (out of reach and of
    /// VoiceOver) once the label has gone.
    func applyOpeningNoteMarkAlpha() {
        guard let chapter = layout?.chapters.lowerBound, let button = chapterNoteMarkViews[chapter] else { return }
        // A later chapter has no label to fade with: its mark simply scrolls with the page.
        let alpha = thumbHidesMarks ? 0 : (layout?.opensWithTitleBlock ?? true) ? openingLabelAlpha : 1
        button.alpha = alpha
        if alpha == 0 {
            button.isHidden = true
        } else if button.isHidden, let section = layout?.section(for: chapter) {
            button.isHidden = !placeOnOpeningLine(button, section: section)
        }
    }

    /// Centred on the opening's last line (the label, or the title block's CHAPTER 1), flush with
    /// the column's trailing edge; in Lectern, whose chapter text starts just below its hairline
    /// opening, in the air above that line (`marksAboveOpeningLine`). Its touch area is 44 pt
    /// around the glyph, but never over the label's text or the text below Lectern's hairline, and
    /// never past the screen's edge. False when the line cannot be found.
    private func placeOnOpeningLine(_ button: ChapterNoteMarkButton, section: BookSection) -> Bool {
        guard let layout, let line = lineFrame(forCharacterIndex: layout.openingMarkLineIndex(of: section)) else { return false }
        let inset = textView.textContainerInset
        let columnRight = textView.bounds.width - inset.right
        let size = button.naturalSize
        let midY = line.midY + inset.top
        let above = layout.marksAboveOpeningLine(of: section)
        let y = above ? line.minY + inset.top - AppSpacing.xs - size.height : midY - size.height / 2
        button.frame = CGRect(x: columnRight - size.width, y: y.rounded(), width: size.width, height: size.height)
        // Where the label's text on that line ends.
        let textEnd = above ? inset.left : segmentFrames(of: [section.openingRange])[0]
            .filter { abs($0.midY - midY) <= line.height / 2 }
            .map(\.maxX).max() ?? inset.left
        let reach = MarginMarkButton.minimumHitSize
        let frame = button.frame
        let right = min(textView.bounds.width, frame.midX + reach / 2)
        let left = max(right - reach, textEnd)
        let bottom = above ? min(frame.midY + reach / 2, line.minY + inset.top) : frame.midY + reach / 2
        let top = bottom - reach
        button.hitArea = CGRect(x: left, y: top, width: max(0, right - left), height: reach)
            .offsetBy(dx: -frame.minX, dy: -frame.minY)
        return true
    }

    // MARK: - Headings rotor

    /// VoiceOver's Headings rotor (the system's heading type, so the Headings setting and its
    /// next-heading gesture use it) over the book's title (on chapter 1), the chapter's opening
    /// and its section headings.
    func makeHeadingsRotor() -> UIAccessibilityCustomRotor {
        UIAccessibilityCustomRotor(systemType: .heading) { [weak self] predicate in
            MainActor.assumeIsolated { self?.heading(for: predicate) }
        }
    }

    private func heading(for predicate: UIAccessibilityCustomRotorSearchPredicate) -> UIAccessibilityCustomRotorItemResult? {
        let item = predicate.currentItem
        let current: Int? = (item.targetElement as? UITextView) === textView
            ? item.targetRange.map { textView.offset(from: textView.beginningOfDocument, to: $0.start) }
            : nil
        guard let heading = BookHeadings.item(from: current, forward: predicate.searchDirection == .next, in: headingItems),
              let start = textView.position(from: textView.beginningOfDocument, offset: heading.range.location),
              let end = textView.position(from: start, offset: heading.range.length),
              let range = textView.textRange(from: start, to: end)
        else { return nil }
        return UIAccessibilityCustomRotorItemResult(targetElement: textView, targetRange: range)
    }
}

/// A chapter's notes as one mark in the text, the phone's UIKit drawing of `ChapterNoteMark`: the
/// outline paper (`doc`) in the accent with the count inside it ("9+" above nine). A control, so
/// its taps win over the text view's own recognizers and the pen's, as the margin marks' do; the
/// glyph keeps its own frame and the touch lands within `hitArea` around it. The paper scales
/// down to fit a narrower frame.
final class ChapterNoteMarkButton: MarginMarkButton {
    let chapter: Int
    private(set) var count = 0
    /// The chapter the notes belong to, as the app names chapters ("John 3").
    private(set) var chapterName = ""
    private let paper = UIImageView()
    private let countLabel = UILabel()

    init(chapter: Int) {
        self.chapter = chapter
        super.init(frame: .zero)
        tintColor = Palette.accent.platformColor
        // The paper takes the heading's text style, as `ChapterNoteMark` does on the phone.
        paper.image = UIImage(systemName: "doc", withConfiguration: UIImage.SymbolConfiguration(textStyle: .title1, scale: .medium))
        paper.contentMode = .scaleAspectFit
        paper.isUserInteractionEnabled = false
        addSubview(paper)
        // The count's size is `ChapterNoteMark`'s: the caption size at the default text size,
        // grown with the heading (`.title`) rather than with the caption, so it stays clear of the
        // folded corner at the accessibility sizes.
        countLabel.font = UIFontMetrics(forTextStyle: .title1).scaledFont(
            for: .monospacedDigitSystemFont(ofSize: ChapterNoteMark.countBaseSize, weight: .semibold))
        countLabel.adjustsFontForContentSizeCategory = true
        countLabel.adjustsFontSizeToFitWidth = true
        countLabel.minimumScaleFactor = 0.5
        countLabel.textAlignment = .center
        countLabel.textColor = Palette.accent.platformColor
        countLabel.isUserInteractionEnabled = false
        countLabel.isAccessibilityElement = false
        addSubview(countLabel)
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func update(count: Int, chapterName: String) {
        guard count != self.count || chapterName != self.chapterName else { return }
        self.count = count
        self.chapterName = chapterName
        countLabel.text = ChapterNoteMark.countText(count)
        accessibilityLabel = ChapterNoteMark.label(count, chapter: chapterName)
    }

    /// The paper's own size at the current text size.
    var naturalSize: CGSize { Self.paperSize(for: traitCollection) }

    /// The paper's size at `traits`' text size: `doc` at `.title1`, grown with Dynamic Type.
    static func paperSize(for traits: UITraitCollection) -> CGSize {
        let configuration = UIImage.SymbolConfiguration(textStyle: .title1, scale: .medium)
        guard let image = UIImage(systemName: "doc", compatibleWith: traits)?.applyingSymbolConfiguration(configuration) else { return .zero }
        return CGSize(width: ceil(image.size.width), height: ceil(image.size.height))
    }

    override var isHighlighted: Bool {
        didSet { paper.alpha = isHighlighted ? 0.4 : 1; countLabel.alpha = paper.alpha }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        paper.frame = bounds
        // The page as drawn (aspect fit), and the count in its lower part, clear of the corner.
        let natural = naturalSize
        guard natural.width > 0, natural.height > 0 else { return }
        let scale = min(bounds.width / natural.width, bounds.height / natural.height)
        let drawn = CGRect(x: bounds.midX - natural.width * scale / 2, y: bounds.midY - natural.height * scale / 2,
                           width: natural.width * scale, height: natural.height * scale)
        let inset = AppSpacing.xxs * scale
        let height = min(drawn.height / 2, countLabel.font.lineHeight)
        countLabel.frame = CGRect(x: drawn.minX + inset, y: drawn.maxY - inset - height,
                                  width: max(0, drawn.width - 2 * inset), height: height)
    }
}
#endif
