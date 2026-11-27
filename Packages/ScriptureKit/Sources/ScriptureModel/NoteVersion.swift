import CryptoKit
import Foundation

/// The rules for a note's version mark, its ancestry and a deletion marker's version. A mark is
/// `<token>.<digest>`: the sitting that wrote the text and the text's digest. An ancestry is
/// `<token>:` then up to `ancestryLimit` entries (`<tag><digest>`), newest first, naming what the
/// sitting opened on. A marker's version is entries of the same form, the deleted text first.
/// Sight is by the writer's tag and the digest together. Only this type builds or reads those strings.
public enum NoteVersion {
    public static let ancestryLimit = 8
    public static let unknownDevice = "0000"

    private static let tagLength = 4
    private static let tokenLength = 12
    private static let digestLength = 16

    /// The first eight bytes of the SHA-256 of the trimmed text, as lowercase hex.
    public static func digest(_ text: String) -> String {
        let hash = SHA256.hash(data: Data(trimmed(text).utf8))
        return hash.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    public static func sameText(_ a: String, _ b: String) -> Bool { trimmed(a) == trimmed(b) }

    public static func isBlank(_ text: String) -> Bool { trimmed(text).isEmpty }

    /// The device's tag, then eight hex characters.
    public static func newToken(deviceTag: String, random: () -> UInt32 = { .random(in: .min ... .max) }) -> String {
        deviceTag + String(format: "%08x", random())
    }

    public static func mark(token: String, text: String) -> String { "\(token).\(digest(text))" }

    public static func token(ofMark mark: String?) -> String? { parts(ofMark: mark)?.token }

    /// The mark's digest is the text's.
    public static func isMarked(text: String, mark: String?) -> Bool {
        parts(ofMark: mark)?.digest == digest(text)
    }

    /// The ancestry's entries as digests, newest first; none unless `isMarked` and the ancestry's own token is the mark's.
    public static func ancestorDigests(text: String, mark: String?, ancestry: String?) -> [String] {
        ownEntries(text: text, mark: mark, ancestry: ancestry).map(\.digest)
    }

    /// What a sitting with `token` writes, opened on a note holding these three values.
    public static func ancestry(token: String, openedOn text: String, mark: String?, ancestry: String?) -> String {
        var entries: [Entry] = []
        if !isBlank(text) {
            entries.append(Entry(tag: markTag(text: text, mark: mark) ?? unknownDevice, digest: digest(text)))
        }
        entries += ownEntries(text: text, mark: mark, ancestry: ancestry)
        var kept: [Entry] = []
        for entry in entries {
            if let last = kept.last, last.tag == entry.tag, entry.tag != unknownDevice { continue }
            kept.append(entry)
        }
        return "\(token):" + kept.prefix(ancestryLimit).map { ($0.tag ?? unknownDevice) + $0.digest }.joined(separator: ",")
    }

    /// The tag of the device that wrote `text`, when the three values hang together; else nil.
    public static func writer(text: String, mark: String?, ancestry: String?) -> String? {
        guard isMarked(text: text, mark: mark), let token = token(ofMark: mark), let ancestry,
              ancestry.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).first == Substring(token)
        else { return nil }
        return String(token.prefix(tagLength))
    }

    /// A version was made with sight of `text`, written by the device tagged `writer`, when it is
    /// the same text, or its ancestry names that digest under `writer` or the unknown device. The
    /// same words put back by another device are not the ones seen. With `writer` nil (an entry
    /// from before entries named their writer, or values that do not hang together) the digest
    /// alone is sight.
    public static func hasSight(of text: String, writtenBy writer: String?, noteText: String, mark: String?, ancestry: String?) -> Bool {
        sameText(text, noteText) || ownEntries(text: noteText, mark: mark, ancestry: ancestry).contains { $0.names(text, writtenBy: writer) }
    }

    /// A marker's version: the deleted text as `<tag><digest>` under its mark's tag (the unknown
    /// device's when unmarked; left out when blank), then the ancestry's entries, comma separated.
    /// Nil when that names nothing: a note that never held text leaves no marker.
    public static func deleted(text: String, mark: String?, ancestry: String?) -> String? {
        var entries = ownEntries(text: text, mark: mark, ancestry: ancestry)
        if !isBlank(text) { entries.insert(Entry(tag: markTag(text: text, mark: mark) ?? unknownDevice, digest: digest(text)), at: 0) }
        guard !entries.isEmpty else { return nil }
        return entries.map { ($0.tag ?? unknownDevice) + $0.digest }.joined(separator: ",")
    }

    /// The marker names the text by its digest, whoever wrote it (it removes more, the safe side).
    public static func marker(_ version: String, names text: String) -> Bool {
        markerEntries(version).contains { $0.digest == digest(text) }
    }

    /// The marker names the text as written by `writer` (by `hasSight`'s rule). A marker written
    /// before entries carried a tag is read by digest alone.
    public static func marker(_ version: String, names text: String, writtenBy writer: String?) -> Bool {
        markerEntries(version).contains { $0.names(text, writtenBy: writer) }
    }

    /// The marker's first entry, the text deleted, is `text`'s digest.
    public static func marker(_ version: String, deleted text: String) -> Bool {
        markerEntries(version).first?.digest == digest(text)
    }

    // MARK: Parsing

    /// An ancestry's or a marker's entry; a marker's entry from before tags has `tag` nil.
    private struct Entry {
        var tag: String?
        var digest: String

        /// `hasSight`'s rule for one entry.
        func names(_ text: String, writtenBy writer: String?) -> Bool {
            guard digest == NoteVersion.digest(text) else { return false }
            guard let writer, let tag else { return true }
            return tag == writer || tag == NoteVersion.unknownDevice
        }
    }

    /// The tag of the sitting whose mark labels `text`; nil when the mark is not the text's.
    private static func markTag(text: String, mark: String?) -> String? {
        guard isMarked(text: text, mark: mark) else { return nil }
        return token(ofMark: mark).map { String($0.prefix(tagLength)) }
    }

    /// A marker's entries: `<tag><digest>`, or a bare digest from before tags; anything else is skipped.
    private static func markerEntries(_ version: String) -> [Entry] {
        version.split(separator: ",").compactMap { piece in
            if isHex(piece, count: tagLength + digestLength) {
                return Entry(tag: String(piece.prefix(tagLength)), digest: String(piece.dropFirst(tagLength)))
            }
            return isHex(piece, count: digestLength) ? Entry(tag: nil, digest: String(piece)) : nil
        }
    }

    private static func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private static func isHex(_ text: Substring, count: Int) -> Bool {
        text.count == count && text.allSatisfy { $0.isASCII && $0.isHexDigit && !$0.isUppercase }
    }

    private static func parts(ofMark mark: String?) -> (token: String, digest: String)? {
        guard let mark else { return nil }
        let pieces = mark.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count == 2, isHex(pieces[0], count: tokenLength), isHex(pieces[1], count: digestLength) else { return nil }
        return (String(pieces[0]), String(pieces[1]))
    }

    private static func ownEntries(text: String, mark: String?, ancestry: String?) -> [Entry] {
        guard isMarked(text: text, mark: mark), let token = token(ofMark: mark), let ancestry else { return [] }
        let pieces = ancestry.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard pieces.count == 2, pieces[0] == token else { return [] }
        return pieces[1].split(separator: ",").compactMap { piece in
            guard isHex(piece, count: tagLength + digestLength) else { return nil }
            return Entry(tag: String(piece.prefix(tagLength)), digest: String(piece.dropFirst(tagLength)))
        }
    }
}
