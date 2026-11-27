/// `#RRGGBB` strings, the storage form of highlight colors.
public enum ColorHex {
    /// Components in 0...1 for `#RRGGBB` or `RRGGBB` in any case; nil for anything else.
    public static func components(_ hex: String) -> (red: Double, green: Double, blue: Double)? {
        var digits = Substring(hex)
        if digits.hasPrefix("#") { digits = digits.dropFirst() }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        return (
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }

    /// Uppercase `#RRGGBB` from components in 0...1 (clamped).
    public static func string(red: Double, green: Double, blue: Double) -> String {
        func byte(_ value: Double) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }
}
