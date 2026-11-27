# Milestone 7: Apple Developer Account and Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Everything Matt creates (highlights, notes, bookmarks, conversations, prompts, colors) syncs through his private iCloud database, his reading position and a named set of preferences follow him, the app keeps working and says so plainly when iCloud is not there, a daily local backup can bring back anything that goes missing, and development builds can never touch his real notes again.

**Architecture:** The app is signed by Matt's team with iCloud entitlements and reads its own entitlements at launch to learn which CloudKit container and environment it mirrors (`SyncConfiguration`); each container and environment pair gets its own local store directory (`StoreLocation`), so one store file is never mirrored to two cloud databases and a Debug build (its own bundle ID and its own `.dev` container) is structurally separate from the Release build Matt reads in. The synced store is a new file: the old local `Markup.store` is never opened for writing again and its records are copied in once by uuid (`StoreCopy`, the route Apple's engineers recommend), which is also how a backup is restored. `SyncMonitor` turns Core Data's CloudKit events into `SyncEvent`s; `SyncStatusModel` turns those and the account status into the one line Settings shows; `SyncCoordinator` holds seeding back until the first import on a fresh device, merges duplicate seeds by key after every import (`SeedMerge`), and tells the models to reload. Preferences travel through `NSUbiquitousKeyValueStore` mirrored onto the existing `UserDefaults` keys (`PreferenceSync`), so `@AppStorage` keeps working. API keys move to the data-protection keychain as synchronizable items.

**Tech Stack:** Swift 6.2, SwiftUI, SwiftData with `cloudKitDatabase: .private`, Core Data's `NSPersistentCloudKitContainer.eventChangedNotification`, CloudKit (`CKContainer.accountStatus`, `CKError`), `NSUbiquitousKeyValueStore`, the `SQLite3` system module's online backup API, Security (`SecTask` entitlements, data-protection keychain), Swift Testing, `xcodebuild -allowProvisioningUpdates`. GRDB stays the only third-party dependency.

**Spec:** `docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md` (Decisions › Sync and iOS, Data model, Milestones › 7, Verification › Sync and Milestone 7, anti-goal "Sync that loses or duplicates highlights"). Design rules: `PRODUCT.md`, `DESIGN.md`, `CLAUDE.md`. Brainstorm with Matt on 2026-11-09: the rulings below record his four choices (only this Mac to test with today; reading position, translation and note preferences and assistant choices travel, text size, spacing and appearance stay per device; automatic local backups; a status line in Settings).

## Before execution starts (Matt)

1. Xcode › Settings › Accounts: add the Apple Account that is enrolled, and confirm the team is listed.
2. Give the executor the ten-character Team ID (developer.apple.com › Account › Membership details), or let Task 3 read it from Xcode's preferences.
3. This Mac is signed in to iCloud with iCloud Drive on, and Passwords & Keychain on if API keys should travel.

Later, inside the plan: Task 3 may need two iCloud containers created by hand in the developer portal; Task 13 needs Matt's go-ahead (and, if finding F1 allows Production, one click in CloudKit Console).

## Global Constraints

- Minimum macOS 26 / iOS 26, Swift language mode 6, Swift Testing, SF Symbols only. GRDB stays the only third-party dependency.
- **CloudKit model rules (spec, Data model):** every attribute has a default or is optional, no `@Attribute(.unique)`, all relationships optional with an inverse. Model changes are additive (optional or defaulted fields) so the store opens without a migration plan. Each record's `uuid` is its identity across devices.
- **Conflicts are last-writer-wins per record (spec).** Data loss is not acceptable: no code path in this plan deletes a record the reader made except the duplicate merges in Task 6, which keep one record per key and move references to it first.
- **Matt's real data.** `~/Library/Application Support/ReadingThroughScripture/Markup.store` (the old local store) is never opened for writing by anything in this plan: `StoreCopy` copies it to a temporary file and reads the copy. A Debug build never opens the Release build's store, defaults, key-value store or keychain group (Task 3 makes that structural). Tasks 1 to 12 run only Debug builds. Task 13 is the only task that runs the Release build, and it starts only on Matt's go-ahead.
- **No fixed-point fonts in chrome**, **no inline colors** (tokens in `ScriptureUI/Palette.swift`, e.g. `Color.inkSecondary`; spacing and radii from `AppSpacing` and `AppRadius`), **no card by reflex**. Plum and `sparkles` are only for the assistant. Verdigris never signals danger; a sync problem is `ink.secondary`, not red and not accent. Deletes are undoable, never confirmed.
- Voice (PRODUCT.md): plain, short, second person, no exclamation marks, no coaching. Every sentence the app shows is given verbatim in this plan; use it as written.
- Reader, column, editor, browser, palette, assistant and Settings behaviour from milestones 2 to 6 is unchanged except where a task names a change. Existing public signatures stay; additions only.
- Tests: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit` (414 pass in 55 suites on main at 1558b1a). No test touches the real Keychain, CloudKit, `NSUbiquitousKeyValueStore.default`, the network, or anything under `~/Library/Application Support/ReadingThroughScripture`. Stores in tests are in memory or under `FileManager.default.temporaryDirectory`. AppKit-touching suites run on the main actor (`@MainActor @Suite`). Keep the `ModelContainer` alive for as long as its contexts are used.
- Build (from Task 3 on): `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/DerivedData -allowProvisioningUpdates -allowProvisioningDeviceRegistration build`.
- Git: `/usr/bin/git`, one command per Bash call, no `cd`. Commit per task, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never merge or push.
- UI tasks (Task 11): load `/impeccable-swift` before writing SwiftUI and verify in the running Debug app (System Events and `screencapture` into the scratchpad).

## Rulings (plan-level decisions the spec leaves open)

1. **Two builds, two worlds (my call).** Debug: bundle ID `com.matthewfurr.ReadingThroughScripture.dev`, container `iCloud.com.matthewfurr.ReadingThroughScripture.dev`, CloudKit Development environment. Release: bundle ID `com.matthewfurr.ReadingThroughScripture`, container `iCloud.com.matthewfurr.ReadingThroughScripture`, Production environment if finding F1 (Task 3) shows a development-signed build may use it, otherwise Development (for now Development regardless: Ruling 15). The app Matt reads in every day becomes the Release build, installed in `/Applications` by `Scripts/install-app.sh`. A Debug build run from Xcode is a separate, empty copy with its own notes, preferences and test iCloud data.
2. **The app learns its sync setup from its own signature (my call).** `SyncConfiguration.current()` reads the `com.apple.developer.icloud-container-identifiers` and `com.apple.developer.icloud-container-environment` entitlements with `SecTask`. No entitlement (an unsigned build, `swift test`) means sync is off. Nothing in code names an environment, so the build settings cannot disagree with the behaviour.
3. **One local store per container and environment (my call).** `~/Library/Application Support/ReadingThroughScripture/Sync/<container>-<Environment>/Markup.store`; an unsigned build uses `…/ReadingThroughScripture/Local/Markup.store`. A launch argument `-storeName Second` opens `Second.store` beside it: a second, empty store mirroring the same cloud database, which stands in for a second device on this Mac (Matt has only this Mac to test with today).
4. **The synced store is new; the old store is copied in, never converted (research, my call).** Core Data only uploads records that have persistent-history entries, and Apple's engineers do not promise that flipping `cloudKitDatabase` on an existing store uploads what is already in it; they recommend copying the objects into the CloudKit-backed container. So the first prepared launch copies every record from the old `Markup.store` into the synced store by uuid (`LegacyImport`), once, and leaves the old file exactly as it was. That untouched file is the "copy taken just before sync first turns on" Matt asked for.
5. **Signing out of iCloud empties the synced store (research; Apple's design, no API to change it).** The data comes back when the same account signs in, but anything not yet uploaded is lost. This is why backups are in this milestone and why they live in their own files.
6. **Backups (Matt: automatic).** One SQLite copy of the store a day, written with SQLite's online backup API (safe while the store is open) to `<store directory>/Backups/yyyy-MM-dd.store`, at launch and whenever the app becomes active and today's is missing; the newest seven are kept. Settings shows when the last one was taken, with **Show in Finder** and **Restore…**.
7. **Restore puts back what is missing and changes nothing else (my call).** Replacing a synced store file with an older copy does not work: the cloud replays its deletions onto it. `StoreCopy.copyMissing` inserts every record whose uuid the live store lacks, as new changes that then sync, and never edits or deletes an existing record. It is additive and deliberate, so it asks no confirmation and registers no undo.
8. **Seeds wait for the first import, and duplicates merge by key (research: Apple's pattern).** On a fresh synced store with an iCloud account, seeding (default colors, built-in prompts) and the old-store import wait for the first import to finish, or 15 seconds, so a second device takes what the cloud has instead of making its own. Where two devices still each made a default, the records with one `builtInKey` merge after every import: the lowest uuid survives (the same on every device, whatever order things arrive in), a survivor the reader never changed takes the fields of a duplicate the reader did change, highlights are re-pointed, and the others are deleted. `HighlightColor` gains `builtInKey`. Two bookmarks on one verse become one.
9. **What travels besides the store (Matt).** Through the iCloud key-value store, mirrored onto the same `UserDefaults` keys: `readingPosition`, `readingPosition.translationID`, `defaultTranslationID`, `showNotelessHighlights`, `finishEditingWithReturn`, `assistantProvider`, `anthropicModel`, `openAIModel`, `compatibleBaseURL`, `compatibleModel`. Not `readerFontSize`, `readerLineSpacing`, `readerAppearance`, `showNotesColumn`, the Notes browser's sort and filter, the export choices or the Settings tab. The spec's `ReadingState` and `UserSettings` single records are not built: a single record duplicates across devices, and the key-value store is last-writer-wins per key by design.
10. **A position from another device never moves the page under the reader (my call).** It is adopted when it arrives while the app is inactive, or before the reader has navigated or scrolled in this launch; otherwise it is ignored and this Mac's next save wins. Adopting goes through the history, so Back returns.
11. **Sync is one line in Settings (Matt), and one quiet symbol when it has failed for a day (my call).** Settings › General gains an iCloud section and a Backups section. The reading window shows nothing about sync unless it has been failing for 24 hours for a reason the reader can act on (iCloud storage full, or an error that is not "offline"): then an `exclamationmark.icloud` toolbar button in `ink.secondary` opens Settings. Being offline or signed out never raises it. The signed-out sentence differs from the mock-up Matt chose, because of Ruling 5: "Not signed in to iCloud. Notes you make now stay on this Mac, and your synced notes return when you sign in."
12. **An empty note is only swept after a day (my call).** The column creates an empty note when the editor opens and fills it when editing ends, and `MarkupModel.reload()` deletes empty notes it is not editing. With sync, the empty note being typed on another device would arrive here and be deleted from under its writer, so the sweep now takes only empty notes whose `modifiedAt` is more than 24 hours old.
13. **API keys move to the iCloud Keychain (spec; research).** A team-signed build can use the data-protection keychain, so keys are written there as synchronizable items; a key the ad-hoc build saved in the login keychain is read from there until `upgradeToSynchronizable` moves it. The first read may show one macOS keychain prompt, because the old item was saved by a differently signed build. Task 12 (item c): the first read of an item the `security` tool seeded prompted for the login keychain password; Allow was never clicked, so the move itself is unverified; while the prompt is up the app's launch is blocked.
14. **Deferred, listed so they are not lost.** A real second device (Matt's other Mac, then the iPhone in milestone 8): "appears on the other device within a minute", push-driven import while running, and the reading position crossing devices are verified then. A real sign-out is not run on Matt's Mac; the signed-out state is unit-tested and described from Apple's engineers' statements. Moving the Release build between CloudKit environments later needs a fresh store and a copy, like Ruling 4. Identical highlights made on two devices offline stay as two.
15. **Release syncs through the Development environment unless Matt chooses Production at go-live (controller, after Task 12; revised in the final fix wave).** The signature may carry Production (F1). The `-initializeCloudKitSchema` path failed twice in rehearsal before the `SyncMonitor` change (NSCocoaErrorDomain 134060 after 30 s: the monitor's main-queue observer deadlocked against `initializeCloudKitSchema()`), and passed once after it (`schema initialized` 6.1 s after launch; Rehearsal results, item (a)). A Production schema that is missing a field would make records silently fail to upload, so the environment is now a choice Matt makes at go-live (Task 13 Step 2):
    - **Development** (the build's setting today): no deploy step; the schema is created as records arrive. Matt's data then lives in an environment that "Reset Development Environment" in CloudKit Console can erase, so that button must never be used while the Release build syncs there.
    - **Production**: run the schema step against the real container's Development environment (Task 13 Step 2), deploy the schema in CloudKit Console, then build Release with `CLOUDKIT_ENVIRONMENT = Production`.
    Moving the Release build between environments after go-live needs a fresh store and a copy, as Ruling 14 says; the old-store marker sits beside the old store, so a later environment never imports the Nov 3 store again.

## Review Focus

1. An empty note being typed on another device arrives here: it is not swept, and it fills in when the other device finishes (Task 8 test `anEmptyNoteYoungerThanADayIsNotSwept`).
2. A record is deleted on another device while this Mac shows it, or has it open in the editor: acting on the stale row does nothing, the editor closes, nothing traps (Task 8 tests `actingOnARowDeletedElsewhereDoesNothing`, `aNoteDeletedElsewhereWhileOpenClosesTheEditor`).
3. A highlight arrives before its color, or its color was deleted elsewhere: it still shows, uncolored, and is not treated as empty (Task 8 test `aHighlightWhoseColorIsMissingStillShows`).
4. The app launches with no iCloud account, or with iCloud unreachable: it opens, seeds at once, saves locally and says which it is (Task 2 test `noAccountSaysWhereTheNotesAre`, Task 7 test `noAccountSeedsAtOnce`).
5. Two devices each seeded the defaults and one renamed Yellow to "Gold" and used it: after the merge there is one Gold and both devices' highlights keep a color (Task 6 test `aRenamedDuplicateGivesItsNameToTheSurvivor`, `theLowestUUIDSurvivesAndHighlightsFollow`).

---

## File Structure

**ScriptureModel (`Packages/ScriptureKit/Sources/ScriptureModel/`)**
- `SyncConfiguration.swift` (create): container identifier and environment, from entitlements.
- `StoreLocation.swift` (create): directories and file names for a sync configuration and store name.
- `MarkupContainer.swift` (modify): `schema`, `developmentContainerIdentifier`, `make(at:sync:)`, `defaultColorKeys`; seeds set `builtInKey`.
- `SyncMonitor.swift` (create): `SyncEvent`, `SyncFailure`, the event observer.
- `StoreCopy.swift` (create): `RestoreSummary`, `StoreCopy.copyMissing`, `LegacyImport`.
- `StoreBackup.swift` (create): daily SQLite copies, pruning, listing.
- `SeedMerge.swift` (create): default color keys, the three merges.
- `SyncCoordinator.swift` (create): first-run policy, prepare, import handling.
- `HighlightColor.swift` (modify): `builtInKey`.
- Tests (`Tests/ScriptureModelTests/`): `SyncConfigurationTests`, `StoreLocationTests`, `SyncMonitorTests`, `StoreCopyTests`, `StoreBackupTests`, `SeedMergeTests`, `SyncCoordinatorTests` (create); additions to `MarkupContainerTests`.

**ScriptureLLM (`Sources/ScriptureLLM/`)**
- `SecretStore.swift` (modify): data-protection keychain first, `upgradeToSynchronizable`.
- Tests: `SecretStoreTests`, `FakeKeychain` (modify).

**ScriptureUI (`Sources/ScriptureUI/`)**
- `SyncStatusModel.swift` (create): `SyncState`, `AccountStatus`, `AccountStatusSource`, `CloudKitAccountSource`, the status text.
- `PreferenceSync.swift` (create): `KeyValueCloud`, `UbiquitousKeyValueCloud`, `SyncedPreferences`, `PreferenceSync`.
- `BackupsModel.swift` (create): last backup, reveal, restore, the summary sentence.
- `SyncSettingsSections.swift` (create): the iCloud and Backups sections; `SyncAttentionButton`.
- `GeneralSettingsView.swift` (modify): takes the two models, shows the sections.
- `NavigationModel.swift` (modify): `isAppActive`, `hasMovedThisSession`, `adoptStoredPosition()`.
- `MarkupModel.swift`, `NotesBrowserModel.swift`, `AssistantModel.swift` (modify): the sweep age; stale rows.
- `PromptTemplatesSettingsView.swift` (modify): `revision`.
- Tests (`Tests/ScriptureUITests/`): `SyncStatusModelTests`, `PreferenceSyncTests`, `BackupsModelTests` (create), `FakeKeyValueCloud` (create); additions to `MarkupModelTests`, `NotesBrowserModelTests`, `NavigationModelTests`.

**App (`Apps/Mac/`)**
- `ReadingThroughScripture.entitlements` (create, beside the project, outside the synchronized folder).
- `ReadingThroughScripture.xcodeproj/project.pbxproj` (modify): team, identity, entitlements, per-configuration bundle ID, `CLOUDKIT_CONTAINER`, `CLOUDKIT_ENVIRONMENT`.
- `ReadingThroughScripture/ReadingThroughScriptureApp.swift` (modify): the launch sequence; `ReadingThroughScripture/AppSync.swift` (create): the app-side wiring object; `ReadingThroughScripture/SyncProbe.swift` (create, `#if DEBUG`); `SettingsView.swift`, `MainWindowView.swift` (modify).
- `Scripts/install-app.sh` (create).
- `README.md`, `DESIGN.md`, the spec, this plan's findings and verification.

