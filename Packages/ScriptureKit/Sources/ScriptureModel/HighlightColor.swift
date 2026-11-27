import Foundation
import SwiftData

/// A named highlight color with light and dark variants, ordered by the user in Settings.
@Model
public final class HighlightColor {
    public var uuid: UUID = UUID()
    public var name: String = ""
    public var lightHex: String = "#FFE86B"
    public var darkHex: String = "#6B5B00"
    public var sortOrder: Int = 0
    public var isDefault: Bool = false
    /// A default color's stable identity across devices ("yellow" ... "orange", parallel to
    /// `MarkupContainer.defaultColorKeys`), so `SeedMerge` can find two devices' seeds of one
    /// default. Nil for the reader's own colors; optional so an older store opens as it is.
    public var builtInKey: String?

    public init(name: String, lightHex: String, darkHex: String, sortOrder: Int, isDefault: Bool) {
        self.name = name
        self.lightHex = lightHex
        self.darkHex = darkHex
        self.sortOrder = sortOrder
        self.isDefault = isDefault
    }
}
