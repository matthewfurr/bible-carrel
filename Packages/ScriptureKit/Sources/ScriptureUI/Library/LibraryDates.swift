import Foundation

/// The dates setting and the one-time notice about whose dating the Library follows (spec 6.5).
/// Both keys are synced preferences. A date is never shown without a line saying whose dating it
/// is: the notice the first time, the footnote after.
public enum LibraryDates {
    /// Absent means on.
    public static let showKey = "showDates"
    public static let noticeAnsweredKey = "datesNoticeAnswered"
    public static let notice = "Dates follow a traditional chronology (Ussher's, as worked out by Floyd Nolen Jones), which puts Creation at 4004 BC. You can turn dates off in Settings."
    public static let footnote = "Dates follow a traditional chronology."

    /// What an absent setting means.
    public static let defaultShows = true

    public static func shows(_ defaults: UserDefaults) -> Bool {
        defaults.object(forKey: showKey) as? Bool ?? defaultShows
    }

    /// On, unanswered, and the view has a date to show.
    public static func showsNotice(_ defaults: UserDefaults, viewHasDate: Bool) -> Bool {
        viewHasDate && shows(defaults) && !defaults.bool(forKey: noticeAnsweredKey)
    }

    public static func answer(_ defaults: UserDefaults) {
        defaults.set(true, forKey: noticeAnsweredKey)
    }

    /// Turning dates off answers the notice; turning them on again does not bring it back.
    public static func setShows(_ on: Bool, in defaults: UserDefaults) {
        defaults.set(on, forKey: showKey)
        if !on { answer(defaults) }
    }
}
