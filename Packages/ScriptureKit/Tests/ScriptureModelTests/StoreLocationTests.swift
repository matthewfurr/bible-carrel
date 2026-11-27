import Foundation
import Testing
@testable import ScriptureModel

private let support = URL(filePath: "/tmp/Support", directoryHint: .isDirectory)
private let real = SyncConfiguration(containerIdentifier: MarkupContainer.cloudKitContainerIdentifier, environment: .production)
private let dev = SyncConfiguration(containerIdentifier: MarkupContainer.developmentContainerIdentifier, environment: .development)

@Suite struct StoreLocationTests {
    /// The Debug probes never write to the main store of the `.dev` or the real container, nor to a
    /// default-named store with sync off (the Debug app's local store); a second store or another container is theirs.
    @Test func theProbesRefuseTheMainStores() {
        let rehearsal = SyncConfiguration(containerIdentifier: "iCloud.com.example.Rehearsal", environment: .development)
        for sync in [dev, real, nil] {
            #expect(StoreLocation.resolve(sync: sync, applicationSupport: support).refusesProbes(sync: sync))
            #expect(StoreLocation(directory: support, storeName: "markup", legacyStoreURL: nil).refusesProbes(sync: sync))      // the volume ignores case
            #expect(!StoreLocation.resolve(sync: sync, storeName: "Second", applicationSupport: support).refusesProbes(sync: sync))
        }
        #expect(!StoreLocation.resolve(sync: rehearsal, applicationSupport: support).refusesProbes(sync: rehearsal))
    }

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
        let location = StoreLocation.resolve(sync: real, applicationSupport: support)
        #expect(location.legacyStoreURL?.path == "/tmp/Support/ReadingThroughScripture/Markup.store")
        #expect(location.legacyMarkerURL.path == "/tmp/Support/ReadingThroughScripture/Markup.legacy-imported")
    }

    @Test func aLaterEnvironmentOfTheRealContainerShareTheMarker() {
        let development = StoreLocation.resolve(
            sync: SyncConfiguration(containerIdentifier: MarkupContainer.cloudKitContainerIdentifier, environment: .development),
            applicationSupport: support)
        let production = StoreLocation.resolve(sync: real, applicationSupport: support)
        #expect(development.directory != production.directory)
        #expect(development.legacyMarkerURL == production.legacyMarkerURL)
    }

    @Test func anotherContainerImportsOnlyARehearsalCopy() {
        let location = StoreLocation.resolve(sync: dev, applicationSupport: support)
        #expect(location.legacyStoreURL == location.directory.appending(path: "Legacy.store"))
        #expect(location.legacyMarkerURL == location.directory.appending(path: "Markup.legacy-imported"))
    }

    @Test func aNamedStoreSitsBesideTheMainOneAndImportsNothing() {
        let location = StoreLocation.resolve(sync: dev, storeName: "Second", applicationSupport: support)
        #expect(location.storeURL.lastPathComponent == "Second.store")
        #expect(location.backupsDirectory.lastPathComponent == "Backups-Second")
        #expect(location.legacyStoreURL == nil)
    }

    @Test func theLastTextsSitBesideTheStore() {
        let main = StoreLocation.resolve(sync: dev, applicationSupport: support)
        #expect(main.lastTextsDirectory == main.directory.appending(path: "LastTexts", directoryHint: .isDirectory))
        let named = StoreLocation.resolve(sync: dev, storeName: "ClashA", applicationSupport: support)
        #expect(named.lastTextsDirectory == named.directory.appending(path: "LastTexts-ClashA", directoryHint: .isDirectory))
    }

    @Test func aStoreNameThatIsNotPlainFallsBackToMarkup() {
        for name in ["../x", "a b", "", String(repeating: "a", count: 33)] {
            #expect(StoreLocation.resolve(sync: dev, storeName: name, applicationSupport: support).storeName == "Markup", "\(name)")
        }
    }
}
