import BibleImporterCore
import Foundation
import ScriptureData

/// Builds a tiny bible.sqlite from the hand-written fixtures once per test process.
/// The database lives in a directory that is wiped on the next run, so no temp files pile up.
enum FixtureStore {
    private static let url: Result<URL, Error> = Result {
        let root = Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ScriptureUITests", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let out = directory.appendingPathComponent("fixture-\(ProcessInfo.processInfo.processIdentifier).sqlite")
        _ = try BibleDatabaseWriter(outputURL: out).importAll(
            from: SourceTree(root: root),
            translations: ["WEB": "World English Bible", "KJV": "King James Version"],
            sourceCommit: "fixture",
            crossReferences: root.appendingPathComponent("CrossRefs/cross_references.txt"),
            theographic: root.appendingPathComponent("Theographic"))
        return out
    }

    static func make() throws -> BibleStore {
        try BibleStore(databaseURL: try url.get())
    }
}
