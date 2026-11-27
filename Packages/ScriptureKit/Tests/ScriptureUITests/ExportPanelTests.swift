#if os(macOS)
import Foundation
import Testing
@testable import ScriptureUI

@MainActor @Suite struct ExportPanelTests {
    @Test func optionsRoundTripThroughDefaults() {
        let defaults = UserDefaults(suiteName: "ExportPanelTests-\(UUID().uuidString)")!
        #expect(ExportPanel.options(from: defaults) == MarkdownExport.Options(layout: .singleFile, includesConversations: true))
        ExportPanel.remember(MarkdownExport.Options(layout: .folderPerBook, includesConversations: false), in: defaults)
        #expect(ExportPanel.options(from: defaults) == MarkdownExport.Options(layout: .folderPerBook, includesConversations: false))
    }

    /// A second export into the same folder replaces it: a book no longer marked leaves no file behind.
    @Test func aFolderExportReplacesTheFolderItOverwrites() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("ExportPanelTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let url = parent.appendingPathComponent("Notes", isDirectory: true)
        func output(_ books: [String]) -> MarkdownExport.Output {
            MarkdownExport.Output(name: "Notes", files: [MarkdownExport.File(relativePath: "README.md", text: "# Notes\n")] + books.map { MarkdownExport.File(relativePath: "\($0).md", text: "# \($0)\n") })
        }

        try ExportPanel.write(output(["Psalms", "Matthew"]), layout: .folderPerBook, to: url)
        try ExportPanel.write(output(["Matthew"]), layout: .folderPerBook, to: url)

        #expect(try FileManager.default.contentsOfDirectory(atPath: url.path).sorted() == ["Matthew.md", "README.md"])
        #expect(try String(contentsOf: url.appendingPathComponent("Matthew.md"), encoding: .utf8) == "# Matthew\n")
    }
}
#endif
