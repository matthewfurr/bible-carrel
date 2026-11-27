import Foundation
import ScriptureData
import ScriptureModel
import SwiftData
import Testing
@testable import ScriptureUI

/// The review, New Plan and Edit Plan… (spec 6.1 to 6.3), on both apps.
@MainActor @Suite final class PlanEditorSessionTests {
    private let small = PlanModelFixture.small
    /// Kept alive as long as the test uses its model.
    private var fixture: PlanModelFixture?

    /// A model on today 16 November 2026, and its store.
    private func make() throws -> (ReadingPlanModel, PlanStore) {
        let made = try PlanModelFixture(today: PlanModelFixture.day(2026, 11, 16))
        fixture = made
        return (made.model, made.store)
    }

    private func reader(_ result: Result<PlanDraft, PlanFileImport.Failure>) -> PlanEditorSession.Reader {
        { _, _ in result }
    }

    @Test func anImportOpensTheReviewAndNothingIsSavedUntilAccepted() async throws {
        let (model, store) = try make()
        let draft = PlanText.draft(from: "Week 1\nPsalms 2; Matthew 5-6\nWeek 2\nMatthew 1", title: "Drawn Plan", today: model.today)
        let session = PlanEditorSession(model: model, read: reader(.success(draft)))
        await session.importFile(at: URL(fileURLWithPath: "/tmp/Drawn Plan.pdf"))
        #expect(session.phase == .editing && session.heading == "Check the Plan" && session.draft == draft && session.canSave && session.flags.isEmpty)
        #expect(try store.plans().isEmpty)
        session.save()
        #expect(try store.plans().count == 1 && model.followed?.title == "Drawn Plan" && session.draft == nil && session.phase == .idle)
    }

    /// Review Focus 2.
    @Test func aFileThatIsNotAPlanSaysSoAndOffersNewPlan() async throws {
        let (model, store) = try make()
        let refused = PlanEditorSession(model: model, read: reader(.failure(.notAPlan)))
        await refused.importFile(at: URL(fileURLWithPath: "/tmp/book.pdf"))
        #expect(refused.phase == .failed(message: "This PDF isn't laid out like a plan Bible Carrel can read. You can type the plan in instead.", offersNewPlan: true))
        #expect(refused.draft == nil)
        refused.dismissFailure()
        refused.newPlan()
        #expect(refused.phase == .editing && refused.heading == "New Plan" && refused.draft?.weeks.count == 1 && !refused.canSave)   // no title yet
        let unreadable = PlanEditorSession(model: model, read: reader(.failure(.unreadableFile)))
        await unreadable.importFile(at: URL(fileURLWithPath: "/tmp/x.txt"))
        #expect(unreadable.phase == .failed(message: "That file could not be read.", offersNewPlan: false))
        #expect(try store.plans().isEmpty)
    }

    @Test func saveIsOffWhileALineCannotBeReadAndCancelSavesNothing() throws {
        let (model, store) = try make()
        let session = PlanEditorSession(model: model, read: reader(.failure(.notAPlan)))
        session.newPlan()
        session.draft?.title = "Mine"
        session.draft?.weeks[0].readings[0].text = "Hezekiah 3"
        let line = try #require(session.draft?.weeks[0].readings[0].id)
        #expect(!session.canSave && session.flag(forReading: line)?.kind == .unknownBook && session.flags.count == 1)
        session.save()
        #expect(try store.plans().isEmpty && session.draft != nil)
        session.draft?.weeks[0].readings[0].text = "Matthew 5-6"
        #expect(session.canSave && session.flag(forReading: line) == nil)
        session.cancel()
        #expect(try store.plans().isEmpty && session.draft == nil && session.phase == .idle)
    }

    /// Spec 6.2: a tick stays with its reading through reordering, renumbering and changes to its passages, and goes only with its reading.
    @Test func editingAPlanInUseKeepsItsTicks() throws {
        let (model, _) = try make()
        model.save(small)                                                // three weeks of two readings, as in ReadingPlanModelTests
        let first = small.weeks[0].readings[0], second = small.weeks[0].readings[1]
        model.toggle(first)
        model.toggle(second)
        let session = PlanEditorSession(model: model, read: reader(.failure(.notAPlan)))
        session.editFollowedPlan()
        #expect(session.heading == "Edit Plan" && session.draft?.planID == small.id)
        let week = try #require(session.draft?.weeks[0].id)
        session.draft?.moveReadings(inWeek: week, fromOffsets: IndexSet(integer: 0), toOffset: 2)
        session.draft?.weeks[0].readings[1].text = "Matthew 1"           // the first reading, now second, with other passages
        session.draft?.weeks[0].number = 7
        session.draft?.removeReading(second.id)
        session.save()
        #expect(model.plans.count == 1 && model.followed?.weeks[0].number == 7 && model.followed?.weeks[0].readings.map(\.id) == [first.id])
        #expect(model.ticked == [first.id])
    }