---

### Task 1: Sync configuration, store location and the container

**Files:**
- Create: `Sources/ScriptureModel/SyncConfiguration.swift`, `Sources/ScriptureModel/StoreLocation.swift`, `Tests/ScriptureModelTests/SyncConfigurationTests.swift`, `Tests/ScriptureModelTests/StoreLocationTests.swift`
- Modify: `Sources/ScriptureModel/MarkupContainer.swift`, `Tests/ScriptureModelTests/MarkupContainerTests.swift`

**Interfaces:**
- Produces: `public struct SyncConfiguration: Equatable, Sendable { public enum Environment: String, Sendable { case development = "Development", production = "Production" }; public let containerIdentifier: String; public let environment: Environment; public init(containerIdentifier: String, environment: Environment); public init?(containerIdentifiers: [String]?, environment: String?) (nil without a container; the environment is matched case-insensitively and defaults to development); public static func current() -> SyncConfiguration? (macOS: `SecTaskCreateFromSelf` and `SecTaskCopyValueForEntitlement` for the two keys in Ruling 2; other platforms return nil until milestone 8) }`
- Produces: `public struct StoreLocation: Equatable, Sendable { public let directory: URL; public let storeName: String; public var storeURL: URL (directory/"<storeName>.store"); public var backupsDirectory: URL ("Backups" for `Markup`, "Backups-<storeName>" otherwise); public var legacyStoreURL: URL?; public var legacyMarkerURL: URL (directory/"Markup.legacy-imported"); public static let defaultStoreName = "Markup"; public static let storeNameArgument = "storeName"; public static func resolve(sync: SyncConfiguration?, storeName: String? = nil, applicationSupport: URL = .applicationSupportDirectory) -> StoreLocation }`
- Rules for `resolve`: root is `applicationSupport/ReadingThroughScripture`. No sync: `root/Local`. With sync: `root/Sync/<containerIdentifier>-<environment.rawValue>`. A `storeName` is kept only if it is 1 to 32 letters, digits or dashes; anything else is `Markup`. `legacyStoreURL` is nil for a named store and for no sync; for the real container (`MarkupContainer.cloudKitContainerIdentifier`) it is `root/Markup.store`; for any other container it is `directory/Legacy.store` (a rehearsal copy an executor places there).
- Produces on `MarkupContainer`: `public static let developmentContainerIdentifier = "iCloud.com.matthewfurr.ReadingThroughScripture.dev"`; `public static let schema: Schema` (the seven models, used by `make(inMemory:)` too); `public static func make(at location: StoreLocation, sync: SyncConfiguration?) throws -> ModelContainer` (creates the directory; `cloudKitDatabase: .private(sync.containerIdentifier)` with sync, `.none` without). `make(inMemory:)` and `storeURL` stay as they are.

- [ ] **Step 1: Write the failing tests**

```swift
// SyncConfigurationTests
@Test func noContainerMeansNoSync() {
    #expect(SyncConfiguration(containerIdentifiers: nil, environment: "Production") == nil)
    #expect(SyncConfiguration(containerIdentifiers: [], environment: nil) == nil)
}
@Test func theEnvironmentDefaultsToDevelopment() {
    #expect(SyncConfiguration(containerIdentifiers: ["iCloud.x"], environment: nil)
        == SyncConfiguration(containerIdentifier: "iCloud.x", environment: .development))
    #expect(SyncConfiguration(containerIdentifiers: ["iCloud.x"], environment: "production")?.environment == .production)
    #expect(SyncConfiguration(containerIdentifiers: ["iCloud.x", "iCloud.y"], environment: "Development")?.containerIdentifier == "iCloud.x")
}
@Test func aTestProcessHasNoEntitlements() { #expect(SyncConfiguration.current() == nil) }

// StoreLocationTests
private let support = URL(filePath: "/tmp/Support", directoryHint: .isDirectory)
private let real = SyncConfiguration(containerIdentifier: MarkupContainer.cloudKitContainerIdentifier, environment: .production)
private let dev = SyncConfiguration(containerIdentifier: MarkupContainer.developmentContainerIdentifier, environment: .development)

@Test func anUnsignedBuildKeepsItsOwnLocalStore() {
    let location = StoreLocation.resolve(sync: nil, applicationSupport: support)
    #expect(location.storeURL.path == "/tmp/Support/ReadingThroughScripture/Local/Markup.store")
    #expect(location.legacyStoreURL == nil)
}
@Test func eachContainerAndEnvironmentHasItsOwnDirectory() {
    #expect(StoreLocation.resolve(sync: real, applicationSupport: support).storeURL.path
        == "/tmp/Support/ReadingThroughScripture/Sync/iCloud.com.matthewfurr.ReadingThroughScripture-Production/Markup.store")
    #expect(StoreLocation.resolve(sync: dev, applicationSupport: support).directory.lastPathComponent
        == "iCloud.com.matthewfurr.ReadingThroughScripture.dev-Development")
}
@Test func theRealContainerImportsTheOldLocalStore() {
    #expect(StoreLocation.resolve(sync: real, applicationSupport: support).legacyStoreURL?.path
        == "/tmp/Support/ReadingThroughScripture/Markup.store")
}
@Test func anotherContainerImportsOnlyARehearsalCopy() {
    let location = StoreLocation.resolve(sync: dev, applicationSupport: support)
    #expect(location.legacyStoreURL == location.directory.appending(path: "Legacy.store"))
}
@Test func aNamedStoreSitsBesideTheMainOneAndImportsNothing() {
    let location = StoreLocation.resolve(sync: dev, storeName: "Second", applicationSupport: support)
    #expect(location.storeURL.lastPathComponent == "Second.store")
    #expect(location.backupsDirectory.lastPathComponent == "Backups-Second")
    #expect(location.legacyStoreURL == nil)
}
@Test func aStoreNameThatIsNotPlainFallsBackToMarkup() {
    for name in ["../x", "a b", "", String(repeating: "a", count: 33)] {
        #expect(StoreLocation.resolve(sync: dev, storeName: name, applicationSupport: support).storeName == "Markup", "\(name)")
    }
}

// MarkupContainerTests
@Test func aStoreOnDiskOpensWhereTheLocationSays() throws {
    let support = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: support) }
    let location = StoreLocation.resolve(sync: nil, applicationSupport: support)
    let container = try MarkupContainer.make(at: location, sync: nil)
    container.mainContext.insert(Bookmark(book: "GEN", chapter: 1, verse: 1))
    try container.mainContext.save()
    #expect(FileManager.default.fileExists(atPath: location.storeURL.path))
    #expect(try container.mainContext.fetchCount(FetchDescriptor<Bookmark>()) == 1)
}
```

- [ ] **Step 2: Run to verify failure** — the test command; expected: the build fails on `SyncConfiguration` and `StoreLocation`.
- [ ] **Step 3: Implement** the two types and the `MarkupContainer` additions from the Interfaces block.
- [ ] **Step 4: Run the whole suite** — expected: 414 + 10 pass.
- [ ] **Step 5: Commit** — `feat: sync configuration from entitlements; a store directory per container and environment`.

---

### Task 2: Sync events and the status line's model

**Files:**
- Create: `Sources/ScriptureModel/SyncMonitor.swift`, `Sources/ScriptureUI/SyncStatusModel.swift`, `Tests/ScriptureModelTests/SyncMonitorTests.swift`, `Tests/ScriptureUITests/SyncStatusModelTests.swift`

**Interfaces:**
- Produces (ScriptureModel): `public enum SyncFailure: Equatable, Sendable { case quotaExceeded, noAccount, network, other(String) }`; `public struct SyncEvent: Equatable, Sendable { public enum Kind: Sendable { case setup, importing, exporting }; public var kind: Kind; public var started: Date; public var ended: Date?; public var failure: SyncFailure?; public init(kind:started:ended:failure:) }`; `@MainActor public final class SyncMonitor { public var onEvent: ((SyncEvent) -> Void)?; public init(center: NotificationCenter = .default); public func start() (observes `NSPersistentCloudKitContainer.eventChangedNotification`, maps the event under `eventNotificationUserInfoKey`, logs each one to `Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "sync")`); public nonisolated static func failure(from error: (any Error)?) -> SyncFailure? }`.
- `failure(from:)`: nil for nil. `CKError.quotaExceeded` → `.quotaExceeded`; `.notAuthenticated`, `.accountTemporarilyUnavailable` → `.noAccount`; `.networkUnavailable`, `.networkFailure`, `.serviceUnavailable`, `.requestRateLimited`, `.zoneBusy` → `.network`; `.partialFailure` → the first of quota, account, network found among `partialErrorsByItemID`, else `.other`; anything else → `.other(error.localizedDescription)`.
- Produces (ScriptureUI): `public enum AccountStatus: Sendable { case available, noAccount, restricted, temporarilyUnavailable, unknown }`; `public protocol AccountStatusSource: Sendable { func status() async -> AccountStatus }`; `public struct CloudKitAccountSource: AccountStatusSource { public init(containerIdentifier: String) }` (`CKContainer(identifier:).accountStatus()`, an error is `.unknown`); `public enum SyncState: Equatable, Sendable { case off, noAccount, unavailable, waiting, syncing, synced(Date), failing(SyncFailure, since: Date) }`.
- Produces: `@MainActor @Observable public final class SyncStatusModel { public private(set) var state: SyncState; public private(set) var lastSynced: Date?; public var onFirstImport: (() -> Void)?; public var onImport: (() -> Void)?; public static let lastSyncedKey = "lastSyncedAt"; public static let attentionAfter: TimeInterval = 86_400; public init(sync: SyncConfiguration?, account: any AccountStatusSource, defaults: UserDefaults = .standard, now: @escaping @Sendable () -> Date = { Date() }); public func refreshAccount() async; public func handle(_ event: SyncEvent); public var isAccountAvailable: Bool; public var statusText: String; public var symbolName: String; public var needsAttention: Bool; public var attentionHelp: String }`.
- State rules: no sync → `.off` and nothing changes it. `refreshAccount`: `.noAccount` → `.noAccount`; `.restricted`, `.temporarilyUnavailable`, `.unknown` → `.unavailable`; `.available` → `.waiting` unless a sync state is already showing. `handle`: an event with no `ended` → `.syncing` (unless failing); a finished event with no failure → `.synced(ended)`, `lastSynced` stored under `lastSyncedKey`; a finished import with no failure calls `onImport`, and the first one also `onFirstImport` before it; a failure of `.noAccount` → `.noAccount`; any other failure → `.failing(failure, since:)` keeping the `since` of an unbroken run of failures. `needsAttention`: failing with `.quotaExceeded` or `.other` for at least `attentionAfter`.
- Copy (`statusText`), exactly:
  - off: `Sync is off in this build. Your notes stay on this Mac.`
  - noAccount: `Not signed in to iCloud. Notes you make now stay on this Mac, and your synced notes return when you sign in.`
  - unavailable: `iCloud is not available right now. Notes you make stay on this Mac until it is.`
  - waiting: `Waiting for iCloud.` with no `lastSynced`, else the synced sentence for `lastSynced`
  - syncing: `Syncing…`
  - synced: `Synced just now` under 60 seconds, else `Synced ` + `RelativeDateTimeFormatter` (`unitsStyle = .full`, locale `en_US` in tests) for the date relative to `now()`, e.g. `Synced 2 minutes ago`
  - failing quota: `iCloud storage is full. Notes you make stay on this Mac until there is room.`
  - failing network: `No connection. Your notes sync when you are back online.`
  - failing other: `Could not sync. The app will try again.`
