import Foundation
import ScriptureModel
import Testing
@testable import ScriptureUI

@MainActor @Suite struct SyncStatusModelTests {
    struct FakeAccount: AccountStatusSource {
        let value: AccountStatus
        init(_ value: AccountStatus) { self.value = value }
        func status() async -> AccountStatus { value }
    }

    final class Clock: @unchecked Sendable {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let sync = SyncConfiguration(containerIdentifier: "iCloud.test", environment: .development)

    func freshDefaults() -> UserDefaults {
        let name = "SyncStatusModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func model(account: AccountStatus = .available, clock: Clock, defaults: UserDefaults? = nil) -> SyncStatusModel {
        let model = SyncStatusModel(sync: sync, account: FakeAccount(account), defaults: defaults ?? freshDefaults(), now: { clock.now })
        model.locale = Locale(identifier: "en_US")
        return model
    }

    func finished(_ kind: SyncEvent.Kind, at start: Date, seconds: TimeInterval = 2, failure: SyncFailure? = nil) -> SyncEvent {
        SyncEvent(kind: kind, started: start, ended: start.addingTimeInterval(seconds), failure: failure)
    }

    @Test(.enabled(if: TestPlatform.isMac, "The default device name is this Mac's; the phone's wording is tested on its own"))
    func anUnsignedBuildSaysSyncIsOff() {
        let clock = Clock(t0)
        let model = SyncStatusModel(sync: nil, account: FakeAccount(.available), defaults: freshDefaults(), now: { clock.now })
        #expect(model.state == .off)
        #expect(model.statusText == "Sync is off in this build. Your notes stay on this Mac.")
        #expect(model.symbolName == "icloud.slash")
        model.handle(finished(.exporting, at: t0))
        #expect(model.state == .off)
        model.handle(SyncEvent(kind: .importing, started: t0, ended: nil, failure: nil))
        #expect(model.state == .off)
    }

    @Test(.enabled(if: TestPlatform.isMac, "The default device name is this Mac's; the phone's wording is tested on its own"))
    func noAccountSaysWhereTheNotesAre() async {
        let model = model(account: .noAccount, clock: Clock(t0))
        await model.refreshAccount()
        #expect(model.state == .noAccount)
        #expect(model.statusText == "Not signed in to iCloud. Notes you make now stay on this Mac, and your synced notes return when you sign in.")
        #expect(model.symbolName == "icloud.slash")
        #expect(model.isAccountAvailable == false)
    }

    @Test func aFinishedExportReadsAsSynced() {
        let clock = Clock(t0)
        let model = model(clock: clock)
        model.handle(finished(.exporting, at: t0))
        #expect(model.state == .synced(t0.addingTimeInterval(2)))
        #expect(model.lastSynced == t0.addingTimeInterval(2))
        #expect(model.symbolName == "icloud")
        clock.now = t0.addingTimeInterval(12)
        #expect(model.statusText == "Synced just now")
        clock.now = t0.addingTimeInterval(122)
        #expect(model.statusText == "Synced 2 minutes ago")
    }

    @Test func anEventInFlightReadsAsSyncing() {
        let model = model(clock: Clock(t0))
        model.handle(SyncEvent(kind: .exporting, started: t0, ended: nil, failure: nil))
        #expect(model.state == .syncing)
        #expect(model.statusText == "Syncing…")
        #expect(model.symbolName == "icloud")
    }

    @Test(.enabled(if: TestPlatform.isMac, "The default device name is this Mac's; the phone's wording is tested on its own"))
    func aFullICloudSaysSo() {
        let model = model(clock: Clock(t0))
        model.handle(finished(.exporting, at: t0, failure: .quotaExceeded))
        #expect(model.state == .failing(.quotaExceeded, since: t0.addingTimeInterval(2)))
        #expect(model.statusText == "iCloud storage is full. Notes you make stay on this Mac until there is room.")
        #expect(model.symbolName == "exclamationmark.icloud")
    }

