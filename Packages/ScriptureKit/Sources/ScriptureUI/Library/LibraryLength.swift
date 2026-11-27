import Foundation

/// A length of time in words (departure 4): "one day", "7 days", "3 months", "one year", "2.5 years".
public enum LibraryLength {
    private static let monthDays = 30.4375, yearDays = 365.25

    /// Under 1.5 days "one day"; a whole number of days under 365 "N days"; other lengths under a year in months
    /// rounded; from a year, years to one place without a trailing ".0", in the reader's number format.
    public static func text(days: Double) -> String {
        if days < 1.5 { return "one day" }
        if days < 365 {
            if (days - days.rounded()).magnitude < 1e-9 { return "\(Int(days.rounded())) days" }
            let months = Int((days / monthDays).rounded())
            if months < 1 { return "\(Int(days.rounded())) days" }
            if months < 12 { return months == 1 ? "one month" : "\(months) months" }
        }
        let years = (days / yearDays * 10).rounded() / 10
        if years == 1 { return "one year" }
        return "\(years.formatted(.number.precision(.fractionLength(0 ... 1)))) years"
    }
}