- `symbolName`: `icloud.slash` for off, noAccount, unavailable; `exclamationmark.icloud` for failing quota and other; `icloud` otherwise. `attentionHelp`: `Your notes have not synced since ` + the `since` date (`.dateTime.weekday(.wide).month().day()`) + `. Open Settings.`

- [ ] **Step 1: Write the failing tests**

```swift
// SyncMonitorTests
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
@Test func anythingElseKeepsItsDescription() {
    let error = NSError(domain: "x", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"])
    #expect(SyncMonitor.failure(from: error) == .other("boom"))
}

// SyncStatusModelTests (@MainActor @Suite); helpers: FakeAccount(status), a fixed `t0`, a mutable clock box, a fresh UserDefaults suite
@Test func anUnsignedBuildSaysSyncIsOff()               // state .off; text as above; handle(event) leaves .off
@Test func noAccountSaysWhereTheNotesAre() async        // FakeAccount(.noAccount); after refreshAccount: .noAccount, the sentence verbatim, symbol icloud.slash, isAccountAvailable false
@Test func aFinishedExportReadsAsSynced()               // handle(exporting, t0…t0+2): .synced(t0+2); clock t0+12 → "Synced just now"; clock t0+122 → "Synced 2 minutes ago"
@Test func anEventInFlightReadsAsSyncing()              // ended nil → .syncing, "Syncing…"
@Test func aFullICloudSaysSo()                          // failure .quotaExceeded → the quota sentence, symbol exclamationmark.icloud
@Test func offlineIsNotWorthANotice()                   // failure .network at t0, clock t0+3 days → needsAttention false
@Test func aDayOfFailureAsksForAttention()              // .other at t0; t0+23h false; a second failure at t0+2h keeps since t0; t0+25h true; a finished success → false
@Test func theFirstFinishedImportIsReportedOnce()       // two finished imports: onFirstImport 1, onImport 2; a failed import: neither
@Test func aSetupThatFindsNoAccountBecomesNoAccount()   // setup failure .noAccount → .noAccount
@Test func lastSyncedSurvivesARelaunch()                // a second model on the same defaults starts .waiting with "Synced …" text
```

Write each body with `#expect` on `state`, `statusText`, `symbolName` or the counters named in its comment.

- [ ] **Step 2: Run to verify failure**, **Step 3: Implement** per the Interfaces block, **Step 4: Run the whole suite** (expected: all pass).
- [ ] **Step 5: Commit** — `feat: sync events and the status line's model`.

---

### Task 3: Signing, entitlements and sync switched on in the Debug build

No unit tests: this task is project configuration and a recorded proof. It needs the "Before execution starts" steps done. If the team is not in Xcode, stop and say so.

**Files:**
- Create: `Apps/Mac/ReadingThroughScripture.entitlements`, `Scripts/install-app.sh`, `Apps/Mac/ReadingThroughScripture/AppSync.swift`
- Modify: `Apps/Mac/ReadingThroughScripture.xcodeproj/project.pbxproj`, `Apps/Mac/ReadingThroughScripture/ReadingThroughScriptureApp.swift`, `README.md` (Prerequisites, Running the app), this plan (the findings table)

**Interfaces:**
- Entitlements file, six keys: `com.apple.developer.icloud-container-identifiers` = [`$(CLOUDKIT_CONTAINER)`]; `com.apple.developer.icloud-services` = [`CloudKit`]; `com.apple.developer.icloud-container-environment` = `$(CLOUDKIT_ENVIRONMENT)`; `com.apple.developer.aps-environment` = `development`; `com.apple.developer.ubiquity-kvstore-identifier` = `$(TeamIdentifierPrefix)$(CFBundleIdentifier)`; `keychain-access-groups` = [`$(AppIdentifierPrefix)$(CFBundleIdentifier)`]. No App Sandbox, hardened runtime stays off.
- Target build settings, both configurations: `CODE_SIGN_STYLE = Automatic`, `CODE_SIGN_IDENTITY = "Apple Development"`, `DEVELOPMENT_TEAM = <Team ID>`, `CODE_SIGN_ENTITLEMENTS = ReadingThroughScripture.entitlements`. Debug: `PRODUCT_BUNDLE_IDENTIFIER = com.matthewfurr.ReadingThroughScripture.dev`, `CLOUDKIT_CONTAINER = iCloud.com.matthewfurr.ReadingThroughScripture.dev`, `CLOUDKIT_ENVIRONMENT = Development`. Release: `PRODUCT_BUNDLE_IDENTIFIER = com.matthewfurr.ReadingThroughScripture`, `CLOUDKIT_CONTAINER = iCloud.com.matthewfurr.ReadingThroughScripture`, `CLOUDKIT_ENVIRONMENT = Production`. `PRODUCT_NAME` stays `ReadingThroughScripture` in both (System Events drives the process by that name).
- Produces: `@MainActor final class AppSync` in the app target, the one object that owns sync wiring: `init()` resolves `SyncConfiguration.current()` and `StoreLocation.resolve(sync:storeName: UserDefaults.standard.string(forKey: StoreLocation.storeNameArgument))`, logs `store <path>, sync <container> <environment>` (or `sync off`) to the `sync` category; `let sync: SyncConfiguration?`, `let location: StoreLocation`, `let status: SyncStatusModel`, `func makeContainer() throws -> ModelContainer` (`MarkupContainer.make(at:sync:)`), `func start()` (starts a `SyncMonitor` feeding `status.handle`, refreshes the account now and on `.CKAccountChanged` and `NSApplication.didBecomeActiveNotification`). Later tasks add to it.
- `ReadingThroughScriptureApp.init` uses `AppSync` for the container instead of `MarkupContainer.make()`; seeding stays where it is until Task 7.
- `Scripts/install-app.sh`: builds the Release configuration with the provisioning flags into `Build/DerivedData`, quits a running `/Applications/ReadingThroughScripture.app`, replaces it with `ditto`, prints the installed path. It is written here and first run in Task 13.
- With `-initializeCloudKitSchema YES` in the arguments and a Development environment, `AppSync.makeContainer()` first runs Apple's documented schema initialization (SwiftData article "Syncing model data across a person's devices": an `NSPersistentCloudKitContainer` built from `NSManagedObjectModel.makeManagedObjectModel(for:)` on the same store URL, `initializeCloudKitSchema()`, then unload the store) and logs `schema initialized`.

- [x] **Step 1: Confirm the team.** `defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier` lists a team; record its Team ID. Without one, stop.
- [x] **Step 2: Write the entitlements file and the build settings.** Build with the command in Global Constraints. Expected: `** BUILD SUCCEEDED **`. If signing fails because an iCloud container does not exist, Matt creates both containers at developer.apple.com › Certificates, Identifiers & Profiles › Identifiers › iCloud Containers, then build again. Record which happened as F4.
- [x] **Step 3: Check the signature.** `codesign -d --entitlements - Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app` shows the `.dev` container, `Development`, the key-value identifier and the keychain group; `Contents/embedded.provisionprofile` exists.
- [x] **Step 4: Add `AppSync` and wire the container.** Launch the Debug app; `log show --last 2m --predicate 'subsystem == "com.matthewfurr.ReadingThroughScripture" AND category == "sync"'` shows the store under `Sync/iCloud.com.matthewfurr.ReadingThroughScripture.dev-Development/` and a finished `setup` event with no failure (F2). The old `Markup.store` modification date is unchanged.
- [x] **Step 5: Make a bookmark in the Debug app** and wait for a finished `exporting` event with no failure in the log (F2).
- [x] **Step 6: Try the Release signature (F1), without launching it.** Build `-configuration Release`. If it succeeds, `security cms -D -i Build/DerivedData/Build/Products/Release/ReadingThroughScripture.app/Contents/embedded.provisionprofile` shows whether `com.apple.developer.icloud-container-environment` allows `Production`, and `codesign -d --entitlements -` shows `Production`. If the build fails on that entitlement or the profile allows only `Development`, set the Release `CLOUDKIT_ENVIRONMENT = Development`, rebuild, and record F1 as "not allowed; Release uses the Development environment of the real container". Do not launch the Release app.
- [x] **Step 7: Key-value store and keychain probes (F3, F6).** In `AppSync.start()`, behind `#if DEBUG`, log whether `NSUbiquitousKeyValueStore.default.synchronize()` returns true, and whether adding then deleting a synchronizable generic-password item named `probe` with `kSecUseDataProtectionKeychain` returns `errSecSuccess`. Record both, then remove the keychain probe code (the key-value line may stay).
- [x] **Step 8: Record the findings** in the table at the end of this plan. If F2 fails (sync cannot be set up at all for an unsandboxed development-signed build), stop the plan and report: the design needs the App Sandbox and a store move, which is Matt's decision.
- [x] **Step 9: README.** Prerequisites: the team in Xcode, iCloud signed in. Running the app: the new build command; "A Debug build is a separate copy with its own notes, preferences and test iCloud data (`…/Sync/iCloud.com.matthewfurr.ReadingThroughScripture.dev-Development/`). The app you read in is the Release build: run `Scripts/install-app.sh`."
- [x] **Step 10: Run the whole suite, commit** — `feat: team signing, iCloud entitlements, a separate Debug identity; sync on in the Debug build`.

---

### Task 4: Copying what is missing from one store into another

**Files:**
- Create: `Sources/ScriptureModel/StoreCopy.swift`, `Tests/ScriptureModelTests/StoreCopyTests.swift`

**Interfaces:**
- Produces: `public struct RestoreSummary: Equatable, Sendable { public var highlights = 0, notes = 0, bookmarks = 0, colors = 0, conversations = 0, prompts = 0; public init(); public var total: Int }`.
- Produces: `public enum StoreCopy { @MainActor public static func copyMissing(from source: URL, into container: ModelContainer) throws -> RestoreSummary }`. It copies the source file (and its `-wal` and `-shm` if present) into a new temporary directory, opens the copy with `MarkupContainer.schema` and `cloudKitDatabase: .none`, inserts what is missing, saves once, and removes the temporary directory. The source file is never opened.
- What "missing" means, in this order: a color whose `uuid` is absent; a highlight whose `uuid` is absent (with its note); a highlight-scoped note whose `uuid` is absent and whose highlight exists live with no note (attached to it); a chapter note whose `uuid` is absent; a bookmark whose `uuid` is absent and whose verse has no live bookmark; a thread whose `uuid` is absent (with all its messages); a prompt that is not built in and whose `uuid` is absent; a built-in prompt whose `builtInKey` no live prompt has. Every stored field is copied, including `uuid` and the dates. Nothing live is changed or deleted. Notes count under `notes`, threads under `conversations`.
- Produces: `public enum LegacyImport { @MainActor public static func importIfNeeded(_ location: StoreLocation, into container: ModelContainer) throws -> RestoreSummary? }`: nil when `location.legacyStoreURL` is nil, the file is absent, or `location.legacyMarkerURL` exists; otherwise `copyMissing`, then writes the marker (the ISO 8601 date as text) and returns the summary. A failed copy writes no marker.

- [ ] **Step 1: Write the failing tests** (`@MainActor @Suite struct StoreCopyTests`). A helper `makeSource() throws -> (url: URL, container: ModelContainer)` builds an on-disk store under the temporary directory holding: two colors; a highlight on MAT 5:3 with a note "first"; a chapter note on PSA 23 "shepherd"; a bookmark on GEN 1:1 labelled "start"; a thread with a user and an assistant message; a user prompt "Mine"; a built-in prompt with key `outline`.

```swift
@Test func everythingMissingIsCopiedWithItsIdentity() throws {
    let source = try makeSource()
    let live = try MarkupContainer.make(inMemory: true)
    let summary = try StoreCopy.copyMissing(from: source.url, into: live)
    #expect(summary == { var s = RestoreSummary(); s.colors = 2; s.highlights = 1; s.notes = 2; s.bookmarks = 1; s.conversations = 1; s.prompts = 2; return s }())
    let highlight = try #require(try live.mainContext.fetch(FetchDescriptor<Highlight>()).first)
    let original = try #require(try source.container.mainContext.fetch(FetchDescriptor<Highlight>()).first)
    #expect(highlight.uuid == original.uuid)
    #expect(highlight.createdAt == original.createdAt)
    #expect(highlight.note?.body == "first")
    #expect(highlight.note?.highlight === highlight)
    let thread = try #require(try live.mainContext.fetch(FetchDescriptor<ChatThread>()).first)
    #expect(thread.orderedMessages.map(\.role) == [.user, .assistant])
}
@Test func aSecondCopyAddsNothing() throws                    // summary.total == 0, counts unchanged
@Test func anExistingRecordIsNeverChanged() throws            // live holds a note with the source note's uuid and body "edited": after the copy its body is still "edited"
@Test func aBookmarkOnABookmarkedVerseIsSkipped() throws      // live has its own bookmark on GEN 1:1: still one bookmark there, summary.bookmarks == 0
@Test func aMissingNoteReturnsToItsLiveHighlight() throws     // live has the highlight (same uuid) with no note: the note is attached, summary.notes counts it, highlights == 0
@Test func aBuiltInPromptAlreadyPresentByKeyIsSkipped() throws
@Test func theSourceFileIsLeftExactlyAsItWas() throws         // the source's bytes (Data(contentsOf:)) are equal before and after
@Test func theOldStoreIsImportedOnce() throws                 // LegacyImport: a location whose legacyStoreURL is the source; first call returns the summary and writes the marker; second returns nil
@Test func noOldStoreMeansNoMarker() throws                   // nil, marker absent
```

