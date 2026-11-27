import Foundation
import Observation
import ScriptureData

/// The review of an imported plan, New Plan and Edit Plan…: one draft at a time, nothing stored
/// until Save (spec 6.1 to 6.3). The editor is shown while `isEditing`.
///
/// The editor's fields write through the mutators below, by id: each does nothing once the draft
/// is gone, so a field that commits as its sheet closes cannot reach a draft that is not there.
@MainActor @Observable public final class PlanEditorSession {
    public enum Phase: Equatable, Sendable { case idle, reading(fileName: String), editing, failed(message: String, offersNewPlan: Bool) }
    public typealias Reader = @Sendable (URL, PlanDay) -> Result<PlanDraft, PlanFileImport.Failure>

    static let reviewHeading = "Check the Plan"
    static let newHeading = "New Plan"
    static let editHeading = "Edit Plan"
    static let removeWeekAction = "Remove Week"
    static let removeReadingAction = "Remove Reading"
    static let moveReadingAction = "Move Reading"

    public private(set) var phase: Phase = .idle
    /// Every change works the flags out again, once, reading only the lines whose text is new.
    public var draft: PlanDraft? {
        didSet { draftChanged(wasOpen: oldValue != nil) }
    }
    /// Set as the editor opens and closes, and only then: the window behind the sheet reads this,
    /// not the draft, so a key typed in the editor does not redraw it.
    public private(set) var isEditing = false
    public private(set) var heading: String = ""
    /// In week order, a week's own before its lines'.
    public private(set) var flags: [PlanFlag] = []
    public private(set) var canSave = false
    /// Pasted text is offered to a new plan only.
    public private(set) var offersPaste = false
    /// Save could not store the plan: the editor stays open on its draft and says so.
    public private(set) var saveFailure: String?

    @ObservationIgnored let model: ReadingPlanModel
    @ObservationIgnored private let read: Reader
    @ObservationIgnored private var flagsByReading: [UUID: [PlanFlag]] = [:]
    /// Each line's reading by its text, for as long as the editor is open.
    @ObservationIgnored private var parses: [String: Result<PlanReadingText.Parsed, PlanReadingText.Failure>] = [:]
    /// The translation being read's chapter counts, read once as the editor opens.
    @ObservationIgnored private var chapterCounts: [String: Int] = [:]
    /// In place of the model's counts (a benchmark's real Bible).
    @ObservationIgnored var chapterCountsOverride: [String: Int]?
    /// A week number field's text while it is not a number (emptied to type another).
    @ObservationIgnored private var numberTexts: [UUID: String] = [:]
    /// The sheet's own: removes and moves in the draft are undone here, and the session's actions
    /// in it go as the editor closes. Nothing in the editor registers through the plan model.
    @ObservationIgnored public weak var undoManager: UndoManager?

    public init(model: ReadingPlanModel, read: @escaping Reader = PlanFileImport.draft(fromFileAt:today:)) {
        self.model = model
        self.read = read
    }

    // MARK: - Opening

    /// Week 1, no date, one empty line.
    public func newPlan() {
        open(PlanDraft(title: ""), heading: Self.newHeading, offersPaste: true)
    }

    /// The followed plan, every reading keeping its id (and so its tick). Nothing for an unreadable plan.
    public func editFollowedPlan() {
        guard let plan = model.followed, plan.isReadable else { return }
        open(PlanDraft(plan: plan), heading: Self.editHeading, offersPaste: false)
    }

    /// The file is read off the main actor; the window shows its progress meanwhile.
    public func importFile(at url: URL) async {
        let fileName = url.lastPathComponent
        draft = nil
        phase = .reading(fileName: fileName)
        let read = read, today = model.today
        let result = await Task.detached(priority: .userInitiated) { read(url, today) }.value
        // Another file, New Plan or a dismissal meanwhile wins.
        guard phase == .reading(fileName: fileName) else { return }
        switch result {
        case let .success(read):
            open(read, heading: Self.reviewHeading, offersPaste: false)
        case .failure(.notAPlan):
            phase = .failed(message: PlanFileImport.notAPlanMessage, offersNewPlan: true)
        case .failure(.unreadableFile):
            phase = .failed(message: PlanFileImport.unreadableMessage, offersNewPlan: false)
        }
    }

    /// The file panel could not hand over the file chosen.
    public func importFailed() {
        guard draft == nil else { return }
        phase = .failed(message: PlanFileImport.unreadableMessage, offersNewPlan: false)
    }

    private func open(_ draft: PlanDraft, heading: String, offersPaste: Bool) {
        self.heading = heading
        self.offersPaste = offersPaste
        saveFailure = nil
        phase = .editing
        self.draft = draft
    }

