import CloudKit
import CoreData
import Foundation
import Testing
@testable import ScriptureModel

@Suite struct SyncMonitorTests {
    @Test func cloudKitErrorsMapToWhatTheReaderCanActOn() {
        #expect(SyncMonitor.failure(from: nil) == nil)
        #expect(SyncMonitor.failure(from: CKError(.quotaExceeded)) == .quotaExceeded)
        #expect(SyncMonitor.failure(from: CKError(.notAuthenticated)) == .noAccount)
        #expect(SyncMonitor.failure(from: CKError(.networkUnavailable)) == .network)
        #expect(SyncMonitor.failure(from: CKError(.networkFailure)) == .network)
    }

    @Test func aPartialFailureReportsItsWorstPart() {
        let partial = NSError(domain: CKErrorDomain, code: CKError.partialFailure.rawValue,
            userInfo: [CKPartialErrorsByItemIDKey: [CKRecord.ID(recordName: "a"): CKError(.quotaExceeded)]])
        #expect(SyncMonitor.failure(from: partial) == .quotaExceeded)
    }

    /// The observer runs on the posting thread, so a post from a background queue must neither
    /// trap (no main-actor assumption) nor reach `onEvent` when it carries no event.
    @MainActor @Test func aPostWithoutAnEventFromABackgroundQueueIsIgnored() async throws {
        let center = NotificationCenter()
        let monitor = SyncMonitor(center: center)
        var received = 0
        monitor.onEvent = { _ in received += 1 }
        monitor.start()
        await Task.detached {
            center.post(name: NSPersistentCloudKitContainer.eventChangedNotification, object: nil)
            center.post(name: NSPersistentCloudKitContainer.eventChangedNotification, object: NSObject(),
                        userInfo: ["unrelated": 1])
        }.value
        try await Task.sleep(for: .milliseconds(100))
        #expect(received == 0)
    }

    @Test func anythingElseKeepsItsDescription() {
        let error = NSError(domain: "x", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"])
        #expect(SyncMonitor.failure(from: error) == .other("boom"))
    }
}