- [ ] **Step 2: Run to verify failure**, **Step 3: Implement**, **Step 4: Run the whole suite**.
- [ ] **Step 5: Commit** — `feat: copy missing records between stores; the one-time import of the old store`.

---

### Task 5: Daily backups

**Files:**
- Create: `Sources/ScriptureModel/StoreBackup.swift`, `Tests/ScriptureModelTests/StoreBackupTests.swift`

**Interfaces:**
- Produces: `public enum StoreBackup { public static let kept = 7; public struct Backup: Equatable, Sendable { public let url: URL; public let day: String (the `yyyy-MM-dd` in the name) }; public static func copy(storeAt source: URL, to destination: URL) throws (SQLite online backup: open the source read-only, `sqlite3_backup_init`, step to completion, finish; one consistent file with no `-wal`); @discardableResult public static func backUpIfNeeded(_ location: StoreLocation, now: Date = Date(), calendar: Calendar = .current) throws -> URL? (nil when the store file is absent or `Backups/<day>.store` exists; otherwise creates the directory, copies, prunes, returns the file); public static func backups(in location: StoreLocation) throws -> [Backup] (files named `yyyy-MM-dd.store`, newest first; an absent directory is an empty list); static func prune(_ location: StoreLocation) throws (deletes dated backups beyond the newest `kept`; never touches a file with another name) }`.
- The day string is built from the calendar's year, month and day components (`%04d-%02d-%02d`), not from a locale-dependent formatter.

- [x] **Step 1: Write the failing tests** (`@MainActor @Suite struct StoreBackupTests`; a helper makes a `StoreLocation` under a fresh temporary directory and an open container on it with one bookmark and one highlight with a note).

```swift
@Test func aBackupTakenWhileTheStoreIsOpenHoldsTheSameRecords() throws {
    let (location, container) = try makeStore()
    let url = try #require(try StoreBackup.backUpIfNeeded(location, now: day(2026, 11, 9)))
    #expect(url.lastPathComponent == "2026-11-09.store")
    let live = try MarkupContainer.make(inMemory: true)
    let summary = try StoreCopy.copyMissing(from: url, into: live)
    #expect(summary.bookmarks == 1 && summary.highlights == 1 && summary.notes == 1)
    _ = container
}
@Test func thereIsOneBackupADay() throws           // a second call on 11-09 returns nil; 11-10 returns "2026-11-10.store"
@Test func onlyTheNewestSevenAreKept() throws      // nine consecutive days: backups(in:).map(\.day) is the last seven, newest first; "Keep me.store" placed in the directory is still there
@Test func noStoreNoBackup() throws                // a location with no store file: nil, no directory created
@Test func backupsAreListedNewestFirst() throws
```

- [x] **Step 2: Run to verify failure**, **Step 3: Implement** with `import SQLite3`, **Step 4: Run the whole suite**.
- [x] **Step 5: Wire it** in `AppSync`: `func backUpIfNeeded()` calls `StoreBackup.backUpIfNeeded(location)` off the main actor and logs a failure to the `sync` category without surfacing it; called from `start()` and on `didBecomeActiveNotification`. Launch the Debug app and confirm today's file appears under the Debug store's `Backups/`.
- [x] **Step 6: Commit** — `feat: a daily backup of the notes store, the last seven kept`.

---

### Task 6: Seed keys and merging duplicates

**Files:**
- Create: `Sources/ScriptureModel/SeedMerge.swift`, `Tests/ScriptureModelTests/SeedMergeTests.swift`
- Modify: `Sources/ScriptureModel/HighlightColor.swift` (`public var builtInKey: String?`), `Sources/ScriptureModel/MarkupContainer.swift`, `Sources/ScriptureModel/StoreCopy.swift` (copy `builtInKey`), `Tests/ScriptureModelTests/MarkupContainerTests.swift`

**Interfaces:**
- Produces on `MarkupContainer`: `public static let defaultColorKeys = ["yellow", "green", "blue", "rose", "orange"]` (parallel to `defaultColors`); `seedDefaultColorsIfNeeded` sets each seeded color's `builtInKey`.
- Produces: `public enum SeedMerge` with `@MainActor @discardableResult` functions, each returning how many records it changed or removed and changing nothing on a second run:
  - `assignDefaultColorKeysIfNeeded(in context: ModelContext) throws -> Int`: for `isDefault` colors with no key, in `sortOrder`: first a match by name (case-insensitive) against `defaultColors` or `legacyDefaultColors` at an index whose key is unused; then a match by hex pair the same way; then the first unused key. Colors that are not defaults never get a key.
  - `mergeDuplicateColors(in context: ModelContext) throws -> Int`: for each `builtInKey` held by more than one color, the survivor is the one with the lowest `uuid.uuidString`. If the survivor's name and hex pair still equal that key's default (or legacy default) and a duplicate's do not, the survivor takes the name, both hexes and `sortOrder` of the changed duplicate with the lowest uuid. Every highlight whose `colorID` is a duplicate's `uuid` is set to the survivor's. The duplicates are deleted.
  - `mergeDuplicateBuiltInPrompts(in context: ModelContext, seeds: [PromptSeed]) throws -> Int`: the same shape by `builtInKey`; "changed" means `title`, `summary` or `body` differs from the seed with that key (or its `legacyTitle`), or `isEnabled` is false; the survivor takes `title`, `summary`, `body`, `isEnabled` and `sortOrder` from the changed duplicate with the lowest uuid.
  - `mergeDuplicateBookmarks(in context: ModelContext) throws -> Int`: bookmarks on one book, chapter and verse: the earliest `createdAt` survives (ties: lowest uuid), takes the first non-nil label among the others if it has none, and the others are deleted.
  - `mergeAll(in context: ModelContext, seeds: [PromptSeed]) throws -> Int`: the three merges, one save.

- [x] **Step 1: Write the failing tests** (`@MainActor @Suite struct SeedMergeTests`; `id(_ n: Int)` makes `UUID(uuidString: "00000000-0000-0000-0000-00000000000\(n)")!`).

```swift
@Test func existingDefaultsGetTheirKeys() throws {
    // legacy-style defaults with no keys: "Yellow" and "Pink" by legacy name, "Gold" carrying Green's current hex pair, "Mine" renamed and recolored, and a user color
    // expect keys: Yellow → "yellow", Pink → "rose", Gold → "green", Mine → "blue" (the first unused), the user color → nil
}
@Test func theLowestUUIDSurvivesAndHighlightsFollow() throws {
    let context = try MarkupContainer.make(inMemory: true).mainContext  // keep the container alive in the real test
    let a = color("Yellow", key: "yellow", uuid: id(1)), b = color("Yellow", key: "yellow", uuid: id(2))
    let highlight = Highlight(book: "MAT", chapter: 5, verse: 3, endVerse: 3, startOffset: 0, endOffset: 7, translationID: "ESV", colorID: b.uuid, quotedText: "Blessed")
    // insert a, b, highlight; mergeDuplicateColors == 1
    #expect(try context.fetch(FetchDescriptor<HighlightColor>()).map(\.uuid) == [id(1)])
    #expect(highlight.colorID == id(1))
}
@Test func aRenamedDuplicateGivesItsNameToTheSurvivor() throws
    // id(1) untouched Yellow, id(2) renamed "Gold" with hexes "#F0D060"/"#5A4A00" and used by a highlight:
    // one color, uuid id(1), name "Gold", lightHex "#F0D060", darkHex "#5A4A00"; the highlight's colorID is id(1)
@Test func mergingTwiceChangesNothing() throws                // second mergeAll returns 0
@Test func coloursTheReaderMadeAreNeverMerged() throws        // two non-default colors named "Sky": both remain
@Test func duplicateBuiltInPromptsMergeAndKeepTheEdit() throws // key "outline": id(1) pristine, id(2) body "my outline" and disabled → one prompt, uuid id(1), body "my outline", isEnabled false
@Test func twoBookmarksOnOneVerseBecomeOne() throws           // the earlier createdAt survives and takes the later one's label "start"
@Test func seededColorsCarryTheirKeys() throws                // MarkupContainerTests: after seedDefaultColorsIfNeeded the keys are defaultColorKeys in sort order
```

- [x] **Step 2: Run to verify failure**, **Step 3: Implement**, **Step 4: Run the whole suite**.
- [x] **Step 5: Commit** — `feat: default colors carry a key; duplicate defaults, built-in prompts and bookmarks merge`.

---

### Task 7: The first run and every import after it

**Files:**
- Create: `Sources/ScriptureModel/SyncCoordinator.swift`, `Tests/ScriptureModelTests/SyncCoordinatorTests.swift`
- Modify: `Apps/Mac/ReadingThroughScripture/AppSync.swift`, `Apps/Mac/ReadingThroughScripture/ReadingThroughScriptureApp.swift`, `Sources/ScriptureUI/PromptTemplatesSettingsView.swift`, `Apps/Mac/ReadingThroughScripture/SettingsView.swift`

**Interfaces:**
- Consumes: `LegacyImport.importIfNeeded` (Task 4), `SeedMerge` (Task 6), `SyncStatusModel.onImport` and `isAccountAvailable` (Task 2), `PromptTemplateStore.seedIfNeeded` and `migrateBuiltInsIfNeeded`, the three `MarkupContainer` color functions.
- Produces: `@MainActor public final class SyncCoordinator { public init(container: ModelContainer, location: StoreLocation, sync: SyncConfiguration?, seeds: [PromptSeed], legacyPromptOrder: [String], firstImportTimeout: Duration = .seconds(15), refresh: @escaping @MainActor () -> Void); public private(set) var isPrepared: Bool; public static func shouldWaitForFirstImport(sync: SyncConfiguration?, storeIsEmpty: Bool, accountAvailable: Bool) -> Bool (true only when all three hold; "empty" is no colors and no prompts); public func start(accountAvailable: Bool) (prepares now, or arms the timeout and waits); public func importFinished() (prepares if still waiting, then `SeedMerge.mergeAll`, then `refresh`); public func prepareNow() }`.
- `prepareNow()` is idempotent and runs, in order: `LegacyImport.importIfNeeded`; `seedDefaultColorsIfNeeded`; `migrateDefaultColorsIfNeeded`; `conformColorsIfNeeded`; `SeedMerge.assignDefaultColorKeysIfNeeded`; the template store's `seedIfNeeded(seeds)` and `migrateBuiltInsIfNeeded(from:legacyOrder:)`; `SeedMerge.mergeAll`; `refresh()`. The two steps the app treats as cosmetic today (conforming colors, migrating built-ins) still only log on failure.
- App: `AppSync` owns the coordinator; the seeding calls leave `ReadingThroughScriptureApp.init`. `AppSync.refreshAll` (the `refresh` closure) reloads, 300 ms after the last request: `markupModel.reload()`, `assistantModel.refresh()`, `assistantModel.reloadTemplates()`, `notesBrowser.reload()`, `colorSettings.reload()`, and increments an observable `templatesRevision`. `status.onImport` calls `coordinator.importFinished()`. `start()` awaits the first `refreshAccount()` and then calls `coordinator.start(accountAvailable:)`.
- `PromptTemplatesSettingsView` gains `revision: Int = 0` and reloads when it changes; `SettingsView` passes `templatesRevision`.

- [x] **Step 1: Write the failing tests** (`@MainActor @Suite struct SyncCoordinatorTests`; in-memory containers, a temporary-directory location, two seeds, a refresh counter, `sync` the dev configuration from Task 1).

```swift
@Test func thePolicyWaitsOnlyForAFreshSyncedStoreWithAnAccount() {
    #expect(SyncCoordinator.shouldWaitForFirstImport(sync: dev, storeIsEmpty: true, accountAvailable: true))
    #expect(!SyncCoordinator.shouldWaitForFirstImport(sync: nil, storeIsEmpty: true, accountAvailable: true))
    #expect(!SyncCoordinator.shouldWaitForFirstImport(sync: dev, storeIsEmpty: false, accountAvailable: true))
    #expect(!SyncCoordinator.shouldWaitForFirstImport(sync: dev, storeIsEmpty: true, accountAvailable: false))
}
@Test func withoutSyncEverythingIsSeededAtOnce() throws             // start: 5 colors with keys, 2 prompts, isPrepared, refresh == 1
@Test func aFreshSyncedStoreWaitsForTheFirstImport() throws         // start(accountAvailable: true), timeout 60 s: 0 colors, !isPrepared
@Test func whatTheCloudBroughtIsNotSeededAgain() throws             // while waiting, insert the five keyed defaults (as an import would); importFinished(): still 5 colors, isPrepared
@Test func anEmptyCloudSeedsAfterTheImport() throws                 // waiting, importFinished(): 5 colors, 2 prompts
@Test func noAccountSeedsAtOnce() throws                            // start(accountAvailable: false): 5 colors
@Test func theTimeoutSeeds() async throws                           // timeout 10 ms, sleep 200 ms: 5 colors
@Test func theOldStoreIsImportedBeforeSeeding() throws              // the location's Legacy.store holds 5 keyless defaults and a highlight: after prepare 5 colors (not 10), each with a key, 1 highlight
@Test func aLaterImportMergesADuplicateDefault() throws             // prepared; insert a second "yellow"; importFinished(): 5 colors
@Test func everyImportRefreshes() throws                            // two importFinished() calls after preparing: refresh == 3
```

