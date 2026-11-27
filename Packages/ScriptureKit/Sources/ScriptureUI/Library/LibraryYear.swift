/// A year as the Library writes it. The data counts years with a year zero, so its -1995 is 1996 BC.
public enum LibraryYear {
    /// "AD 30", "1996 BC": the year without "about".
    public static func bare(_ year: Int) -> String {
        year > 0 ? "AD \(year)" : "\(1 - year) BC"
    }

    /// "about AD 30", "about 1996 BC".
    public static func text(_ year: Int) -> String { "about " + bare(year) }

    /// A run of years as the Spans fact writes it: "about 4004 to 1635 BC", "about AD 30 to 57",
    /// "about 1921 BC to AD 49"; one year is "about 1055 BC".
    public static func spans(_ years: ClosedRange<Int>) -> String {
        let (low, high) = (years.lowerBound, years.upperBound)
        if low == high { return text(low) }
        if high <= 0 { return "about \(1 - low) to \(1 - high) BC" }
        if low > 0 { return "about AD \(low) to \(high)" }
        return "about \(bare(low)) to \(bare(high))"
    }

    /// "A to B", "born A", "died B"; nil with neither.
    public static func life(birth: Int?, death: Int?) -> String? {
        switch (birth, death) {
        case let (birth?, death?): "\(text(birth)) to \(text(death))"
        case let (birth?, nil): "born \(text(birth))"
        case let (nil, death?): "died \(text(death))"
        case (nil, nil): nil
        }
    }

    /// A person's years as the Lived fact writes them (Departure 20): "about 1085 to 1015 BC" for both a birth and a
    /// death, "born about 1755 BC" or "died about 1056 BC" for one; nil with neither.
    public static func lived(birth: Int?, death: Int?) -> String? {
        if let birth, let death { return spans(min(birth, death)...max(birth, death)) }
        return life(birth: birth, death: death)
    }

    /// The least year to the greatest; one year is its text; nil for none.
    public static func span(_ years: [Int]) -> String? {
        guard let first = years.min(), let last = years.max() else { return nil }
        return first == last ? text(first) : "\(text(first)) to \(text(last))"
    }
}
