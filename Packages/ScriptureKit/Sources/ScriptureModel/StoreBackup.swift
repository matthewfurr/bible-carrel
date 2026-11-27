import Foundation
import SQLite3

/// The app's own daily copy of the markup store, kept beside it in `Backups/` as
/// `yyyy-MM-dd.store`, the newest `kept` of them. Signing out of iCloud empties a synced store;
/// these copies do not depend on iCloud.
public enum StoreBackup {
    public static let kept = 7

    public struct Backup: Equatable, Sendable {
        public let url: URL
        /// The `yyyy-MM-dd` in the file's name.
        public let day: String
    }

    /// Copies the SQLite store at `source` to `destination` with SQLite's online backup API, so the
    /// copy is consistent even while the app has the store open in WAL mode. The source is opened
    /// read-only. The result is one file with no `-wal` beside it. The copy is written under a
    /// temporary name in the destination's directory and moved into place only when complete, so a
    /// failure leaves nothing at `destination`.
    public static func copy(storeAt source: URL, to destination: URL) throws {
        let files = FileManager.default
        let partial = destination.deletingLastPathComponent()
            .appending(path: ".\(destination.lastPathComponent).partial-\(UUID().uuidString)")
        do {
            try backUp(source.path(percentEncoded: false), into: partial.path(percentEncoded: false))
            if files.fileExists(atPath: destination.path(percentEncoded: false)) {
                _ = try files.replaceItemAt(destination, withItemAt: partial)
            } else {
                try files.moveItem(at: partial, to: destination)
            }
        } catch {
            for suffix in ["", "-journal", "-wal", "-shm"] {
                try? files.removeItem(atPath: partial.path(percentEncoded: false) + suffix)
            }
            throw error
        }
    }

    /// What one call to `takeBackup` did.
    public enum Outcome: Equatable, Sendable {
        /// The new file, or today's empty backup replaced by one that holds the store's records.
        case taken(URL)
        /// No store file, or today's backup exists and is not an empty one the store has outgrown.
        case notNeeded
        /// The store has no highlights and no notes while the newest backup has some, so today's
        /// copy was not taken: a sign-out purge or a mass delete never ages the last good copy out.
        case skippedEmptyStore
    }

    /// Takes today's backup unless there is one already. Returns nil when the store file is absent,
    /// `Backups/<day>.store` exists, or the store is empty while the newest backup is not;
    /// otherwise creates the directory, copies, prunes to the newest `kept` and returns the new file.
    /// The one exception to a backup a day: when today's backup holds no highlights and no notes
    /// and the store holds some, today's file is replaced (written under a partial name, then moved
    /// over it) and returned.
    @discardableResult
    public static func backUpIfNeeded(_ location: StoreLocation, now: Date = Date(), calendar: Calendar = .current) throws -> URL? {
        if case let .taken(url) = try takeBackup(location, now: now, calendar: calendar) { return url }
        return nil
    }

    /// `backUpIfNeeded`, saying why no backup was taken.
    public static func takeBackup(_ location: StoreLocation, now: Date = Date(), calendar: Calendar = .current) throws -> Outcome {
        let files = FileManager.default
        guard files.fileExists(atPath: location.storeURL.path(percentEncoded: false)) else { return .notNeeded }
        let destination = location.backupsDirectory.appending(path: "\(day(of: now, in: calendar)).store")
        if files.fileExists(atPath: destination.path(percentEncoded: false)) {
            // Today's backup is replaced only when it holds nothing and the store now holds
            // something: a copy taken as the container opened, before an import filled the store.
            guard markCount(at: destination, immutable: true) == 0,
                  let live = markCount(at: location.storeURL), live > 0 else { return .notNeeded }
            try copy(storeAt: location.storeURL, to: destination)
            return .taken(destination)
        }
        if markCount(at: location.storeURL) == 0,
           let newest = try backups(in: location).first,
           let kept = markCount(at: newest.url, immutable: true), kept > 0 {
            return .skippedEmptyStore
        }
        try files.createDirectory(at: location.backupsDirectory, withIntermediateDirectories: true)
        try copy(storeAt: location.storeURL, to: destination)
        try prune(location)
        return .taken(destination)
    }