- [x] **Step 2: Run to verify failure**, **Step 3: Implement**, **Step 4: Run the whole suite**.
- [x] **Step 5: Wire the app** as in the Interfaces block. Launch the Debug app with `-storeName Fresh`: within 15 seconds the highlight menu shows the five colors once and Settings › Prompts lists each built-in once; the log shows the import and the prepare. Delete `Fresh.store*` afterwards.
- [x] **Step 6: Commit** — `feat: seeding waits for the first import; every import merges duplicates and reloads the models`.

---

### Task 8: The models survive changes made elsewhere

**Files:**
- Modify: `Sources/ScriptureUI/MarkupModel.swift`, `Sources/ScriptureUI/NotesBrowserModel.swift`, `Sources/ScriptureUI/AssistantModel.swift`
- Test: `Tests/ScriptureUITests/MarkupModelTests.swift`, `NotesBrowserModelTests.swift`, `AssistantModelTests.swift`

**Interfaces:**
- Produces on `MarkupModel`: `public static let emptyNoteSweepAge: TimeInterval = 86_400`; the initializer gains `now: @escaping () -> Date = { Date() }` after `defaults`; `reload()` sweeps an empty highlight note only when `now().timeIntervalSince(note.modifiedAt) > emptyNoteSweepAge`, and clears `editingNoteID` when that note no longer exists.
- Rule for all three models: every public method that takes a `UUID` (or a row carrying one) fetches the record through the store by that uuid when it runs and returns without an error message when the record is gone; no method reads a property of a stored `Highlight`, `Note`, `Bookmark`, `ChatThread` or `ChatMessage` object held from before the last reload without re-fetching it. Audit each model's public methods against this and fix what does not hold.
- A highlight whose `colorID` matches no color keeps its row and its text range, drawn as an uncolored highlight (the dotted underline); it is not deleted.

- [x] **Step 1: Write the failing tests.** "Deleted elsewhere" is a delete and save through `ModelContext(container)`, a second context on the same container, which is how an import reaches the store.

```swift
// MarkupModelTests
@Test func anEmptyNoteYoungerThanADayIsNotSwept() throws    // an empty highlight note with modifiedAt 2 hours before `now`: after reload() it still exists
@Test func anEmptyNoteOlderThanADayIsSwept() throws         // modifiedAt 25 hours before: gone after reload()
@Test func aNoteDeletedElsewhereWhileOpenClosesTheEditor() throws  // beginEditing(noteID:), delete the note elsewhere, reload(): editingNoteID == nil, no row for it, lastError == nil
@Test func actingOnARowDeletedElsewhereDoesNothing() throws // delete a highlight elsewhere, then, before any reload, call the model's recolor, delete and add-note entry points with its uuid: no trap, lastError == nil, and after reload() the row is gone
@Test func aHighlightWhoseColorIsMissingStillShows() throws // a highlight whose colorID matches no color: items contains it with no color, and store.allHighlights().count == 1 after reload()

// NotesBrowserModelTests
@Test func aRowDeletedElsewhereDisappearsAndItsActionsDoNothing() throws

// AssistantModelTests
@Test func addingAReplyAsANoteAfterItsThreadWasDeletedElsewhereDoesNothing() async throws
```

- [x] **Step 2: Run to verify failure**, **Step 3: Implement** (the sweep age, the editor check, the audit), **Step 4: Run the whole suite**.
- [x] **Step 5: Commit** — `fix: an empty note is swept only after a day; rows deleted elsewhere are handled, not trapped on`.

---

### Task 9: Preferences and the reading position travel

**Files:**
- Create: `Sources/ScriptureUI/PreferenceSync.swift`, `Tests/ScriptureUITests/PreferenceSyncTests.swift`, `Tests/ScriptureUITests/FakeKeyValueCloud.swift`
- Modify: `Sources/ScriptureUI/NavigationModel.swift`, `Tests/ScriptureUITests/NavigationModelTests.swift`, `Apps/Mac/ReadingThroughScripture/AppSync.swift`, `ReadingThroughScriptureApp.swift`

