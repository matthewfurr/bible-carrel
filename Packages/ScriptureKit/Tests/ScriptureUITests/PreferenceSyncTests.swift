import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

@MainActor @Suite struct PreferenceSyncTests {
    private func makeDefaults() -> UserDefaults {
        let name = "PreferenceSyncTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func theSyncedKeysAreExactlyThese() {
        #expect(SyncedPreferences.keys.sorted() == ["anthropicModel", "assistantProvider", "compareTranslationIDs", "compatibleBaseURL", "compatibleModel", "datesNoticeAnswered",
            "defaultTranslationID", "finishEditingWithReturn", "followedPlanID", "openAIModel", "readerJustified", "readerPageFace", "readerPageStyle",
            "readerShowsSectionHeadings", "readerShowsVerseNumbers", "readerVerseLayout",
            "readingPosition", "readingPosition.translationID", "showDates", "showNotelessHighlights"])
    }

    @Test func aNewDeviceTakesTheCloudValues() {
        let defaults = makeDefaults()
        defaults.set("ESV", forKey: "defaultTranslationID")
        let cloud = FakeKeyValueCloud(["defaultTranslationID": "KJV"])
        let sync = PreferenceSync(defaults: defaults, cloud: cloud)
        sync.start()
        #expect(defaults.string(forKey: "defaultTranslationID") == "KJV")
        #expect(cloud.synchronizeCount == 1)
        #expect(cloud.sets == 0)
    }

    @Test func aNewDeviceTakesDatesOffAndTheNoticeAnsweredFromTheCloud() {
        let defaults = makeDefaults()
        let cloud = FakeKeyValueCloud(["showDates": false, "datesNoticeAnswered": true])
        let sync = PreferenceSync(defaults: defaults, cloud: cloud)
        sync.start()
        #expect(!LibraryDates.shows(defaults) && !LibraryDates.showsNotice(defaults, viewHasDate: true))
        #expect(defaults.bool(forKey: "datesNoticeAnswered"))
    }

    @Test func aFirstRunPushesLocalValuesUp() {
        let defaults = makeDefaults()
        defaults.set(false, forKey: "showNotelessHighlights")
        let cloud = FakeKeyValueCloud()
        let sync = PreferenceSync(defaults: defaults, cloud: cloud)
        sync.start()
        #expect(cloud.object(forKey: "showNotelessHighlights") as? Bool == false)
    }

    @Test func aLocalChangeIsPushed() {
        let defaults = makeDefaults()
        let cloud = FakeKeyValueCloud()
        let sync = PreferenceSync(defaults: defaults, cloud: cloud)
        sync.start()
        defaults.set("x", forKey: "anthropicModel")
        #expect(cloud.object(forKey: "anthropicModel") == nil)   // pending until the push
        sync.pushPending()
        #expect(cloud.object(forKey: "anthropicModel") as? String == "x")
    }

    @Test func anExternalChangeLandsAndIsNotEchoed() {
        let defaults = makeDefaults()
        let cloud = FakeKeyValueCloud()
        let sync = PreferenceSync(defaults: defaults, cloud: cloud)
        sync.start()
        let setsBefore = cloud.sets
        cloud.simulateExternal(["defaultTranslationID": "WEB"])
        #expect(defaults.string(forKey: "defaultTranslationID") == "WEB")
        sync.pushPending()
        #expect(cloud.sets == setsBefore)
    }

    @Test func aKeyOutsideTheListNeverTravels() {
        let defaults = makeDefaults()
        defaults.set(18.0, forKey: "readerFontSize")
        let cloud = FakeKeyValueCloud(["readerFontSize": 22.0])
        let sync = PreferenceSync(defaults: defaults, cloud: cloud)
        sync.start()
        #expect(defaults.double(forKey: "readerFontSize") == 18.0)
        defaults.set(20.0, forKey: "readerFontSize")
        sync.pushPending()
        cloud.simulateExternal(["readerFontSize": 24.0])
        #expect(defaults.double(forKey: "readerFontSize") == 20.0)
        #expect(cloud.object(forKey: "readerFontSize") as? Double == 24.0)
        #expect(cloud.sets == 0)
    }

    @Test func aLocalRemovalRemovesTheCloudValue() {
        let defaults = makeDefaults()
        defaults.set("gpt-x", forKey: "openAIModel")
        let cloud = FakeKeyValueCloud()
        let sync = PreferenceSync(defaults: defaults, cloud: cloud)
        sync.start()
        #expect(cloud.object(forKey: "openAIModel") as? String == "gpt-x")
        defaults.removeObject(forKey: "openAIModel")
        sync.pushPending()
        #expect(cloud.object(forKey: "openAIModel") == nil)
    }

    @Test func anExternalRemovalRemovesTheLocalValue() {
        let defaults = makeDefaults()
        let cloud = FakeKeyValueCloud(["compatibleModel": "llama"])
        let sync = PreferenceSync(defaults: defaults, cloud: cloud)
        sync.start()
        #expect(defaults.string(forKey: "compatibleModel") == "llama")
        let setsBefore = cloud.sets
        cloud.simulateExternal(["compatibleModel": nil])
        #expect(defaults.object(forKey: "compatibleModel") == nil)
        sync.pushPending()
        #expect(cloud.sets == setsBefore)
    }

    @Test func savingTheSamePositionAgainPushesNothing() {
        let defaults = makeDefaults()
        let cloud = FakeKeyValueCloud()
        let sync = PreferenceSync(defaults: defaults, cloud: cloud)
        sync.start()
        let positionStore = ReadingPositionStore(defaults: defaults)
        positionStore.save(ReadingPosition(book: "ROM", chapter: 8, firstVisibleVerse: 1, translationID: "ESV"))
        sync.pushPending()
        let setsAfterFirstSave = cloud.sets
        #expect(setsAfterFirstSave == 1)
        positionStore.save(ReadingPosition(book: "ROM", chapter: 8, firstVisibleVerse: 1, translationID: "ESV"))
        sync.pushPending()
        #expect(cloud.sets == setsAfterFirstSave)
    }

    @Test func recentsStayOnTheDevice() {
        #expect(!SyncedPreferences.keys.contains(RecentsStore.key))
        let defaults = makeDefaults()
        let cloud = FakeKeyValueCloud()
        let sync = PreferenceSync(defaults: defaults, cloud: cloud)
        sync.start()
        let setsBefore = cloud.sets
        RecentsStore(defaults: defaults).record(.chapter(ChapterLocation(book: "JHN", chapter: 1)), translationID: "ESV")
        sync.pushPending()
        #expect(cloud.sets == setsBefore)
    }

    @Test func anAccountChangeNeverRemovesALocalValue() {
        let defaults = makeDefaults()
        defaults.set("KJV", forKey: "defaultTranslationID")
        defaults.set("claude-x", forKey: "anthropicModel")
        defaults.set(true, forKey: "finishEditingWithReturn")
        let cloud = FakeKeyValueCloud()
        let sync = PreferenceSync(defaults: defaults, cloud: cloud)
        var reported: [[String]] = []
        sync.onExternalChange = { reported.append($0) }
        sync.start()
        cloud.simulateAccountChange(to: [:])   // signed out, or into an account with nothing stored
        #expect(defaults.string(forKey: "defaultTranslationID") == "KJV")
        #expect(defaults.string(forKey: "anthropicModel") == "claude-x")
        #expect(defaults.object(forKey: "finishEditingWithReturn") as? Bool == true)
        #expect(cloud.object(forKey: "defaultTranslationID") as? String == "KJV")
        #expect(cloud.object(forKey: "anthropicModel") as? String == "claude-x")
        #expect(cloud.object(forKey: "finishEditingWithReturn") as? Bool == true)
        #expect(reported.isEmpty)
    }

    @Test func anAccountChangeTakesTheNewAccountsValues() {
        let defaults = makeDefaults()
        defaults.set("ESV", forKey: "defaultTranslationID")
        defaults.set("gpt-x", forKey: "openAIModel")
        let cloud = FakeKeyValueCloud()
        let sync = PreferenceSync(defaults: defaults, cloud: cloud)
        var reported: [[String]] = []
        sync.onExternalChange = { reported.append($0) }
        sync.start()
        cloud.simulateAccountChange(to: ["defaultTranslationID": "KJV"])
        #expect(defaults.string(forKey: "defaultTranslationID") == "KJV")
        #expect(reported == [["defaultTranslationID"]])
        #expect(defaults.string(forKey: "openAIModel") == "gpt-x")
        #expect(cloud.object(forKey: "openAIModel") as? String == "gpt-x")
        let setsAfterMerge = cloud.sets
        sync.pushPending()   // the merge's own write is not a local change to push back
        #expect(cloud.sets == setsAfterMerge)
    }

    @Test func externalChangesNameTheirKeys() {
        let defaults = makeDefaults()
        let cloud = FakeKeyValueCloud()
        let sync = PreferenceSync(defaults: defaults, cloud: cloud)
        var reported: [[String]] = []
        sync.onExternalChange = { reported.append($0) }
        sync.start()
        let position = Data("{}".utf8)
        cloud.simulateExternal(["readingPosition": position])
        #expect(reported == [["readingPosition"]])
        #expect(defaults.data(forKey: "readingPosition") == position)
    }
}
