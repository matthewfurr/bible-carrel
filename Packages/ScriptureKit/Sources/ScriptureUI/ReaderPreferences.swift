import Foundation

/// Everything Settings → Reading chooses, read from `UserDefaults` with fallbacks.
public struct ReaderPreferences: Equatable, Sendable {
    public var style: PageStyle
    /// Nil is the style's own face.
    public var face: PageFace?
    public var fontSize: Double
    public var lineSpacing: LineSpacingChoice
    public var columnWidth: ColumnWidthChoice
    public var layout: VerseLayoutChoice
    public var showsVerseNumbers: Bool
    public var showsSectionHeadings: Bool
    public var justified: Bool

    public init(
        style: PageStyle = .printed, face: PageFace? = nil, fontSize: Double = ReaderSettings.defaultFontSize,
        lineSpacing: LineSpacingChoice = .normal, columnWidth: ColumnWidthChoice = .normal,
        layout: VerseLayoutChoice = .paragraphs, showsVerseNumbers: Bool = true,
        showsSectionHeadings: Bool = true, justified: Bool = false
    ) {
        self.style = style
        self.face = face
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.columnWidth = columnWidth
        self.layout = layout
        self.showsVerseNumbers = showsVerseNumbers
        self.showsSectionHeadings = showsSectionHeadings
        self.justified = justified
    }

    public static let `default` = ReaderPreferences()

    /// The face the page is set in: the reader's choice, else the style's.
    public var resolvedFace: PageFace { face ?? style.defaultFace }

    /// The stored settings; a missing or unrecognised value falls back to `default`'s.
    public static func load(from defaults: UserDefaults) -> ReaderPreferences {
        let base = ReaderPreferences.default
        func choice<T: RawRepresentable>(_ key: String, _ fallback: T) -> T where T.RawValue == String {
            defaults.string(forKey: key).flatMap(T.init(rawValue:)) ?? fallback
        }
        func flag(_ key: String, _ fallback: Bool) -> Bool {
            defaults.object(forKey: key) as? Bool ?? fallback
        }
        return ReaderPreferences(
            style: choice(ReaderSettings.pageStyleKey, base.style),
            face: defaults.string(forKey: ReaderSettings.pageFaceKey).flatMap(PageFace.init(rawValue:)),
            fontSize: defaults.object(forKey: ReaderSettings.fontSizeKey) as? Double ?? base.fontSize,
            lineSpacing: choice(ReaderSettings.lineSpacingKey, base.lineSpacing),
            columnWidth: choice(ReaderSettings.columnWidthKey, base.columnWidth),
            layout: choice(ReaderSettings.verseLayoutKey, base.layout),
            showsVerseNumbers: flag(ReaderSettings.showsVerseNumbersKey, base.showsVerseNumbers),
            showsSectionHeadings: flag(ReaderSettings.showsSectionHeadingsKey, base.showsSectionHeadings),
            justified: flag(ReaderSettings.justifiedKey, base.justified))
    }
}
