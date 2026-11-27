import CoreGraphics

/// The spacing scale (DESIGN.md › spacing), in points. Every padding and stack spacing is one of
/// these; one tied to text is a `@ScaledMetric` seeded from one of these.
public enum AppSpacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
    public static let xxxl: CGFloat = 64
}

/// The corner radius scale (DESIGN.md › rounded), in points; always `style: .continuous`.
public enum AppRadius {
    /// Highlight fills and small tags.
    public static let sm: CGFloat = 4
    /// Selection washes, the note editor, palette rows.
    public static let md: CGFloat = 6
    /// Chapter cells.
    public static let lg: CGFloat = 10
    /// The ⌘K panel.
    public static let xl: CGFloat = 12
    /// The Library's reference icons (36 pt squares): rounder than a chapter cell (Matt, 2026-11-16).
    /// Scaled with the icon's side.
    public static let xxl: CGFloat = 14
}
