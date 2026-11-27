import Testing
@testable import ScriptureModel

@Suite struct SyncConfigurationTests {
    @Test func noContainerMeansNoSync() {
        #expect(SyncConfiguration(containerIdentifiers: nil, environment: "Production") == nil)
        #expect(SyncConfiguration(containerIdentifiers: [], environment: nil) == nil)
        // From the Info dictionary: nil info, missing key, empty string.
        #expect(SyncConfiguration.fromInfoDictionary(nil) == nil)
        #expect(SyncConfiguration.fromInfoDictionary(["CloudKitEnvironment": "Development"]) == nil)
        #expect(SyncConfiguration.fromInfoDictionary(["CloudKitContainer": "", "CloudKitEnvironment": "Development"]) == nil)
    }

    @Test func theEnvironmentDefaultsToDevelopment() {
        #expect(SyncConfiguration(containerIdentifiers: ["iCloud.x"], environment: nil)
            == SyncConfiguration(containerIdentifier: "iCloud.x", environment: .development))
        #expect(SyncConfiguration(containerIdentifiers: ["iCloud.x"], environment: "production")?.environment == .production)
        #expect(SyncConfiguration(containerIdentifiers: ["iCloud.x", "iCloud.y"], environment: "Development")?.containerIdentifier == "iCloud.x")
    }

    @Test func aTestProcessHasNoEntitlements() { #expect(SyncConfiguration.current() == nil) }

    @Test func readsContainerAndEnvironmentFromInfo() {
        let c = SyncConfiguration.fromInfoDictionary(["CloudKitContainer": "iCloud.x.dev", "CloudKitEnvironment": "development"])
        #expect(c == SyncConfiguration(containerIdentifier: "iCloud.x.dev", environment: .development))
    }

    /// The build setting writes the environment capitalised, as the entitlement does.
    @Test func readsTheCapitalisedEnvironmentFromInfo() {
        #expect(SyncConfiguration.fromInfoDictionary(["CloudKitContainer": "iCloud.x.dev", "CloudKitEnvironment": "Development"])
            == SyncConfiguration(containerIdentifier: "iCloud.x.dev", environment: .development))
        #expect(SyncConfiguration.fromInfoDictionary(["CloudKitContainer": "iCloud.x", "CloudKitEnvironment": "Production"])?.environment
            == .production)
    }
}