    /// The phone names itself where the Mac does; the rest of each sentence is the Mac's.
    @Test func thePhoneSaysTheNotesStayOnThisIPhone() async {
        let clock = Clock(t0)
        let off = SyncStatusModel(sync: nil, account: FakeAccount(.available), defaults: freshDefaults(), now: { clock.now })
        off.deviceName = "iPhone"
        #expect(off.statusText == "Sync is off in this build. Your notes stay on this iPhone.")

        let noAccount = model(account: .noAccount, clock: clock)
        noAccount.deviceName = "iPhone"
        await noAccount.refreshAccount()
        #expect(noAccount.statusText == "Not signed in to iCloud. Notes you make now stay on this iPhone, and your synced notes return when you sign in.")

        let unavailable = model(account: .temporarilyUnavailable, clock: clock)
        unavailable.deviceName = "iPhone"
        await unavailable.refreshAccount()
        #expect(unavailable.statusText == "iCloud is not available right now. Notes you make stay on this iPhone until it is.")

        let full = model(clock: clock)
        full.deviceName = "iPhone"
        full.handle(finished(.exporting, at: t0, failure: .quotaExceeded))
        #expect(full.statusText == "iCloud storage is full. Notes you make stay on this iPhone until there is room.")
    }

    @Test(.enabled(if: TestPlatform.isMac, "The default device name is this Mac's; the phone's wording is tested on its own"))
    func theBackupsFooterNamesTheDevice() {
        #expect(BackupsSettingsSection.footer(device: "Mac") == "A copy of your notes is kept on this Mac each day, for seven days. Restore brings back anything that is missing and changes nothing else.")
        #expect(BackupsSettingsSection.footer(device: "iPhone") == "A copy of your notes is kept on this iPhone each day, for seven days. Restore brings back anything that is missing and changes nothing else.")
        // The Mac's build of the package says Mac.
        #expect(BackupsSettingsSection.footer() == BackupsSettingsSection.footer(device: "Mac"))
    }

    @Test func offlineIsNotWorthANotice() {
        let clock = Clock(t0)
        let model = model(clock: clock)
        model.handle(finished(.exporting, at: t0, seconds: 0, failure: .network))
        clock.now = t0.addingTimeInterval(3 * 86_400)
        #expect(model.state == .failing(.network, since: t0))
        #expect(model.statusText == "No connection. Your notes sync when you are back online.")
        #expect(model.symbolName == "icloud")
        #expect(model.needsAttention == false)
    }

    /// With no sync ever recorded, the day counts from the first failure in this launch; the
    /// model's 15-minute timer is stood in for by `refreshAttention()`.
    @Test func aDayOfFailureAsksForAttention() {
        let clock = Clock(t0)
        let model = model(clock: clock)
        model.handle(finished(.exporting, at: t0, seconds: 0, failure: .other("boom")))
        #expect(model.statusText == "Could not sync. The app will try again.")
        #expect(model.symbolName == "exclamationmark.icloud")
        clock.now = t0.addingTimeInterval(23 * 3_600)
        model.refreshAttention()
        #expect(model.needsAttention == false)
        model.handle(finished(.importing, at: t0.addingTimeInterval(2 * 3_600), seconds: 0, failure: .other("again")))
        #expect(model.state == .failing(.other("again"), since: t0))
        #expect(model.needsAttention == false)
        clock.now = t0.addingTimeInterval(25 * 3_600)
        model.refreshAttention()
        #expect(model.needsAttention == true)
        let since = t0.formatted(Date.FormatStyle(locale: Locale(identifier: "en_US")).weekday(.wide).month().day())
        #expect(model.attentionHelp == "Your notes have not synced since \(since). Open Settings.")
        model.handle(finished(.exporting, at: t0.addingTimeInterval(25 * 3_600)))
        #expect(model.needsAttention == false)
        #expect(model.state == .synced(t0.addingTimeInterval(25 * 3_600 + 2)))
    }

    @Test func aDayWithoutASuccessfulSyncAsksForAttentionAcrossRelaunches() {
        let clock = Clock(t0)
        let defaults = freshDefaults()
        let lastWorked = t0.addingTimeInterval(-25 * 3_600)
        defaults.set(lastWorked, forKey: SyncStatusModel.lastSyncedKey)
        let model = model(clock: clock, defaults: defaults)
        #expect(model.needsAttention == false)
        model.handle(finished(.exporting, at: t0, seconds: 0, failure: .other("boom")))
        #expect(model.needsAttention == true)
        let day = lastWorked.formatted(Date.FormatStyle(locale: Locale(identifier: "en_US")).weekday(.wide).month().day())
        #expect(model.attentionHelp == "Your notes have not synced since \(day). Open Settings.")
    }

