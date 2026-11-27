import Foundation
#if os(macOS)
import Security
#endif

/// Which CloudKit container and environment this build syncs with, read from its own signature.
/// No iCloud container entitlement (an unsigned build, `swift test`) means sync is off.
public struct SyncConfiguration: Equatable, Sendable {
    public enum Environment: String, Sendable {
        case development = "Development"
        case production = "Production"
    }

    public let containerIdentifier: String
    public let environment: Environment

    public init(containerIdentifier: String, environment: Environment) {
        self.containerIdentifier = containerIdentifier
        self.environment = environment
    }

    /// The first container, and the environment matched case-insensitively (development when
    /// missing or unrecognised). Nil without a container.
    public init?(containerIdentifiers: [String]?, environment: String?) {
        guard let containerIdentifier = containerIdentifiers?.first else { return nil }
        let matched = environment.flatMap { value in
            [Environment.development, .production].first { $0.rawValue.caseInsensitiveCompare(value) == .orderedSame }
        }
        self.init(containerIdentifier: containerIdentifier, environment: matched ?? .development)
    }

    static let containerIdentifiersEntitlement = "com.apple.developer.icloud-container-identifiers"
    static let containerEnvironmentEntitlement = "com.apple.developer.icloud-container-environment"

    static let containerInfoKey = "CloudKitContainer"
    static let environmentInfoKey = "CloudKitEnvironment"

    /// The setup an Info.plist names (`CloudKitContainer`, `CloudKitEnvironment`), where the app
    /// cannot read its own entitlements (iOS). The environment is matched case-insensitively.
    /// Nil without a container, or with an empty one.
    public static func fromInfoDictionary(_ info: [String: Any]?) -> SyncConfiguration? {
        guard let container = info?[containerInfoKey] as? String, !container.isEmpty else { return nil }
        return SyncConfiguration(containerIdentifiers: [container], environment: info?[environmentInfoKey] as? String)
    }

    /// The running process's sync setup: on the Mac from its iCloud entitlements (nil when
    /// unsigned), on iOS from its Info.plist.
    public static func current() -> SyncConfiguration? {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil) else { return nil }
        let identifiers = SecTaskCopyValueForEntitlement(task, containerIdentifiersEntitlement as CFString, nil) as? [String]
        let environment = SecTaskCopyValueForEntitlement(task, containerEnvironmentEntitlement as CFString, nil) as? String
        return SyncConfiguration(containerIdentifiers: identifiers, environment: environment)
        #elseif os(iOS)
        return fromInfoDictionary(Bundle.main.infoDictionary)
        #else
        return nil
        #endif
    }
}
