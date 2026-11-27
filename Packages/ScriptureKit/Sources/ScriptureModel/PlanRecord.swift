import Foundation
import SwiftData

/// A reading plan in the synced store: its weeks are one encoded value (`PlanCoding`), so an
/// edit is one write and a plan never arrives from another device in pieces.
@Model
public final class PlanRecord {
    public var uuid: UUID = UUID()
    public var title: String = ""
    public var createdAt: Date = Date()
    public var modifiedAt: Date = Date()
    /// `PlanCoding`.
    public var weeksData: Data = Data()

    public init() {}
}

/// One reading of a plan marked read. Points at its plan and reading by id, with no relationship,
/// so a tick that arrives before its plan, or outlives its reading, is kept and never counted.
@Model
public final class PlanTick {
    public var uuid: UUID = UUID()
    public var planID: UUID?
    public var readingID: UUID?
    public var tickedAt: Date = Date()

    public init(planID: UUID, readingID: UUID, tickedAt: Date = Date()) {
        self.planID = planID
        self.readingID = readingID
        self.tickedAt = tickedAt
    }
}