    // MARK: - The fields, by id

    public func setTitle(_ title: String) {
        guard draft != nil, draft?.title != title else { return }
        draft?.title = title
    }

    /// The week number field's text: the number, or what the field holds while it is not one.
    public func numberText(ofWeek id: UUID) -> String {
        guard let week = draft?.weeks.first(where: { $0.id == id }) else { return "" }
        return numberText(of: week)
    }

    /// The same, for a week the caller already holds: it reads nothing observed.
    func numberText(of week: PlanDraft.Week) -> String {
        numberTexts[week.id] ?? String(week.number)
    }

    /// Written as typed, digits only, so a number typed and then Save is in the saved plan. While
    /// the field is empty the week keeps its number.
    public func setNumberText(_ text: String, ofWeek id: UUID) {
        guard let index = draft?.weeks.firstIndex(where: { $0.id == id }) else { return }
        let digits = String(text.filter { $0.isASCII && $0.isNumber }.prefix(4))
        if let number = Int(digits), String(number) == digits {
            numberTexts[id] = nil
            if draft?.weeks[index].number != number { draft?.weeks[index].number = number }
        } else {
            numberTexts[id] = digits
        }
    }

    public func setLabel(_ label: String, ofWeek id: UUID) {
        guard let index = draft?.weeks.firstIndex(where: { $0.id == id }), draft?.weeks[index].label != label else { return }
        draft?.weeks[index].label = label
    }

    public func setText(_ text: String, ofReading id: UUID) {
        guard let weeks = draft?.weeks, let week = weeks.firstIndex(where: { $0.readings.contains { $0.id == id } }),
              let row = weeks[week].readings.firstIndex(where: { $0.id == id }),
              weeks[week].readings[row].text != text else { return }
        draft?.weeks[week].readings[row].text = text
    }

    public func setDay(_ day: PlanDay?, ofWeek id: UUID) {
        guard draft != nil else { return }
        draft?.setDay(day, ofWeek: id)
    }

    /// Set Date: seven days a week from the nearest dated week before it, else after it, else today.
    public func setSuggestedDay(ofWeek id: UUID) {
        guard let weeks = draft?.weeks, let index = weeks.firstIndex(where: { $0.id == id }) else { return }
        let day: PlanDay
        if let before = weeks[..<index].lastIndex(where: { $0.day != nil }), let dated = weeks[before].day {
            day = dated.adding(days: 7 * (index - before))
        } else if let after = weeks[(index + 1)...].firstIndex(where: { $0.day != nil }), let dated = weeks[after].day {
            day = dated.adding(days: -7 * (after - index))
        } else {
            day = model.today
        }
        draft?.setDay(day, ofWeek: id)
    }

    public func setFirstYear(_ year: Int) {
        guard draft != nil else { return }
        draft?.setFirstYear(year)
    }

    public func addWeek() {
        guard draft != nil else { return }
        draft?.addWeek()
    }

    public func addReading(toWeek id: UUID) {
        guard draft != nil else { return }
        draft?.addReading(toWeek: id)
    }

    // MARK: - Removes and moves, undone in the sheet's manager

    public func removeWeek(_ id: UUID) {
        guard let index = draft?.weeks.firstIndex(where: { $0.id == id }), let week = draft?.weeks[index] else { return }
        draft?.removeWeek(id)
        numberTexts[id] = nil
        register(Self.removeWeekAction) { session in session.insert(week, at: index) }
    }

    public func removeReading(_ id: UUID) {
        guard let weeks = draft?.weeks, let week = weeks.firstIndex(where: { $0.readings.contains { $0.id == id } }),
              let row = weeks[week].readings.firstIndex(where: { $0.id == id }) else { return }
        let reading = weeks[week].readings[row], weekID = weeks[week].id
        draft?.removeReading(id)
        register(Self.removeReadingAction) { session in session.insert(reading, at: row, inWeek: weekID) }
    }

    /// The same move SwiftUI's `onMove` asks for.
    public func moveReadings(inWeek id: UUID, fromOffsets: IndexSet, toOffset: Int) {
        guard let before = draft?.weeks.first(where: { $0.id == id })?.readings.map(\.id) else { return }
        draft?.moveReadings(inWeek: id, fromOffsets: fromOffsets, toOffset: toOffset)
        guard let after = draft?.weeks.first(where: { $0.id == id })?.readings.map(\.id), after != before else { return }
        registerOrder(before, redo: after, inWeek: id)
    }

