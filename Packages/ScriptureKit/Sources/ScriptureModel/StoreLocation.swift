import Foundation

/// Where the markup store lives: one directory per container and environment under
/// `Application Support/ReadingThroughScripture/Sync`, or `…/Local` when sync is off.
public struct StoreLocation: Equatable, Sendable {
    public static let defaultStoreName = "Markup"
    /// The launch argument (`-storeName Second`) that opens a second store beside the main one.
    public static let storeNameArgument = "storeName"

    public let directory: URL
    public let storeName: String
    /// The old local store to copy in once, if any.
    public let legacyStoreURL: URL?

    public var storeURL: URL { directory.appending(path: "\(storeName).store") }

    public var backupsDirectory: URL {
        directory.appending(
            path: storeName == Self.defaultStoreName ? "Backups" : "Backups-\(storeName)",
            directoryHint: .isDirectory)
    }

    /// The on-device journal of last texts, beside the store.
    public var lastTextsDirectory: URL {
        directory.appending(
            path: storeName == Self.defaultStoreName ? "LastTexts" : "LastTexts-\(storeName)",
            directoryHint: .isDirectory)
    }

    /// Written once the old store is imported. For the real container it sits beside the old
    /// store in `ReadingThroughScripture/`, so every environment of that container shares it and a
    /// later environment never imports the old store again; otherwise it is in `directory`.
    public var legacyMarkerURL: URL {
        if let legacyStoreURL, legacyStoreURL.deletingLastPathComponent().standardizedFileURL != directory.standardizedFileURL {
            return legacyStoreURL.deletingLastPathComponent().appending(path: "Markup.legacy-imported")
        }
        return directory.appending(path: "Markup.legacy-imported")
    }

    public static func resolve(sync: SyncConfiguration?, storeName: String? = nil, applicationSupport: URL = .applicationSupportDirectory) -> StoreLocation {
        let root = applicationSupport.appending(path: "ReadingThroughScripture", directoryHint: .isDirectory)
        let name = storeName.flatMap { isPlain($0) ? $0 : nil } ?? defaultStoreName
        guard let sync else {
            return StoreLocation(directory: root.appending(path: "Local", directoryHint: .isDirectory), storeName: name, legacyStoreURL: nil)
        }
        let directory = root
            .appending(path: "Sync", directoryHint: .isDirectory)
            .appending(path: "\(sync.containerIdentifier)-\(sync.environment.rawValue)", directoryHint: .isDirectory)
        let legacy: URL?
        if name != defaultStoreName {
            legacy = nil
        } else if sync.containerIdentifier == MarkupContainer.cloudKitContainerIdentifier {
            legacy = root.appending(path: "Markup.store")
        } else {
            legacy = directory.appending(path: "Legacy.store")
        }
        return StoreLocation(directory: directory, storeName: name, legacyStoreURL: legacy)
    }

    /// Whether a Debug probe must leave this store alone: the default-named store of the `.dev` or
    /// the real container, or of any container with sync off (the Debug app's local store). The
    /// store is a file and the default volume ignores case, so `markup` is `Markup`.
    public func refusesProbes(sync: SyncConfiguration?) -> Bool {
        guard storeName.caseInsensitiveCompare(Self.defaultStoreName) == .orderedSame else { return false }
        guard let sync else { return true }
        return sync.containerIdentifier == MarkupContainer.developmentContainerIdentifier
            || sync.containerIdentifier == MarkupContainer.cloudKitContainerIdentifier
    }

    /// 1 to 32 ASCII letters, digits or dashes.
    private static func isPlain(_ name: String) -> Bool {
        (1...32).contains(name.count)
            && name.unicodeScalars.allSatisfy { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-") }
    }
}