**Interfaces:**
- Produces: `public protocol KeyValueCloud: AnyObject { func object(forKey key: String) -> Any?; func set(_ value: Any?, forKey key: String) (nil removes); @discardableResult func synchronize() -> Bool; var onExternalChange: (([String]) -> Void)? { get set } }`; `public final class UbiquitousKeyValueCloud: KeyValueCloud` over `NSUbiquitousKeyValueStore.default`, forwarding the changed keys of `didChangeExternallyNotification` for the server-change, initial-sync and account-change reasons and ignoring the quota reason.
- Produces: `public enum SyncedPreferences { public static let positionKey = "readingPosition"; public static let keys: [String] }` with exactly the ten keys of Ruling 9, built from the existing constants (`ReaderSettings.defaultTranslationKey`, `MarkupModel.showNotelessHighlightsKey`, `NoteEditingKeys.settingKey`, the five `AssistantSettings` keys) plus `readingPosition` and `readingPosition.translationID`.
- Produces: `@MainActor public final class PreferenceSync { public init(defaults: UserDefaults, cloud: any KeyValueCloud, keys: [String] = SyncedPreferences.keys, center: NotificationCenter = .default); public var onExternalChange: (([String]) -> Void)?; public func start(); public func pushPending() }`.
- Rules: `start()` calls `cloud.synchronize()`; for each key, a cloud value is written into defaults, and a key only defaults has is written to the cloud; then it listens. A local change (found by comparing the watched keys on `UserDefaults.didChangeNotification`, because `readingPosition.translationID` contains a dot and cannot be key-value observed) is marked pending and pushed by `pushPending()`, which a 2-second timer after the last change calls; a local removal removes the cloud value. An external change is written into defaults (or removed), recorded as known so it is not pushed back, and reported through `onExternalChange`.
- Produces on `NavigationModel`: `public var isAppActive = true`; `public private(set) var hasMovedThisSession = false` (set by every navigation the reader makes and by a change of the first visible verse after a chapter's first report; not by restoring the stored position at launch or by adopting); `public func adoptStoredPosition()`: reads the position store and, when `!isAppActive || !hasMovedThisSession` and the stored chapter exists in the current translation and differs from what is shown (chapter or verse), goes to it through the history as a navigation does.
- App: `AppSync` creates the `PreferenceSync` (with `UbiquitousKeyValueCloud`) only when `sync != nil`, and `ReadingThroughScriptureApp.init` calls `appSync.startPreferences()` before it builds the `NavigationModel`, so a position already in the local key-value cache is the one the app opens at. `onExternalChange`: keys containing `readingPosition` → `model.adoptStoredPosition()`; any other → `markupModel.reload()`. `didResignActive` → `model.isAppActive = false`, `pushPending()`; `didBecomeActive` → `isAppActive = true`; `willTerminate` → `pushPending()`.

- [x] **Step 1: Write the failing tests** (`FakeKeyValueCloud`: a dictionary, a `sets` counter, `simulateExternal(_ changes: [String: Any?])` that applies them and calls `onExternalChange`).

```swift
// PreferenceSyncTests (@MainActor @Suite, a fresh UserDefaults suite per test)
@Test func theSyncedKeysAreExactlyThese() {
    #expect(SyncedPreferences.keys.sorted() == ["anthropicModel", "assistantProvider", "compatibleBaseURL", "compatibleModel",
        "defaultTranslationID", "finishEditingWithReturn", "openAIModel", "readingPosition", "readingPosition.translationID", "showNotelessHighlights"])
}
@Test func aNewDeviceTakesTheCloudValues()            // cloud defaultTranslationID "KJV", defaults "ESV": after start() defaults reads "KJV"
@Test func aFirstRunPushesLocalValuesUp()             // cloud empty, defaults showNotelessHighlights false: after start() the cloud holds false
@Test func aLocalChangeIsPushed()                     // after start(), set anthropicModel "x"; pushPending(); cloud holds "x"
@Test func anExternalChangeLandsAndIsNotEchoed()      // simulateExternal(["defaultTranslationID": "WEB"]): defaults "WEB"; pushPending(); cloud.sets unchanged
@Test func aKeyOutsideTheListNeverTravels()           // readerFontSize set locally and present in the cloud: neither side copies it
@Test func aLocalRemovalRemovesTheCloudValue()
@Test func anExternalRemovalRemovesTheLocalValue()
@Test func externalChangesNameTheirKeys()             // onExternalChange receives ["readingPosition"]

// NavigationModelTests
@Test func aStoredPositionArrivingBeforeTheReaderMovesIsAdopted() throws   // launch at MAT 5; save ROM 8:1 into the position store; adoptStoredPosition(): location ROM 8
@Test func aStoredPositionArrivingWhileReadingIsIgnored() throws           // after goToNextChapter(): adoptStoredPosition() leaves the location alone
@Test func aStoredPositionArrivingWhileInactiveIsAdopted() throws          // after navigating, isAppActive = false: adopted
@Test func adoptingKeepsBackWorking() throws                               // canGoBack true; goBack() returns to the chapter left
@Test func aStoredPositionInAChapterThisTranslationLacksIsIgnored() throws
```

- [x] **Step 2: Run to verify failure**, **Step 3: Implement**, **Step 4: Run the whole suite**.
- [x] **Step 5: Wire the app** and launch the Debug build twice: the second launch opens where the first was left (the existing behaviour, now through the mirror), and the `sync` log shows the key-value store synchronized. If finding F3 was "not available", `PreferenceSync` still mirrors nothing harmful: confirm the app behaves as before and record it.
- [x] **Step 6: Commit** — `feat: reading position and a named set of preferences travel through the iCloud key-value store`.

---

### Task 10: API keys in the iCloud Keychain

**Files:**
- Modify: `Sources/ScriptureLLM/SecretStore.swift`, `Tests/ScriptureLLMTests/FakeKeychain.swift`, `Tests/ScriptureLLMTests/SecretStoreTests.swift`, `Apps/Mac/ReadingThroughScripture/AppSync.swift`, `Sources/ScriptureUI/AssistantSettingsView.swift` (footer copy)

**Interfaces:**
- `KeychainStore` behaviour (signatures unchanged): `secret(for:)` reads the data-protection keychain first (`kSecUseDataProtectionKeychain: true`, `kSecAttrSynchronizableAny`), then the file-based keychain (neither flag); `errSecMissingEntitlement` from the first is "not found there". `setSecret` updates in place where the item is; a new key is added to the data-protection keychain with `kSecAttrSynchronizable: true`, and only if that returns `errSecMissingEntitlement` or `errSecParam` to the file-based keychain as now. Removing deletes from both.
- Produces: `@discardableResult public func upgradeToSynchronizable(_ ids: [LLMProviderID]) -> [LLMProviderID]`: for each id with a file-based item and no data-protection item, add the synchronizable copy; only when that add succeeds, delete the file-based item. Returns the ids moved. Any failure leaves the old item.
- `FakeKeychain`: items keyed by account and by which keychain (the query's `kSecUseDataProtectionKeychain` or a true `kSecAttrSynchronizable` selects the data-protection one); `var dataProtectionAvailable = true` (false makes every data-protection call return `errSecMissingEntitlement`); `func seedFileBased(_ value: String, account: String)`; `failNextWrite` stays.
- App: `AppSync.start()` calls `upgradeToSynchronizable` for the three provider ids in a detached task, then refreshes the assistant settings model. Footer under the Claude section: `Keys are stored in your Keychain and travel through iCloud Keychain.`

- [x] **Step 1: Write the failing tests**

```swift
@Test func aKeyFromTheOldKeychainIsStillRead()                 // seedFileBased("sk-old", …): secret(for: .anthropic) == "sk-old"
@Test func upgradingMovesTheKeyAndDeletesTheOldItem()          // returns [.anthropic]; the data-protection item holds "sk-old"; the file-based item is gone; a second call returns []
@Test func withoutTheEntitlementNothingMovesAndTheKeyStillReads() // dataProtectionAvailable = false: returns [], secret still "sk-old"
@Test func aFailedCopyLeavesTheOldItem()                       // failNextWrite = errSecIO: returns [], the file-based item remains
@Test func aNewKeyGoesToTheSyncedKeychain()                    // setSecret("sk-new"): only the data-protection keychain holds it
@Test func removingAKeyRemovesItFromBoth()
```

- [x] **Step 2: Run to verify failure**, **Step 3: Implement**, **Step 4: Run the whole suite** (the existing `SecretStoreTests` still pass).
- [x] **Step 5: Check in the Debug app:** save a throwaway key in Settings › Assistant, quit, relaunch: it reads back, and `security find-generic-password -s com.matthewfurr.ReadingThroughScripture -a llm.anthropic` (the file-based keychain) does not find it. Remove the key.
- [x] **Step 6: Commit** — `feat: API keys are stored as synchronizable items; a key from the old keychain moves over`.

---

### Task 11: Settings: iCloud and Backups; the toolbar notice

Load `/impeccable-swift` first. Design brief: Settings › General, grouped `Form`, two sections after "Notes Column". Nothing here is a card; rows are form rows.

**Files:**
- Create: `Sources/ScriptureUI/BackupsModel.swift`, `Sources/ScriptureUI/SyncSettingsSections.swift`, `Tests/ScriptureUITests/BackupsModelTests.swift`
- Modify: `Sources/ScriptureUI/GeneralSettingsView.swift`, `Apps/Mac/ReadingThroughScripture/SettingsView.swift`, `MainWindowView.swift`, `AppSync.swift`, `ReadingThroughScriptureApp.swift`, `DESIGN.md` (symbol inventory: `icloud`, `icloud.slash`, `exclamationmark.icloud`; a line under Components for the two sections and the notice)

**Interfaces:**
- Produces: `@MainActor @Observable public final class BackupsModel { public init(location: StoreLocation, container: ModelContainer, onRestore: @escaping @MainActor () -> Void); public private(set) var lastBackup: Date? (the newest backup file's modification date); public private(set) var resultText: String?; public func refresh(); public func restore(from url: URL) (`StoreCopy.copyMissing`, then `onRestore`, then `resultText`; a failure sets `resultText` to "That backup could not be read."); public var backupsDirectory: URL; public static func sentence(for summary: RestoreSummary) -> String }`.
- `sentence(for:)`: `Nothing was missing.` for a total of zero; otherwise `Restored ` + the non-zero counts in the order highlights, notes, bookmarks, colors, conversations, prompts, each as `1 note` / `3 notes` (`highlight`, `note`, `bookmark`, `color`, `conversation`, `prompt`), joined with `, ` and a final ` and `, + `.`
- `GeneralSettingsView.init(translations:sync:backups:)` with `sync: SyncStatusModel? = nil`, `backups: BackupsModel? = nil`; the sections show when the models are given.
- **iCloud section** (header `iCloud`): one row, `Label(statusText, systemImage: symbolName)` in `.body`, text `ink.primary`, symbol `ink.secondary`, inside a `TimelineView(.periodic(from: .now, by: 60))` so the relative time stays true; when the state is `.noAccount`, a trailing `.bordered` button `Open iCloud Settings` (opens `x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings`; check that it lands on the Apple Account pane on macOS 26 and, if it does not, open `x-apple.systempreferences:` instead). Footer in `ink.secondary`: `Highlights, notes, bookmarks, conversations, prompts and colors sync through your private iCloud. Text size and appearance stay with each device.`
- **Backups section** (header `Backups`): `LabeledContent("Last backup")` with the date as `.dateTime.weekday(.wide).hour().minute()` or `None yet`; a row of two `.bordered` buttons, `Show in Finder` (`NSWorkspace.shared.activateFileViewerSelecting` on the newest backup, or opens the directory) and `Restore…` (an `NSOpenPanel` starting in the backups directory, one file, the result passed to `restore(from:)`); under them `resultText` in `.callout` `ink.secondary` when set, announced to VoiceOver. Footer: `A copy of your notes is kept on this Mac each day, for seven days. Restore brings back anything that is missing and changes nothing else.`
- **`SyncAttentionButton`** (`SyncSettingsSections.swift`): a toolbar button shown in the main window's primary-action group only while `status.needsAttention`; `Image(systemName: "exclamationmark.icloud")` in `ink.secondary`, label `iCloud`, `.help(status.attentionHelp)`; its action sets the Settings tab to `general` and opens Settings.

- [x] **Step 1: Write the failing tests** (`@MainActor @Suite struct BackupsModelTests`)

```swift
@Test func theSentenceCountsWhatCameBack() {
    var summary = RestoreSummary()
    #expect(BackupsModel.sentence(for: summary) == "Nothing was missing.")
    summary.notes = 1
    #expect(BackupsModel.sentence(for: summary) == "Restored 1 note.")
    summary.highlights = 2; summary.bookmarks = 1
    #expect(BackupsModel.sentence(for: summary) == "Restored 2 highlights, 1 note and 1 bookmark.")
}
@Test func theLastBackupIsTheNewestFile() throws            // two backups on consecutive days: lastBackup is the later file's date; none: nil
@Test func restoringBringsBackADeletedNoteAndSaysSo() throws // back up, delete the note through the store, restore(from:): the note exists again, onRestore ran once, resultText == "Restored 1 note."
@Test func anUnreadableFileSaysSo() throws                  // a text file: resultText == "That backup could not be read."
```

- [x] **Step 2: Run to verify failure**, **Step 3: Implement the model**, **Step 4: Run the whole suite**.
- [x] **Step 5: Build the sections and the button, wire them** (`AppSync` owns the `BackupsModel`, with `refreshAll` as `onRestore`; `backUpIfNeeded` calls `backups.refresh()`).
- [x] **Step 6: Verify in the running Debug app.** Settings › General in light and dark: the iCloud row reads `Synced just now` after a bookmark is toggled, the Backups row shows today, `Show in Finder` selects the file, `Restore…` on today's backup says `Nothing was missing.` Delete a note, restore the same backup: `Restored 1 note.` and the note is back in the column. Screenshots to the scratchpad. The toolbar shows no iCloud button.
- [x] **Step 7: Critique** (`/impeccable-swift critique` on the two sections): no inline colors, no fixed-point fonts, every button labelled, the status readable by VoiceOver as one sentence. Fix what it finds.
- [x] **Step 8: Commit** — `feat: Settings shows the iCloud status and the backups, with Restore; a quiet toolbar notice after a day of failed sync`.

---

### Task 12: The sync probe and the two-store rehearsal

This task proves the whole path in the Debug build's own container, with a copy of Matt's notes as the test data and a second store standing in for a second device. It changes nothing of Matt's: his old store is copied, not opened.

**Files:**
- Create: `Apps/Mac/ReadingThroughScripture/SyncProbe.swift` (`#if DEBUG`)
- Modify: `Apps/Mac/ReadingThroughScripture/AppSync.swift`, this plan (the rehearsal results)

**Interfaces:**
- Produces: `enum SyncProbe { @MainActor static func runIfAsked(store: MarkupStore) }`, called once when the coordinator has prepared. It reads the string argument `-syncProbe` and logs `probe done: <argument>` to the `sync` category. Forms: `bookmark:GEN.1.1` (toggles that bookmark); `note:GEN.1:<text>` (sets the body of the first chapter note on Genesis 1 in ESV, creating it if there is none); `deleteNote:GEN.1` (deletes that note). Nothing in a Release build reads the argument.
- Launching: `open -n Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app --args -storeName Second -syncProbe bookmark:GEN.1.1`. Counting: `sqlite3 "<store path>" "select count(*) from ZHIGHLIGHT"` (also `ZNOTE`, `ZBOOKMARK`, `ZHIGHLIGHTCOLOR`, `ZPROMPTTEMPLATE`, `ZCHATTHREAD`, `ZCHATMESSAGE`), read-only. Waiting: a finished `exporting` or `importing` event in the `sync` log after the change.

- [x] **Step 1: Write the probe.** Build. Launch with `-storeName ProbeCheck -syncProbe bookmark:GEN.1.1`; the log shows `probe done`; `ZBOOKMARK` in `ProbeCheck.store` counts 1. Quit; delete `ProbeCheck.store*`.
- [x] **Step 2: Start clean.** Quit the Debug app. Delete the Debug store directory's `Markup.store*`, `Second.store*`, `Markup.legacy-imported` and `Backups*`. The Debug container's cloud data still holds what Tasks 3 to 11 put there (a few bookmarks and notes): launch once with `-storeName Baseline`, wait for the imports, record its seven counts as the baseline, quit, and delete `Baseline.store*`. Every "equal counts" check below means equal after adding the baseline.
- [x] **Step 3: Rehearse the import of the old store.** Copy `~/Library/Application Support/ReadingThroughScripture/Markup.store`, `-wal` and `-shm` (those that exist) into the Debug store directory as `Legacy.store`, `Legacy.store-wal`, `Legacy.store-shm`. Launch the Debug app. Expected: the notes appear; the seven table counts in `Markup.store` equal those in `Legacy.store` except that colors and prompts are never more than the legacy counts; the marker file exists; the log shows a finished export with no failure. Record the counts.
- [x] **Step 4: A second device.** With the first instance quit, launch with `-storeName Second`. Expected within a few minutes (watch for finished imports): `Second.store` reaches the same seven counts; five default colors, not ten; each built-in prompt once. Record how long it took.
- [x] **Step 5: A change crosses.** Quit both. Launch `Second` with `-syncProbe bookmark:GEN.1.1`, wait for the export, quit. Launch the main store, wait for an import: `ZBOOKMARK` in `Markup.store` is one higher, and the reader shows the bookmark on Genesis 1:1.
- [x] **Step 6: A delete crosses.** Launch the main store with `-syncProbe note:GEN.1:rehearsal`, wait for the export, quit. Launch `Second`, wait for the import, confirm the note; relaunch `Second` with `-syncProbe deleteNote:GEN.1`, wait, quit. Launch the main store: the note is gone after the import.
- [x] **Step 7: A conflict.** With the note recreated and in both stores, launch both instances at once: the main store with `-syncProbe note:GEN.1:from-main` and `Second` with `-syncProbe note:GEN.1:from-second`. Wait for both to export and import, quit both, launch each once more and wait. Expected: neither crashes; each store has exactly one chapter note on Genesis 1; both hold the same body (either one).
- [x] **Step 8: Restore from iCloud into nothing.** Delete `Second.store*`. Launch `Second`: it fills again to the main store's counts.
- [x] **Step 9: A backup restores.** In the main store, back up (launch), delete two notes in the app, then Settings › General › Restore… on today's backup: `Restored 2 notes.`; after an export, `Second` shows them again on its next launch.
- [x] **Step 10: Record every result** under "Rehearsal results" at the end of this plan, with the counts and times. Remove the bookmark and the rehearsal note. Leave the Debug stores in place for Task 14.
- [x] **Step 11: Commit** — `test: a sync probe for Debug builds; the two-store rehearsal recorded`.

---

### Task 13: Going live on Matt's notes

**Stop before this task and ask Matt for a go-ahead.** It is the first time a Release build runs, and the first time his notes go to iCloud.

**Files:**
- Modify: this plan (the go-live results), `README.md`

- [x] **Step 1: Matt quits the app he has been reading in** (the old ad-hoc build). From here on that old build must not be used: it writes to the old local store, which no longer syncs and is no longer read. After installing (Step 3), move the old ad-hoc copies to the Trash, because they share the bundle ID `com.matthewfurr.ReadingThroughScripture` and would write to the old store: `/Users/matt/Code/reading-through-scripture/Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app`, and any other copy with that bundle ID that `mdfind "kMDItemCFBundleIdentifier == 'com.matthewfurr.ReadingThroughScripture'"` lists outside `/Applications`.
- [x] **Step 2: Matt chooses the environment (Ruling 15).** **Development** (the current setting): skip to Step 3; there is no deploy step. **Production**: first push the schema to the real container's Development environment. Build the Release configuration with Development pinned: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Release -derivedDataPath Build/DerivedData -allowProvisioningUpdates -allowProvisioningDeviceRegistration CLOUDKIT_ENVIRONMENT=Development build`. Launch that build once with `-storeName Schema -initializeCloudKitSchema YES` (the app refuses the schema step on the main store and logs `schema initialization refused: use -storeName`), wait for `schema initialized` in the `sync` log, quit, then delete only `Schema.store`, `Schema.store-wal`, `Schema.store-shm`, `.Schema_SUPPORT/`, `Schema_ckAssets/` and `Backups-Schema/`. **Never delete the directory `Sync/iCloud.com.matthewfurr.ReadingThroughScripture-Development/` itself or anything else in it: it may hold Matt's live `Markup.store` and its `Backups/`.** Then Matt: CloudKit Console › the `iCloud.com.matthewfurr.ReadingThroughScripture` container › Deploy Schema Changes. Then set `CLOUDKIT_ENVIRONMENT = Production` for the Release configuration, so Step 3 builds and installs a Production build.
- [x] **Step 3: Install.** `Scripts/install-app.sh`. Record the old store's seven table counts first (read-only `sqlite3`).
- [x] **Step 4: First launch of `/Applications/ReadingThroughScripture.app`.** Expected: Matt's notes, highlights, colors, prompts and conversations are all there; the seven counts in the new store equal the old store's (colors and prompts never more); `~/Library/Application Support/ReadingThroughScripture/Markup.store` has the same modification date as before; Settings › General reads `Synced just now` within a few minutes; a backup for today exists. If the keychain asks to use an item saved by the old build, Matt chooses Always Allow; his API keys read back in Settings › Assistant.
- [x] **Step 5: Prove the notes are in iCloud.** Quit. `open -n /Applications/ReadingThroughScripture.app --args -storeName Check`; when the imports finish, `Check.store` has the same seven counts. Quit, delete `Check.store*` and `Backups-Check`.
- [x] **Step 6: Record the go-live results** at the end of this plan. README, Running the app: the installed app, where its store and backups are, and "Do not copy a store file between Macs; let iCloud bring the notes."
- [x] **Step 7: Commit** — `docs: go-live recorded; where the synced store and its backups live`.

---

### Task 14: Documentation, verification and the whole-branch review

**Files:**
- Modify: `README.md` (reviewed whole), `DESIGN.md`, `docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md` (tick Verification › Milestone 7), this plan (checkboxes, results), `Packages/ScriptureKit/Sources/ScriptureUI/ReadingPositionStore.swift` and `ReaderSettings.swift` (the two doc comments that still promise a SwiftData record)

- [x] **Step 1: README pass.** Prerequisites; Running the app (two builds, the install script, the provisioning flags); a new "Sync and backups" section (what syncs, what travels as a preference, what stays per device, what signing out of iCloud does, where the stores and backups are, how Restore works, how a second device joins); Settings (the two new sections, the full list of synced keys); Running the tests; Layout. "Current plan" already points here.
- [x] **Step 2: Run the Milestone 7 verification** below, in the Debug build for everything except the lines marked Release; tick each line here and in the spec, with the result under it. (The two Release lines wait for Task 13.)
- [ ] **Step 3: Whole-branch review** (whole-branch review: run by the controller) with the superpowers code-review flow, against the Review Focus list and the Global Constraints (above all: nothing opens the old store for writing; no test touches real iCloud, the real Keychain or Application Support). Then the full suite and both configurations' builds one last time. Suite and builds done in Task 14: 517 tests in 65 suites pass; Debug and Release `** BUILD SUCCEEDED **` (Release not launched).
- [x] **Step 4: Commit** — `docs: README, DESIGN and the spec for milestone 7; verification recorded`.

---

## Milestone 7 verification

These steps are also in the spec's Verification section. Tick them in both places when run.

- [x] **Signing.** `codesign -d --entitlements -` on the Debug and Release apps shows the team, each build's own container, the key-value identifier and the keychain group; both have an embedded provisioning profile.
  - Task 14, 15:47 and 15:55 (both built in this task; Release built only, never launched). Debug: `SFQ7B3J933.com.matthewfurr.ReadingThroughScripture.dev`, container `iCloud.com.matthewfurr.ReadingThroughScripture.dev`, `Development`, kvstore and keychain group `SFQ7B3J933.com.matthewfurr.ReadingThroughScripture.dev`, `TeamIdentifier=SFQ7B3J933`. Release: `SFQ7B3J933.com.matthewfurr.ReadingThroughScripture`, container `iCloud.com.matthewfurr.ReadingThroughScripture`, `Development` (Ruling 15), kvstore and keychain group `SFQ7B3J933.com.matthewfurr.ReadingThroughScripture`. Both carry `aps-environment development` and `Contents/embedded.provisionprofile`.
- [x] **Two worlds.** A Debug launch logs a store under `Sync/iCloud.com.matthewfurr.ReadingThroughScripture.dev-Development/`; the old `Markup.store` and the Release store's files have unchanged modification dates after a Debug session.
  - Task 14: every launch logged `store …/Sync/iCloud.com.matthewfurr.ReadingThroughScripture.dev-Development/Markup.store, sync iCloud.com.matthewfurr.ReadingThroughScripture.dev Development`. After four Debug sessions the old `Markup.store`, `-wal` and `-shm` still read 1793753629, 1793754389, 1793754085 (sizes 159744, 1289592, 32768), the same as in Task 12. No Release store exists yet (`Sync/` holds only the `.dev` directory), so there was nothing of the Release build's to change.
- [x] **The old notes come across (Release, Task 13).** After the first Release launch the seven table counts match the old store's, the old file is untouched, and a `-storeName Check` store fills from iCloud to the same counts.
  - Task 13, 16:32 to 16:35: old store 6/4/0/5/14/7/17; the new Release store after the first launch 6/4/0/5/14/7/17 (`old store imported: 36 records`, then `prepared` 8.4 s after the launch command, exports with `failure none`); `Check.store` filled from iCloud to 6/4/0/5/14/7/17 in 1.8 s. `Markup.store` (159744, 1793753629) and `Markup.store-wal` (1289592, 1793754389) unchanged through the whole task; `Markup.store-shm` (32768) was touched once by the task's own read-only `sqlite3` count (mtime 1794259823, before the install), never by the app. See Go-live results.
- [x] **A second device (stand-in).** A `Second` store starts empty and fills; a bookmark made in one store appears in the other; a note deleted in one is gone from the other; a note edited in both at once ends as one note with one body in both; default colors and built-in prompts appear once.
  - Task 12's recorded results, not re-run: steps 4 to 8 all pass (fill in 1.7 s, the bookmark crossed, the delete crossed, the conflict ended as one note with body `from-main` in both, five defaults and fourteen prompts once each). See Rehearsal results.
- [x] **No account.** Unit-tested (`noAccountSaysWhereTheNotesAre`, `noAccountSeedsAtOnce`). Not run on Matt's Mac: signing out would empty the synced store until he signs back in.
  - Task 14: both tests pass in the full suite (517). Not run live, as the line says.
- [x] **Backups.** After a launch a file for today is in `Backups/`; with nine days of files only seven remain (unit-tested); Restore on a backup taken before a note was deleted brings the note back and says how many; Show in Finder selects the newest.
  - Task 14, live in the Debug build at 15:49 to 15:51: `Backups/2026-11-09.store` (15:23, today) is present and Settings › General › Last backup reads `Monday 3:23 PM`; `onlyTheNewestSevenAreKept` passes. The Genesis 1:1 note (`Some note here.`) deleted from the notes column with Delete: `ZNOTE` 4 → 3, its highlight kept. Restore… opened the panel in `Backups/`; choosing `2026-11-09.store` showed `Restored 1 note.` and `ZNOTE` went back to 4 (counts 6/4/0/7/14/7/17, as before). Show in Finder: Finder's selection was `…/Backups/2026-11-09.store`. Screenshot: `settings-backups.png`, `restore-result.png` in the Task 14 scratchpad.
- [x] **Status line.** Settings › General reads `Synced just now` after a change, then counts up by the minute; the toolbar shows no iCloud button.
  - Task 14, Debug build: after the note delete (export finished 15:50:57, last at 15:51:12) the row read `Synced just now`; then `Synced 1 minute ago` at 15:53:07 and `Synced 2 minutes ago` at 15:54:05 (the row redraws on a one-minute timeline, so it can lag a change of minute by up to a minute). A normal launch's toolbar holds Home, Back, Forward, the translation menu, Go to Reference, Notes Column, Assistant and Notes Browser, and no iCloud button (`toolbar-no-notice.png`).
  - The notice itself, never shown before, forced with the new Debug-only `-forceSyncAttention YES`: the `exclamationmark.icloud` button appears at the head of the primary-action group (its own glass capsule, before the translation menu's), icon only like its neighbours, in the secondary ink, grey and not red or green, in light and dark; hovering shows the help tag `Your notes have not synced since Sunday, Nov 8. Open Settings.`; a click with the Settings tab set to Reading opened Settings on General (`settingsTab` became `general`, window title General). No change to `SyncSettingsSections.swift` was needed. Screenshots: `toolbar-light.png`, `toolbar-help-light.png`, `toolbar-dark.png`, `settings-general-from-notice.png` in `/private/tmp/claude-501/-Users-matt--claude-spares-spare-4pD2AM/e7ca742e-8f34-4e90-b6e8-8c824ecd82fa/scratchpad/`.
- [x] **Preferences.** Unit-tested (`PreferenceSyncTests`, the five `NavigationModel` tests). Across devices: deferred.
  - Task 14: `PreferenceSyncTests` and the `NavigationModel` position tests (now six, with `aStoredPositionBringsItsTranslation`) pass. Across devices: deferred, as the line says.
- [x] **API keys.** A key saved in the signed build is in the data-protection keychain, not the login keychain; a key the old build saved is moved on first launch (Release, Task 13).
  - First half done in the Debug build in Task 10 step 5 (a throwaway key read back after a relaunch and was not in the file-based keychain). The move, Task 13: the first Release launch showed the keychain prompt for the old build's item; Matt answered it, and 8 s after the launch the log read `keys moved to iCloud Keychain: anthropic`. Afterwards `security find-generic-password -s com.matthewfurr.ReadingThroughScripture` finds nothing in the login keychain, and Settings › Assistant shows the Anthropic key as `Saved`. No key value was read or printed.
- [ ] **Deferred to a real second device (Matt's other Mac, then the iPhone in milestone 8).** A highlight made on one device appears on the other within a minute while both run; the reading position follows; a change of default translation arrives.

## Findings (Task 3)

| | Question | Result |
| --- | --- | --- |
| F1 | Can a development-signed Release build carry `icloud-container-environment = Production`? | Yes. The Release build succeeded; its profile ("Mac Team Provisioning Profile: com.matthewfurr.ReadingThroughScripture") allows `Production` and `Development` for `iCloud.com.matthewfurr.ReadingThroughScripture`, and `codesign -d --entitlements -` shows `icloud-container-environment = Production`. Release keeps `CLOUDKIT_ENVIRONMENT = Production`. Not launched. Superseded: Release uses Development anyway (Ruling 15). |
| F2 | Does an unsandboxed, development-signed build set up CloudKit and finish an export? | Yes. The first launch, two minutes after the container was created, failed setup with CKError 5 (bad container; cloudd's `ckAppInit` returned CKInternalError 1014): the new container had not reached CloudKit yet. The next launch, three minutes later: `setup … ended 18:59:10, failure none`, then an import and exports with no failure; adding a highlight color in Settings › Markup was followed by `exporting started 18:59:39, ended 18:59:40, failure none`. |
| F3 | Does `NSUbiquitousKeyValueStore.synchronize()` succeed in that build? | Yes: `key-value store synchronize true` on both launches. |
| F4 | Did automatic signing create the two iCloud containers, or did Matt? | Automatic signing. Neither build reported a missing container; `-allowProvisioningUpdates` made Xcode-managed profiles at 18:53:54Z (`.dev`) and 18:56:54Z (real), each listing its container. A brand-new container takes a few minutes before CloudKit accepts it (see F2). |
| F5 | Signed-out behaviour | Not run. Apple's engineers: the synced store is emptied on sign-out and re-downloaded on sign-in; unsynced changes are lost (forums threads 764080, 766668). |
| F6 | Does a synchronizable data-protection keychain add succeed in that build? | Yes: `keychain probe add 0, delete 0` (`errSecSuccess` for both) on both launches. The probe code is removed. |

## Rehearsal results (Task 12)

Run 2026-11-09, 15:16 to 15:33, Debug build only, container `iCloud.com.matthewfurr.ReadingThroughScripture.dev` (Development). Matt's `Markup.store`, `-wal` and `-shm` were copied with `cp` (sizes 159744, 1289592, 32768, equal after the copy) and never opened; their modification times were the same before and after the whole task (1793753629, 1793754389, 1793754085, i.e. Nov 3 19:53:49, 20:06:29, 20:01:25).

| Store | Highlights | Notes | Bookmarks | Colors | Prompts | Threads | Messages |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Baseline (cloud before the rehearsal) | 0 | 0 | 0 | 6 | 14 | 0 | 0 |
| `Legacy.store` (copy of Matt's store) | 6 | 4 | 0 | 5 | 14 | 7 | 17 |
| `Markup.store` after the import | 6 | 4 | 0 | 7 | 14 | 7 | 17 |
| `Second.store` after its fill | 6 | 4 | 0 | 7 | 14 | 7 | 17 |
| Both stores at the end (bookmark and rehearsal note removed) | 6 | 4 | 0 | 7 | 14 | 7 | 17 |

Baseline colors: the five defaults (with keys) and a `New Color` an earlier task made. Legacy colors: Yellow, Green, Blue, Rose, and Matt's own `Gray` (not a default; one highlight uses it). Matt had no Orange.

Fill times (launch to the finished import that brought the records): Baseline 2.3 s; `Markup.store` with the old store's import 2.7 s to `old store imported: 22 records`, 5.4 s to the finished export; `Second` 1.7 s; `Second` again from nothing (step 8) 1.8 s.

| Step | Result | Evidence |
| --- | --- | --- |
| 1 Probe | Pass | `probe done: bookmark:GEN.1.1` 2.0 s after the launch command (15:16:37 to 15:16:39.937; 1.8 s after the app's first log line); `ZBOOKMARK` in `ProbeCheck.store` = 1 (GEN 1:1). That export reached the cloud, so `ProbeCheck` was launched once more with the same probe to take the bookmark out again (`ZBOOKMARK` 0, export finished) before its files were deleted. |
| 2 Start clean | Pass | Deleted `Markup.store*`, `.Markup_SUPPORT`, `Markup_ckAssets`, `Backups/` (no `Second` or marker existed). Baseline above; `prepared` 2.3 s after launch. |
| 3 Old store import | Pass, with one count above the brief's bound | `old store imported: 22 records`, `prepared`, `exporting … ended 20:21:52 …, failure none`; `Markup.legacy-imported` exists; the Notes window lists Matt's notes (`Notes – 13 items`). Highlights, notes, bookmarks, threads and messages equal Legacy + Baseline. Prompts 14 = max(14, 14). Colors 7 > max(5, 6): the five defaults merged to one each (keys yellow, green, blue, rose, orange), plus Matt's `Gray` and the Debug cloud's `New Color`, two distinct non-default colors that no merge should join. On the real container (no `New Color`) the expected color count is 6, and Orange (deleted by Matt) comes back as a default only if the real cloud already holds one. |
| 4 Second device | Pass | `Second.store` reached 6/4/0/7/14/7/17 in 1.7 s; 5 default colors with 5 distinct keys; 14 built-in prompts, 14 distinct keys and titles. |
| 5 A change crosses | Pass | `Second` with `bookmark:GEN.1.1`: `probe done`, export finished, `Second` `ZBOOKMARK` 1. Main launch: import finished, `Markup.store` `ZBOOKMARK` 0 → 1 (GEN 1:1); the reader shows the bookmark ribbon on Genesis 1:1. |
| 6 A delete crosses | Pass | Main `note:GEN.1:rehearsal`: `ZNOTE` 4 → 5 (one chapter note), export finished. `Second` imported it (`ZNOTE` 5, body `rehearsal`). `Second` `deleteNote:GEN.1`: `ZNOTE` 5 → 4, export finished. Main launch: `ZNOTE` 4, no chapter note. `ZHIGHLIGHT` unchanged throughout (a chapter note has no anchor). |
| 7 A conflict | Pass | Note recreated in both (body `rehearsal`). Both launched at 15:25:27: `probe done: note:GEN.1:from-second` (28.144) and `from-main` (28.182); both exported with no failure. While both ran, neither imported the other's change (same Mac, so CloudKit sends no push to the device that wrote it). Both quit (by process id), each relaunched: `Second` imported `from-main`; main kept `from-main`. Each store: exactly one chapter note on Genesis 1, body `from-main`, same modification time. No crash, no crash report. |
| 8 Restore from iCloud into nothing | Pass | `Second.store*`, `.Second_SUPPORT`, `Second_ckAssets`, `Backups-Second` deleted; relaunch filled to main's counts (6/5/1/7/14/7/17 at that point) in 1.8 s; 5 defaults. |
| 9 A backup restores | Pass | Today's backup (`Backups/2026-11-09.store`, 15:23) held the 4 old notes. In the Notes window, Mark 1:1 and Mark 1:6 deleted (`ZNOTE` 5 → 3). Settings › General › Restore… on `2026-11-09.store`: `Restored 2 notes.`; `ZNOTE` 3 → 5; export finished 15:30:00 with no failure. `Second` next launch: `ZNOTE` 5 with both Mark notes. (`Second` was not running while the notes were deleted, so this shows the restored records arrive, not that the deletes crossed first.) |
| 10 Clean-up | Pass | Main `bookmark:GEN.1.1` then `deleteNote:GEN.1`, each exported; `Second` relaunched and took both. End: both stores 6/4/0/7/14/7/17. Debug stores left in place, app quit. |
| (a) Schema path | FAILED twice before the `SyncMonitor` change; PASSED once after it | `makeManagedObjectModel` returning nil now logs `schema initialization failed: no managed object model` and throws, so `schema initialized` is never logged. The run with `-storeName Schema -initializeCloudKitSchema YES`: `will initialize cloudkit schema` at 15:31:14.513, then exactly 30 s later `Startup failed: Error Domain=NSCocoaErrorDomain Code=134060 UserInfo={encounteredErrors=<private>}`, `Initialize schema request failed`, and the window says the notes could not be opened. Retried at 15:32:15: the same failure at 15:32:45. No `schema initialized`. The CloudKit setup for that store only finished after the main thread was released (`setup … ended 20:31:45`). Likely cause, not verified: `SyncMonitor` (started before the container) observes `eventChangedNotification` with `queue: .main`, and a post to a queue-bound observer waits for the main thread, which is blocked in `initializeCloudKitSchema()`; the 30 s is the schema request's timeout. Task 13 step 2 uses this path. **Fix round 1: PASS.** `SyncMonitor` now observes with `queue: nil` and hops to the main actor itself. Retried once in the Debug container at 15:42:51: `will initialize cloudkit schema` 15:42:51.597, schema records saved and deleted, `schema initialized` at 15:42:57.692 (6.1 s), then `prepared` and exports with `failure none`. The deadlock reading is confirmed. The `Schema` store and its sidecars were deleted. The schema path works, so Production is now a choice Matt makes at go-live (Ruling 15, Task 13 Step 2): Development has no deploy step but keeps his data in an environment CloudKit Console can reset; Production runs the schema step against the real container's Development environment, deploys it in CloudKit Console, then builds Release with `CLOUDKIT_ENVIRONMENT = Production`. |
| (b) `install-app.sh` | Pass (not run) | Exits 1 with `No built app at …; the installed copy is unchanged.` when the built app is missing, before anything is quit or removed; the quit wait gives up after 30 s with `The installed app did not quit within 30 seconds; the installed copy is unchanged.` and exit 1. `zsh -n` passes. |
| (c) Keychain move | FAILED | A throwaway `llm.openAI` item was seeded under the `.dev` service with `-T` for the Debug app. On launch (`-storeName KeyCheck`, so the main store's first launch stayed for step 3) a macOS dialog appeared: "ReadingThroughScripture wants to access key "com.matthewfurr.ReadingThroughScripture.dev" in your keychain", asking for the login keychain password. Not clicked. The app logged nothing after `key-value store synchronize` (no `setup`, no `prepared`), so the main thread was blocked; `quit` hung, and the process was ended with SIGTERM. No `keys moved` line; the item was still in the login keychain, and was then deleted with `security delete-generic-password` so later launches would not prompt. Settings › Assistant was not checked. Likely cause: an item made by the `security` tool has the partition list `apple-tool:, apple:`, so `-T` alone does not spare a non-Apple app the prompt; an item the old app saved itself carries its team partition and may behave differently. The Release service `com.matthewfurr.ReadingThroughScripture` was never touched. |

## Go-live results (Task 13)

Run 2026-11-09, 16:29 to 16:36, on Matt's go-ahead, environment **Development** (Ruling 15; Step 2 not run, no schema step, no deploy).

| Store | Highlights | Notes | Bookmarks | Colors | Prompts | Threads | Messages |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Old `Markup.store` (before the install) | 6 | 4 | 0 | 5 | 14 | 7 | 17 |
| New `Sync/iCloud.com.matthewfurr.ReadingThroughScripture-Development/Markup.store` after the first launch (and again after the relaunch) | 6 | 4 | 0 | 5 | 14 | 7 | 17 |
| `Check.store` filled from iCloud | 6 | 4 | 0 | 5 | 14 | 7 | 17 |

- **Old store files.** Before: `Markup.store` 159744 bytes, mtime 1793753629 (Nov 3 19:53:49); `-wal` 1289592, 1793754389 (Nov 3 20:06:29); `-shm` 32768, 1793754085 (Nov 3 20:01:25). The task's one read-only count (`sqlite3 "file:…?mode=ro"`) changed the `-shm` mtime to 1794259823 (Nov 9 16:30:23): SQLite opens the `-shm` read-write even with `mode=ro` and writes a read mark. Accepted by the controller as harmless (the index only, size unchanged); no further `sqlite3` read of the old store. After the first launch, the `Check` run and the relaunch, all three files read exactly 159744/1793753629, 1289592/1793754389, 32768/1794259823: the Release app never opened the old store.
- **Old ad-hoc copies moved to the Trash** (Finder `delete`, bundle ID `com.matthewfurr.ReadingThroughScripture`, before the install): `/Users/matt/Code/reading-through-scripture/Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app`, `/Users/matt/Library/Developer/Xcode/DerivedData/ReadingThroughScripture-ftubipjhhgrcbagzbfoetzdxsczq/Build/Products/Debug/ReadingThroughScripture.app`, `/Users/matt/Library/Developer/Xcode/DerivedData/ReadingThroughScripture-acxlrzjnjviwaqblpddewqzfhepz/Build/Products/Debug/ReadingThroughScripture.app`. Afterwards `mdfind` lists only the three Trash copies (until the Trash is emptied).
- **Install.** `Scripts/install-app.sh`: `** BUILD SUCCEEDED **`, `Installed /Applications/ReadingThroughScripture.app`. Entitlements: `SFQ7B3J933.com.matthewfurr.ReadingThroughScripture`, container `iCloud.com.matthewfurr.ReadingThroughScripture`, `icloud-container-environment Development`, kvstore and keychain group `SFQ7B3J933.com.matthewfurr.ReadingThroughScripture`.
- **First launch** (16:32:47): `store …/Sync/iCloud.com.matthewfurr.ReadingThroughScripture-Development/Markup.store, sync iCloud.com.matthewfurr.ReadingThroughScripture Development`; `key-value store synchronize true: 0 preferences taken, 9 offered`; `backup 2026-11-09.store` (16:32:47.5); the keychain prompt, answered by Matt; `keys moved to iCloud Keychain: anthropic` (16:32:55.4); setup and the first import finished with `failure none`; `old store imported: 36 records` (16:32:55.8); `prepared` (16:32:55.8, 8.4 s after the launch, most of it the keychain prompt); exports finished `failure none` from 21:32:53Z, the larger one ended 21:33:02Z. `Markup.legacy-imported` written (`2026-11-09T21:32:55Z`). No failure in the log.
- **Time to the first `Synced just now`.** The first finished export was 6 s after the launch (21:32:53Z); Settings › General, first opened at 16:33:45 (58 s after the launch), read `Synced just now`.
- **Settings › General** (read with System Events): Default translation; the notes column rows; iCloud: `Synced just now`; Backups: `Last backup` `Monday 4:32 PM`, Show in Finder and Restore… buttons, `A copy of your notes is kept on this Mac each day…`. **Settings › Assistant**: the Anthropic key row reads `Saved`; `Keys are stored in your Keychain and travel through iCloud Keychain.`
- **Check** (16:34:26): `waiting for the first import`, import finished and `prepared` at 16:34:28.4 (1.8 s), exports `failure none`; counts above. Quit; `Check.store`, `-wal`, `-shm`, `.Check_SUPPORT/`, `Check_ckAssets/` and `Backups-Check/` deleted; nothing else in the directory touched.
- **Relaunch** (16:35:15): `prepared` in 0.6 s, imports and exports `failure none`, window `Mark 1`. Left running for Matt.
- **Known gap: today's backup is empty.** The daily backup ran at 16:32:47.5, when the container opened and before the old store's import (16:32:55.8), so `Backups/2026-11-09.store` holds 0 records in all seven tables, and no second backup is taken today because today's file exists. Tomorrow's first launch takes the first backup with the notes. Until then the notes are in the synced store, in iCloud (proved by `Check`), and in the untouched old store.
- **Fixed** by the commit `fix: an empty backup taken before the old store's import is replaced the same day` (Ruling 20): an empty backup of today is replaced once the store has highlights or notes, and the app backs up again after the first prepare. The next launch of the installed app, once rebuilt with this commit, writes a real `2026-11-09.store` (the app now running is the earlier build; without a reinstall, tomorrow's first backup has the notes).

## Self-review notes

- Spec coverage (Milestone 7 and Decisions › Sync and iOS): enroll (done by Matt); create the CloudKit container (Task 3); turn on sync (Tasks 1, 3, 7, 13); verify on a second Mac or the iOS simulator (Task 12 with a stand-in store, the real second device deferred by Matt's choice, Ruling 14); handle the signed-out-of-iCloud state (Tasks 2, 7, 11, Ruling 5). Synced: highlights, notes, bookmarks, threads and messages, prompt templates, highlight colors (the store); reading position and settings (Task 9, Ruling 9: through the key-value store, and by Matt's choice not text size, spacing or appearance). Conflicts last-writer-wins per record (Task 12 step 7). "Sync that loses or duplicates highlights" (Rulings 4, 5, 7, 8; Tasks 4, 5, 6, 8).
- Type consistency: `SyncConfiguration` and `StoreLocation` (Task 1) are consumed by `MarkupContainer.make(at:sync:)`, `LegacyImport`, `StoreBackup`, `SyncCoordinator`, `SyncStatusModel`, `BackupsModel` and `AppSync`; `SyncEvent` and `SyncFailure` (Task 2) by `SyncStatusModel`; `RestoreSummary` (Task 4) by `LegacyImport`, `BackupsModel.sentence(for:)` and the tests in Tasks 5 and 11; `SeedMerge.mergeAll(in:seeds:)` (Task 6) by `SyncCoordinator`; `SyncStatusModel.onImport` and `isAccountAvailable` (Task 2) by `AppSync` and `SyncCoordinator.start(accountAvailable:)`; `KeyValueCloud` (Task 9) by `PreferenceSync` and `FakeKeyValueCloud`.
- Review Focus tests: 1 → Task 8, 2 → Task 8, 3 → Task 8, 4 → Tasks 2 and 7, 5 → Task 6.

## Known minors, deferred by the task reviews (2026-11-09)

The whole-branch review triaged these as able to wait. They are the backlog for a later polish pass.

- `StoreLocation`: a store name differing from `Markup` only by case, or `Legacy`, opens an existing file as a named store (compare case-insensitively, reserve `Legacy`); tests do not cover the default `Backups` directory or the real container with a named store.
- `SyncStatusModel` / `SyncMonitor`: no test for the `.unavailable` sentence or for the rarer `CKError` mappings; failure text is logged `.public`; `hasImportedThisLaunch` is never reset, so a sign-out and sign-in within one launch re-enables Restore before the new account's import (reset it on `.noAccount` or `CKAccountChanged`); a `RelativeDateTimeFormatter` is built per read.
- `StoreCopy`: field fidelity is only spot-checked (`Note.sourceThreadID`, `PromptTemplate.sectionRaw`/`isEnabled`/`outputKind`, `ChatMessage.providerHost`/`finishReason`/`savedNoteID`); an orphaned highlight-scoped note is copied as an anchorless note; `LegacyImport`'s failed-copy path is untested; `rollback()` on a failed save discards unrelated unsaved changes (comment it).
- `StoreBackup`: leftover `.partial` files after a crash are never removed; a prune failure is logged as a backup failure; pruning leaves sidecars; "empty" means no highlights and no notes only; an emptied store's backups resume with the first new highlight; no unreadable-file or non-default-calendar test.
- `SeedMerge`: the pristine check is case-sensitive where key assignment is not; re-pointed highlights are not counted; no test shows the uuid tie-break changes a result; duplicate built-in prompts whose key no seed matches lose the other copies' edits.
- `SyncCoordinator` / `AppSync`: `step`'s rollback acts on the shared main context (comment it); the first reload after prepare is debounced 300 ms; `templatesRevision` increments on every reload; two tests assert less than their comments.
- `MarkupModel` / `AssistantModel`: a computed `threadRecord` treats a fetch failure as "gone" silently; a stale doc comment at `MarkupModel.swift:9`; a young empty orphan note shows as an empty card for up to a day; `updateNoteBody` does a predicate fetch per keystroke.
- `PreferenceSync` / `NavigationModel`: an account change within the 2 s push delay overwrites a not-yet-pushed local edit; a kill within 2 s of the last scroll lets the cloud's older position win; a stored verse that does not start an entry is re-saved once and pushed back; the 2 s timer and the other navigations' `hasMovedThisSession` are untested.
- `KeychainStore`: the detached upgrade can race a save made at launch and bring back the previous key (re-read before delete); `keychainAccountsAreNamedPerProvider` depends on the test host having no bundle id; `reloadKeys` leaves an edited field's Saved state stale; no test for update-in-place in the file-based keychain.
- Settings and the notice: a repeated Restore with the same sentence is not re-announced and `resultText` persists across openings; prune can race a Restore of the oldest file at day rollover; `DESIGN.md`'s toolbar line omits the notice; Show in Finder with no `Backups` directory does nothing; `newestBackup` and `forcedAttention` are public (the latter Debug-only by contract); the Show in Finder and Restore buttons reported no name through System Events (check with VoiceOver).
- README: the Settings key list names nine of the ten synced keys (`readingPosition.translationID`); the iCloud-line summary omits "Could not sync. The app will try again."
- `install-app.sh`: the built-app check is satisfied by a stale bundle. The Debug-only probe's no-op paths. Event ordering in `SyncMonitor` now rests on the main executor's FIFO.
- Go-live: the installed app predates the same-day backup fix (`daaf65a`); its next launch writes a real backup for the day, or reinstall with `Scripts/install-app.sh`. The three old ad-hoc copies in the Trash still carry the bundle ID until the Trash is emptied.
