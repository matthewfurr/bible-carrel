import Foundation
import Testing
@testable import ScriptureUI

/// The Plan tab's `ellipsis` menu: what it offers for what the tab holds.
@Suite struct PhonePlanMenuTests {
    @Test func theMenuOffersWhatCanBeDoneNow() {
        #expect(PhonePlanMenu.items(planCount: 0, followedIsReadable: false, hasThisWeek: false) == [.importFile, .newPlan])
        #expect(PhonePlanMenu.items(planCount: 2, followedIsReadable: true, hasThisWeek: true) == [.plans, .importFile, .newPlan, .editPlan, .changeMeetingDate, .deletePlan])
        #expect(PhonePlanMenu.items(planCount: 1, followedIsReadable: true, hasThisWeek: false) == [.plans, .importFile, .newPlan, .editPlan, .deletePlan])   // no dates yet, or finished
        #expect(PhonePlanMenu.items(planCount: 1, followedIsReadable: false, hasThisWeek: false) == [.plans, .importFile, .newPlan, .deletePlan])
        #expect(PhonePlanMenu.title(.importFile) == "Import…" && PhonePlanMenu.title(.changeMeetingDate) == "Change Meeting Date…" && PhonePlanMenu.title(.deletePlan) == "Delete Plan…")
        #expect(PhonePlanMenu.title(.newPlan) == "New Plan" && PhonePlanMenu.title(.editPlan) == "Edit Plan…")
    }
}
