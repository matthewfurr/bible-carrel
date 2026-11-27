import Foundation
import Testing
@testable import ScriptureUI

@Suite struct LibraryDatesTests {
    private let defaults: UserDefaults

    init() {
        let name = "LibraryDatesTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
    }

    @Test func datesAreOnUntilTurnedOffAndTheNoticeShowsOnce() {
        #expect(LibraryDates.shows(defaults) && LibraryDates.showsNotice(defaults, viewHasDate: true) && !LibraryDates.showsNotice(defaults, viewHasDate: false))
        LibraryDates.answer(defaults)
        #expect(LibraryDates.shows(defaults) && !LibraryDates.showsNotice(defaults, viewHasDate: true) && defaults.bool(forKey: "datesNoticeAnswered"))
    }

    @Test func turningDatesOffAnswersTheNoticeAndTurningThemOnDoesNotAskAgain() {
        LibraryDates.setShows(false, in: defaults)
        #expect(!LibraryDates.shows(defaults) && defaults.bool(forKey: "datesNoticeAnswered") && !LibraryDates.showsNotice(defaults, viewHasDate: true))
        LibraryDates.setShows(true, in: defaults)
        #expect(LibraryDates.shows(defaults) && !LibraryDates.showsNotice(defaults, viewHasDate: true))
        #expect(LibraryDates.notice.hasSuffix("You can turn dates off in Settings.") && LibraryDates.footnote == "Dates follow a traditional chronology.")
    }
}
