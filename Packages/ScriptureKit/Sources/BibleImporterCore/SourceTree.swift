import Foundation

/// One `{VERSION}.json` file located in the holybooks tree.
public struct BookFileRef: Sendable, Equatable {
    public let translationID: String
    public let bookCode: String
    public let canonFolder: String
    public let url: URL
}

/// A checkout (or partial checkout) of the holybooks repository: `root/EN/{OT,NT,AP}/{CODE}/{VERSION}.json`.
public struct SourceTree: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    /// All book files for the given translation IDs, sorted by canon folder, book code, translation.
    public func bookFiles(translations: Set<String>) throws -> [BookFileRef] {
        let fm = FileManager.default
        let en = root.appendingPathComponent("EN")
        var refs: [BookFileRef] = []
        for canonFolder in try fm.contentsOfDirectory(atPath: en.path) {
            let canonURL = en.appendingPathComponent(canonFolder)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: canonURL.path, isDirectory: &isDir), isDir.boolValue else { continue }
            for bookCode in try fm.contentsOfDirectory(atPath: canonURL.path) {
                let bookURL = canonURL.appendingPathComponent(bookCode)
                guard fm.fileExists(atPath: bookURL.path, isDirectory: &isDir), isDir.boolValue else { continue }
                for file in try fm.contentsOfDirectory(atPath: bookURL.path) where file.hasSuffix(".json") {
                    let translationID = String(file.dropLast(".json".count))
                    guard translations.contains(translationID) else { continue }
                    refs.append(BookFileRef(
                        translationID: translationID,
                        bookCode: bookCode,
                        canonFolder: canonFolder,
                        url: bookURL.appendingPathComponent(file)))
                }
            }
        }
        return refs.sorted {
            ($0.canonFolder, $0.bookCode, $0.translationID) < ($1.canonFolder, $1.bookCode, $1.translationID)
        }
    }
}