    /// Highlights plus notes in the store at `url`, read through a read-only connection; nil when
    /// they cannot be counted, which never skips a backup. A backup file is opened `immutable`:
    /// it is a WAL-mode database with no `-shm` beside it, which a read-only open cannot create,
    /// and nothing writes it.
    static func markCount(at url: URL, immutable: Bool = false) -> Int? {
        var connection: OpaquePointer?
        defer { sqlite3_close_v2(connection) }
        let opened: Int32
        if immutable {
            var components = URLComponents()
            components.scheme = "file"
            components.path = url.path(percentEncoded: false)
            components.queryItems = [URLQueryItem(name: "immutable", value: "1")]
            guard let uri = components.string else { return nil }
            opened = sqlite3_open_v2(uri, &connection, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil)
        } else {
            opened = sqlite3_open_v2(url.path(percentEncoded: false), &connection, SQLITE_OPEN_READONLY, nil)
        }
        guard opened == SQLITE_OK, let connection else { return nil }
        sqlite3_busy_timeout(connection, 5_000)
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        let sql = "SELECT (SELECT COUNT(*) FROM ZHIGHLIGHT) + (SELECT COUNT(*) FROM ZNOTE)"
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return Int(sqlite3_column_int64(statement, 0))
    }

    /// The files in `location.backupsDirectory` named `yyyy-MM-dd.store`, newest first. An absent
    /// directory is an empty list.
    public static func backups(in location: StoreLocation) throws -> [Backup] {
        let files = FileManager.default
        guard files.fileExists(atPath: location.backupsDirectory.path(percentEncoded: false)) else { return [] }
        let dated = #/([0-9]{4}-[0-9]{2}-[0-9]{2})\.store/#
        return try files.contentsOfDirectory(at: location.backupsDirectory, includingPropertiesForKeys: nil)
            .compactMap { url in
                guard let match = url.lastPathComponent.wholeMatch(of: dated) else { return nil }
                return Backup(url: url, day: String(match.output.1))
            }
            .sorted { $0.day > $1.day }
    }

    /// Deletes the dated backups beyond the newest `kept`. A file with any other name is never touched.
    static func prune(_ location: StoreLocation) throws {
        for backup in try backups(in: location).dropFirst(kept) {
            try FileManager.default.removeItem(at: backup.url)
        }
    }

    /// The calendar day of `date` as `yyyy-MM-dd`, from its components rather than a formatter.
    private static func day(of date: Date, in calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    /// One online backup from `sourcePath` (opened read-only) into a new database at
    /// `destinationPath`. Both connections are closed on every path.
    private static func backUp(_ sourcePath: String, into destinationPath: String) throws {
        var source: OpaquePointer?
        defer { sqlite3_close_v2(source) }
        let opened = sqlite3_open_v2(sourcePath, &source, SQLITE_OPEN_READONLY, nil)
        guard opened == SQLITE_OK, let source else { throw SQLiteFailure(code: opened, connection: source, step: "open store") }
        sqlite3_busy_timeout(source, 5_000)

        var destination: OpaquePointer?
        defer { sqlite3_close_v2(destination) }
        let created = sqlite3_open_v2(destinationPath, &destination, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
        guard created == SQLITE_OK, let destination else { throw SQLiteFailure(code: created, connection: destination, step: "create backup") }

        guard let backup = sqlite3_backup_init(destination, "main", source, "main") else {
            throw SQLiteFailure(code: sqlite3_errcode(destination), connection: destination, step: "start backup")
        }
        let stepped = sqlite3_backup_step(backup, -1)
        let finished = sqlite3_backup_finish(backup)
        guard stepped == SQLITE_DONE else { throw SQLiteFailure(code: stepped, connection: destination, step: "copy pages") }
        guard finished == SQLITE_OK else { throw SQLiteFailure(code: finished, connection: destination, step: "finish backup") }
    }
}

/// A SQLite call that did not succeed during a backup.
struct SQLiteFailure: Error, CustomStringConvertible {
    let code: Int32
    let message: String
    let step: String

    init(code: Int32, connection: OpaquePointer?, step: String) {
        self.code = code
        self.step = step
        message = connection.flatMap { sqlite3_errmsg($0).map { String(cString: $0) } } ?? String(cString: sqlite3_errstr(code))
    }

    var description: String { "\(step): SQLite \(code), \(message)" }
}
