import Foundation
import PDFKit
import ScriptureData

/// A file chosen with Import…: a church's PDF read by its table, any other file as text in the editor's form (spec 6.1, 6.3).
public enum PlanFileImport {
    public enum Failure: Error, Equatable, Sendable { case notAPlan, unreadableFile }
    public static let notAPlanMessage = "This PDF isn't laid out like a plan Bible Carrel can read. You can type the plan in instead."
    public static let unreadableMessage = "That file could not be read."

    /// A PDF by its table, any other file as text in the editor's form. Safe off the main actor.
    public nonisolated static func draft(fromFileAt url: URL, today: PlanDay) -> Result<PlanDraft, Failure> {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return .failure(.unreadableFile) }
        let title = PlanImport.title(forFileNamed: url.lastPathComponent)
        guard url.pathExtension.lowercased() == "pdf" || data.starts(with: Data("%PDF".utf8)) else {
            guard let text = String(data: data, encoding: .utf8) else { return .failure(.unreadableFile) }
            return .success(PlanText.draft(from: text, title: title, today: today))
        }
        guard let document = PDFDocument(data: data) else { return .failure(.unreadableFile) }
        guard document.pageCount > 0, let firstPage = document.page(at: 0) else { return .failure(.notAPlan) }
        let first = words(on: firstPage)
        guard PlanTableReader.hasHeader(first) else { return .failure(.notAPlan) }
        let rest = (1..<document.pageCount).map { document.page(at: $0).map(words(on:)) ?? [] }
        guard let table = try? PlanTableReader.table(pages: [first] + rest) else { return .failure(.notAPlan) }
        return .success(PlanImport.draft(from: table, title: title, today: today))
    }

    /// Each character's bounds; a character joins the word before it when its bottom is within 2 pt of the word's
    /// and it starts no more than 2 pt after the word ends and not before the word starts.
    nonisolated static func words(on page: PDFPage) -> [PlanWord] {
        let text = (page.string ?? "") as NSString
        var words: [PlanWord] = []
        var current: PlanWord?
        func flush() {
            if let current { words.append(current) }
            current = nil
        }
        for index in 0..<text.length {
            let character = text.substring(with: NSRange(location: index, length: 1))
            if character.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                flush()
                continue
            }
            guard let bounds = page.selection(for: NSRange(location: index, length: 1))?.bounds(for: page) else { continue }
            let x0 = Double(bounds.minX), x1 = Double(bounds.maxX), y = Double(bounds.minY)
            if let word = current, abs(word.y - y) < 2, x0 - word.x1 <= 2, x0 >= word.x0 {
                current = PlanWord(word.text + character, x0: word.x0, x1: x1, y: word.y)
            } else {
                flush()
                current = PlanWord(character, x0: x0, x1: x1, y: y)
            }
        }
        flush()
        return words
    }
}