    @Test func pastedTextAddsItsWeeks() throws {
        let (model, _) = try make()
        let session = PlanEditorSession(model: model, read: reader(.failure(.notAPlan)))
        session.newPlan()
        session.paste("Week 5\nPsalms 2\nWeek 6\nMatthew 1")
        #expect(session.draft?.weeks.map(\.number) == [5, 6])
    }

    /// C1: the fields write by id; once Save or Cancel has closed the editor, a field that commits
    /// late reaches nothing; a week number typed and then Save is in the saved plan.
    @Test func theFieldsWriteByIdAndNothingOnceTheEditorCloses() throws {
        let (model, store) = try make()
        let session = PlanEditorSession(model: model, read: reader(.failure(.notAPlan)))
        session.newPlan()
        let week = try #require(session.draft?.weeks[0].id), line = try #require(session.draft?.weeks[0].readings[0].id)
        session.setTitle("Mine")
        session.setText("Psalms 1", ofReading: line)
        session.setLabel("OFF", ofWeek: week)
        session.setNumberText("", ofWeek: week)                                            // emptied to type another
        #expect(session.numberText(ofWeek: week) == "" && session.draft?.weeks[0].number == 1)
        session.setNumberText("7x", ofWeek: week)                                          // digits only, as typed
        #expect(session.numberText(ofWeek: week) == "7" && session.canSave)
        session.save()                                                                     // no Return first
        #expect(try store.plans().first?.weeks.map(\.number) == [7] && store.plans().first?.weeks[0].label == "OFF")
        #expect(session.draft == nil && !session.isEditing)
        func closedFieldsWriteNothing() {
            session.setTitle("Late")
            session.setNumberText("9", ofWeek: week)
            session.setLabel("Late", ofWeek: week)
            session.setText("Psalms 2", ofReading: line)
            session.setDay(PlanModelFixture.day(2026, 11, 17), ofWeek: week)
            session.setSuggestedDay(ofWeek: week)
            session.setFirstYear(2027)
            session.addWeek()
            session.addReading(toWeek: week)
            session.removeReading(line)
            session.removeWeek(week)
            session.moveReadings(inWeek: week, fromOffsets: IndexSet(integer: 0), toOffset: 1)
            #expect(session.draft == nil && !session.isEditing && session.numberText(ofWeek: week) == "")
        }
        closedFieldsWriteNothing()
        session.newPlan()
        session.cancel()
        closedFieldsWriteNothing()
        #expect(try store.plans().count == 1)
    }

    /// Set Date: seven days a week from the nearest dated week before, else after, else today.
    @Test func setDateSuggestsSevenDaysAWeekFromItsNeighbor() throws {
        let (model, _) = try make()
        let session = PlanEditorSession(model: model, read: reader(.failure(.notAPlan)))
        session.newPlan()
        session.addWeek()
        session.addWeek()
        let ids = try #require(session.draft?.weeks.map(\.id))
        session.setSuggestedDay(ofWeek: ids[1])
        #expect(session.draft?.weeks.map(\.day) == [nil, model.today, nil])
        session.setSuggestedDay(ofWeek: ids[0])
        session.setSuggestedDay(ofWeek: ids[2])
        #expect(session.draft?.weeks.map(\.day) == [model.today.adding(days: -7), model.today, model.today.adding(days: 7)])
    }