    /// An undo puts back the one thing removed, so what was typed since in other lines stays.
    private func insert(_ week: PlanDraft.Week, at index: Int) {
        guard let count = draft?.weeks.count, draft?.weeks.contains(where: { $0.id == week.id }) == false else { return }
        draft?.weeks.insert(week, at: min(index, count))
        register(Self.removeWeekAction) { session in session.removeWeek(week.id) }
    }

    private func insert(_ reading: PlanDraft.Reading, at row: Int, inWeek weekID: UUID) {
        guard let week = draft?.weeks.firstIndex(where: { $0.id == weekID }), let count = draft?.weeks[week].readings.count,
              draft?.weeks.contains(where: { $0.readings.contains { $0.id == reading.id } }) == false else { return }
        draft?.weeks[week].readings.insert(reading, at: min(row, count))
        register(Self.removeReadingAction) { session in session.removeReading(reading.id) }
    }

    /// Undoing a move puts the week's lines back in `order`, each keeping its text; a line `order`
    /// does not name stays after them.
    private func registerOrder(_ order: [UUID], redo: [UUID], inWeek id: UUID) {
        register(Self.moveReadingAction) { session in
            guard let week = session.draft?.weeks.firstIndex(where: { $0.id == id }),
                  let readings = session.draft?.weeks[week].readings else { return }
            let placed = order.compactMap { id in readings.first { $0.id == id } }
            session.draft?.weeks[week].readings = placed + readings.filter { !order.contains($0.id) }
            session.registerOrder(redo, redo: order, inWeek: id)
        }
    }

    /// Nothing is registered with no draft, and an action that runs after the editor closed does nothing.
    private func register(_ name: String, _ action: @escaping (PlanEditorSession) -> Void) {
        guard let undoManager, draft != nil else { return }
        undoManager.registerUndo(withTarget: self) { session in
            guard session.draft != nil else { return }
            action(session)
        }
        undoManager.setActionName(name)
    }

    // MARK: - The review

    /// The line's first flag.
    public func flag(forReading id: UUID) -> PlanFlag? {
        flagsByReading[id]?.first
    }

    /// Every flag the line has (a line can name two chapters a book lacks).
    func flags(forReading id: UUID) -> [PlanFlag] {
        flagsByReading[id] ?? []
    }

    private func draftChanged(wasOpen: Bool) {
        guard let draft else {
            flags = []
            flagsByReading = [:]
            parses = [:]
            numberTexts = [:]
            if canSave { canSave = false }
            if isEditing { isEditing = false }
            if phase == .editing { phase = .idle }
            return
        }
        if !wasOpen {
            chapterCounts = chapterCountsOverride ?? model.chapterCounts
            parses = [:]
        }
        let worked = PlanReview.flags(draft, chapterCounts: chapterCounts, parse: parse)
        if worked != flags { flags = worked }
        var byReading: [UUID: [PlanFlag]] = [:]
        for flag in worked {
            if let reading = flag.readingID { byReading[reading, default: []].append(flag) }
        }
        flagsByReading = byReading
        // What blocks Save: no title, no week, a line that cannot be read or a book the app does not know.
        let saving = !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !draft.weeks.isEmpty
            && !worked.contains { $0.kind == .unreadable || $0.kind == .unknownBook }
        if saving != canSave { canSave = saving }
        if !isEditing { isEditing = true }
    }

    private func parse(_ text: String) -> Result<PlanReadingText.Parsed, PlanReadingText.Failure> {
        if let known = parses[text] { return known }
        let parsed = PlanReadingText.parse(text)
        parses[text] = parsed
        return parsed
    }

    // MARK: - Closing

    /// Stores the plan (a new one is followed) and closes the editor; nothing unless `canSave`. A
    /// save the store refuses keeps the editor open on its draft, and says so there.
    public func save() {
        guard canSave, let plan = draft?.plan(now: model.currentDate) else { return }
        guard model.save(plan) else {
            // Said in the sheet, and not a second time by the window under it.
            model.clearError()
            saveFailure = ReadingPlanModel.saveFailure
            return
        }
        close()
    }

    /// Closes the editor; nothing is stored.
    public func cancel() {
        close()
    }

    private func close() {
        undoManager?.removeAllActions(withTarget: self)
        saveFailure = nil
        draft = nil
        phase = .idle
    }

    public func clearSaveFailure() {
        saveFailure = nil
    }

    /// Text from the system's Paste button: its weeks come after the last.
    public func paste(_ text: String) {
        draft?.append(text: text, today: model.today)
    }

    public func dismissFailure() {
        if case .failed = phase { phase = .idle }
    }
}