    @Test func aFailureWithARecentSyncDoesNot() {
        let clock = Clock(t0)
        let defaults = freshDefaults()
        defaults.set(t0.addingTimeInterval(-3_600), forKey: SyncStatusModel.lastSyncedKey)
        let model = model(clock: clock, defaults: defaults)
        model.handle(finished(.exporting, at: t0, seconds: 0, failure: .quotaExceeded))
        #expect(model.needsAttention == false)
        clock.now = t0.addingTimeInterval(22 * 3_600)
        model.refreshAttention()
        #expect(model.needsAttention == false)
        clock.now = t0.addingTimeInterval(23 * 3_600)
        model.refreshAttention()
        #expect(model.needsAttention == true)
    }

    @Test func restoreWaitsForTheFirstImport() async {
        let off = SyncStatusModel(sync: nil, account: FakeAccount(.available), defaults: freshDefaults())
        #expect(off.canRestore == true)

        let model = model(account: .available, clock: Clock(t0))
        await model.refreshAccount()
        #expect(model.isAccountAvailable == true)
        #expect(model.hasImportedThisLaunch == false)
        #expect(model.canRestore == false)
        model.handle(finished(.exporting, at: t0))
        #expect(model.canRestore == false)
        model.handle(finished(.importing, at: t0, failure: .other("boom")))
        #expect(model.canRestore == false)
        model.handle(finished(.importing, at: t0.addingTimeInterval(10)))
        #expect(model.hasImportedThisLaunch == true)
        #expect(model.canRestore == true)

        let signedOut = self.model(account: .noAccount, clock: Clock(t0))
        await signedOut.refreshAccount()
        #expect(signedOut.canRestore == false)
        signedOut.handle(finished(.importing, at: t0))
        signedOut.handle(finished(.setup, at: t0.addingTimeInterval(10), failure: .noAccount))
        #expect(signedOut.hasImportedThisLaunch == true)
        #expect(signedOut.canRestore == false)
    }

    @Test func aForcedNoticeReadsAsADayOfFailure() {
        let clock = Clock(t0)
        let model = model(clock: clock)
        model.handle(finished(.exporting, at: t0))
        #expect(model.needsAttention == false)
        #expect(model.attentionHelp == "")
        model.forcedAttention = true
        #expect(model.needsAttention == true)
        let since = t0.addingTimeInterval(-86_400).formatted(
            Date.FormatStyle(locale: Locale(identifier: "en_US")).weekday(.wide).month().day())
        #expect(model.attentionHelp == "Your notes have not synced since \(since). Open Settings.")
    }

    @Test func theFirstFinishedImportIsReportedOnce() {
        let model = model(clock: Clock(t0))
        var firstImports = 0
        var imports = 0
        var order: [String] = []
        model.onFirstImport = { firstImports += 1; order.append("first") }
        model.onImport = { imports += 1; order.append("import") }
        model.handle(finished(.importing, at: t0))
        model.handle(finished(.importing, at: t0.addingTimeInterval(10)))
        #expect(firstImports == 1)
        #expect(imports == 2)
        #expect(order == ["first", "import", "import"])
        model.handle(finished(.importing, at: t0.addingTimeInterval(20), failure: .network))
        #expect(firstImports == 1)
        #expect(imports == 2)

        let failedFirst = self.model(clock: Clock(t0))
        var failedFirstCalls = 0
        failedFirst.onFirstImport = { failedFirstCalls += 1 }
        failedFirst.onImport = { failedFirstCalls += 1 }
        failedFirst.handle(finished(.importing, at: t0, failure: .other("boom")))
        #expect(failedFirstCalls == 0)
    }

    @Test func aSetupThatFindsNoAccountBecomesNoAccount() {
        let model = model(clock: Clock(t0))
        model.handle(finished(.setup, at: t0, failure: .noAccount))
        #expect(model.state == .noAccount)
        #expect(model.symbolName == "icloud.slash")
    }

    @Test func lastSyncedSurvivesARelaunch() async {
        let clock = Clock(t0)
        let defaults = freshDefaults()
        let first = model(clock: clock, defaults: defaults)
        first.handle(finished(.exporting, at: t0))
        clock.now = t0.addingTimeInterval(122)

        let second = model(clock: clock, defaults: defaults)
        #expect(second.state == .waiting)
        #expect(second.lastSynced == t0.addingTimeInterval(2))
        #expect(second.statusText == "Synced 2 minutes ago")
        await second.refreshAccount()
        #expect(second.state == .waiting)

        let never = model(clock: clock)
        #expect(never.statusText == "Waiting for iCloud.")
    }
}