    /// I1: a save the store refuses keeps the editor open on its draft and says so in the editor.
    @Test func aSaveTheStoreRefusesKeepsTheDraftAndSaysSo() throws {
        let (model, store) = try make()
        model.save(small)
        let session = PlanEditorSession(model: model, read: reader(.failure(.notAPlan)))
        session.editFollowedPlan()
        let line = try #require(session.draft?.weeks[0].readings[0].id)
        session.setText("Matthew 1", ofReading: line)
        // A newer build's edit arrives while the editor is open: the stored record can no longer be read.
        let record = try #require(try store.container.mainContext.fetch(FetchDescriptor<PlanRecord>()).first)
        record.weeksData = Data(#"{"v":2,"weeks":[]}"#.utf8)
        try store.container.mainContext.save()
        let draft = session.draft
        session.save()
        #expect(session.draft == draft && session.isEditing && session.saveFailure == "That change could not be saved. Try it again.")
        #expect(model.lastError == nil)                                                    // not said again by the window under the sheet
        session.clearSaveFailure()
        session.cancel()
        #expect(session.saveFailure == nil && session.draft == nil)
    }

    /// M1: Remove Week, Remove Reading and a move are undone and redone in the sheet's own manager,
    /// each putting back only what it took; once the editor closes its actions are gone.
    @Test func removesAndMovesAreUndoneInTheSheetsManager() throws {
        let (model, _) = try make()
        model.save(small)
        let undo = UndoManager()
        let session = PlanEditorSession(model: model, read: reader(.failure(.notAPlan)))
        session.undoManager = undo
        session.editFollowedPlan()
        let original = try #require(session.draft)
        let second = original.weeks[1].id, line = original.weeks[0].readings[0].id
        session.removeWeek(second)
        #expect(session.draft?.weeks.count == 2 && undo.undoActionName == "Remove Week")
        session.setText("Psalms 9", ofReading: original.weeks[2].readings[0].id)          // typed after the remove: kept by its undo
        undo.undo()
        #expect(session.draft?.weeks.map(\.id) == original.weeks.map(\.id) && session.draft?.weeks[2].readings[0].text == "Psalms 9")
        undo.redo()
        #expect(session.draft?.weeks.count == 2)
        undo.undo()
        session.removeReading(line)
        #expect(session.draft?.weeks[0].readings.count == 1 && undo.undoActionName == "Remove Reading")
        undo.undo()
        #expect(session.draft?.weeks[0].readings.map(\.id) == original.weeks[0].readings.map(\.id))
        session.moveReadings(inWeek: original.weeks[0].id, fromOffsets: IndexSet(integer: 0), toOffset: 2)
        #expect(session.draft?.weeks[0].readings.first?.id != line && undo.undoActionName == "Move Reading")
        undo.undo()
        #expect(session.draft?.weeks[0].readings.map(\.id) == original.weeks[0].readings.map(\.id))
        undo.redo()
        #expect(session.draft?.weeks[0].readings.last?.id == line)
        session.cancel()
        #expect(!undo.canUndo && !undo.canRedo && session.draft == nil)
    }

    /// I3: the window behind the sheet reads `isEditing`, which a key does not change.
    @Test func aKeyInTheEditorLeavesIsEditingAlone() throws {
        let (model, _) = try make()
        let session = PlanEditorSession(model: model, read: reader(.failure(.notAPlan)))
        session.newPlan()
        let line = try #require(session.draft?.weeks[0].readings[0].id)
        let editing = ObservedChange.observing { _ = session.isEditing }
        session.setText("Psalms 1", ofReading: line)
        session.setTitle("Mine")
        #expect(!editing.fired && session.isEditing)
        session.cancel()
        #expect(editing.fired && !session.isEditing)
    }

    /// A file the panel could not hand over says so, as a file that cannot be read does.
    @Test func aFilePanelFailureSaysTheFileCouldNotBeRead() throws {
        let (model, _) = try make()
        let session = PlanEditorSession(model: model, read: reader(.failure(.notAPlan)))
        session.importFailed()
        #expect(session.phase == .failed(message: "That file could not be read.", offersNewPlan: false))
    }

    /// VoiceOver's week header, and the review's first date with its year.
    @Test func theEditorsDatesAreWrittenAsTheSystemWritesThem() {
        let (locale, calendar) = (PlanModelFixture.locale, PlanModelFixture.calendar)
        let day = PlanModelFixture.day(2026, 11, 17)
        #expect(PlanWeekText.spokenHeader(number: 63, day: day, locale: locale, calendar: calendar) == "Week 63, Tuesday, November 17")
        #expect(PlanWeekText.spokenHeader(number: 63, day: nil, locale: locale, calendar: calendar) == "Week 63")
        #expect(PlanWeekText.dateWithYear(day, locale: locale, calendar: calendar) == "Tuesday, November 17, 2026")
    }

    /// The saved plan's dates are the model's clock, not the real one.
    @Test func aSaveStampsThePlanWithTheModelsClock() throws {
        let (model, store) = try make()
        let session = PlanEditorSession(model: model, read: reader(.failure(.notAPlan)))
        session.newPlan()
        session.draft?.title = "Mine"
        session.draft?.weeks[0].readings[0].text = "Psalms 1"
        session.save()
        #expect(try store.plans().first?.modifiedAt == PlanModelFixture.day(2026, 11, 16).date(in: PlanModelFixture.calendar))
    }
}

