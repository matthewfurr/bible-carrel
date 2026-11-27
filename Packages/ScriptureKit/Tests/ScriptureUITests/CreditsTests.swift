import Foundation
import ScriptureData
import Testing
@testable import ScriptureUI

/// The credits catalogue and the About view's head: every bundled translation and font has an
/// entry, the catalogue is the spec's appendix and claims no permission, and (on the Mac) the
/// README acknowledges every source.
@Suite struct CreditsTests {
    @Test func everyBundledTranslationHasACredit() {
        // The importer's list (`Sources/bible-importer/main.swift:6`), which a test cannot import.
        for id in ["AMP", "ASV", "CPDV", "ERV", "ESV", "KJV", "NASB", "WEB"] {
            #expect(Credits.all.contains { $0.translationID == id && $0.section == .scripture }, "\(id)")
        }
    }

    @Test(.needsRealBible) func everyTranslationInTheBuiltDatabaseHasACredit() throws {
        for id in try BenchmarkChapter.realStore().translations().map(\.id) {
            #expect(Credits.all.contains { $0.translationID == id }, "\(id)")
        }
    }

    @Test func everyBundledFontHasACreditWithItsLicenceText() throws {
        let families = Credits.bundledFontFamilies()
        #expect(families == ["Literata", "SourceSerif4"])
        for family in families {
            let credit = try #require(Credits.all.first { $0.fontFamily == family })
            #expect(Credits.licenseText(for: credit)?.contains("SIL OPEN FONT LICENSE") == true)
        }
    }

    @Test func theCatalogueIsTheAppendixAndClaimsNoPermission() throws {
        #expect(Credits.all.count == 17 && Set(Credits.all.map(\.id)).count == 17)
        #expect(Credit.Section.allCases.map(\.rawValue) == ["Scripture", "Study data", "Typefaces, icon, videos and software"])
        #expect(Credit.Section.allCases.allSatisfy { !Credits.entries(in: $0).isEmpty })
        #expect(Credits.entries(in: .scripture).map(\.name).contains("Amplified Bible, Classic Edition"))
        #expect(Credits.all.allSatisfy { $0.link.scheme == "https" && !$0.notice.isEmpty })
        #expect(!Credits.all.contains { $0.notice.localizedCaseInsensitiveContains("used by permission") })
        #expect(!Credits.all.contains { $0.notice.contains("Matt") })          // no author line, no remarks to ourselves
        for credit in Credits.all where credit.licenseFile != nil {
            #expect((Credits.licenseText(for: credit) ?? "").count > 200, "\(credit.id)")
        }
        let openbible = try #require(Credits.all.first { $0.id == "openbible" })
        #expect(openbible.notice == "Cross-references from OpenBible.info, CC BY 4.0, drawn chiefly from the Treasury of Scripture Knowledge. Changes: re-keyed to this app's verse table; links with no votes left out.")
        #expect(openbible.link.absoluteString == "https://openbible.info/labs/cross-references" && openbible.licenseLink?.host() == "creativecommons.org")
        let theographic = try #require(Credits.all.first { $0.id == "theographic" })
        #expect(theographic.notice == LibraryCredit.text && theographic.notice.hasPrefix("People, places and events from Theographic Bible Metadata by Robert Rouse (viz.bible), CC BY-SA 4.0, changed:"))
        #expect(theographic.licenseLink?.absoluteString == "https://creativecommons.org/licenses/by-sa/4.0/" && String(LibraryCredit.linked.characters) == LibraryCredit.text)
        #expect(LibraryCredit.linked.runs.compactMap(\.link).count == 7)
        let grdb = try #require(Credits.all.first { $0.id == "grdb" })
        #expect(Credits.licenseText(for: grdb)?.contains("Permission is hereby granted, free of charge") == true)
        let holybooks = try #require(Credits.all.first { $0.id == "holybooks" })
        #expect(Credits.licenseText(for: holybooks)?.contains("Grigory Bakunov") == true)
    }

    @Test func aboutListsThreeSectionsInOrder() {
        #expect(Credits.entries(in: .scripture).map(\.id) == ["esv", "nasb", "amp", "erv", "asv", "kjv", "web", "cpdv"])
        #expect(Credits.entries(in: .studyData).map(\.id) == ["bsb", "openbible", "theographic"])
        #expect(Credits.entries(in: .typefacesAndSoftware).map(\.id) == ["literata", "sourceSerif4", "3dicons", "bibleProject", "holybooks", "grdb"])
        let together = Credit.Section.allCases.flatMap { Credits.entries(in: $0) }.map(\.id)
        #expect(together == Credits.all.map(\.id) && together.count == 17)
    }

    @Test func theUseAfterTheDot() {
        let uses: [String: String?] = [
            "esv": nil, "nasb": nil, "amp": "the file labelled AMP", "erv": nil, "asv": nil, "kjv": "and its book titles", "web": nil, "cpdv": nil,
            "bsb": "section headings", "openbible": "cross-references", "theographic": "people, places, events and dictionary entries",
            "literata": "reading typeface", "sourceSerif4": "reading typeface", "3dicons": "the app icon's artwork",
            "bibleProject": "links to its book overview videos", "holybooks": "the texts' file layout", "grdb": "reading the Bible database",
        ]
        for credit in Credits.all { #expect(credit.shownUse == uses[credit.id]!, "\(credit.id)") }
        let hidden = Credits.all.filter { $0.shownUse == nil }
        #expect(hidden.map(\.id) == ["esv", "nasb", "erv", "asv", "web", "cpdv"] && hidden.allSatisfy { $0.section == .scripture })
    }

    /// The dot goes with the use: a no-break space after it, so a line that wraps breaks before
    /// "·" and never leaves it at a line's end. A Bible text has neither.
    @Test func aWrappedUseKeepsItsDot() throws {
        let bsb = CreditLine(credit: try #require(Credits.all.first { $0.id == "bsb" }))
        #expect(bsb.afterName == " \u{00B7}\u{00A0}section headings")
        for credit in Credits.all {
            let line = CreditLine(credit: credit)
            #expect(line.afterName == line.use.map { " \u{00B7}\u{00A0}\($0)" }, "\(credit.id)")
        }
    }

    @Test func aLinesWordsForVoiceOver() throws {
        func line(_ id: String) throws -> CreditLine { CreditLine(credit: try #require(Credits.all.first { $0.id == id })) }
        #expect(try line("esv").spoken == "English Standard Version, Copyright")
        #expect(try line("kjv").spoken == "King James Version, and its book titles, Public domain")
        #expect(try line("literata").spoken == "Literata, reading typeface, SIL OFL 1.1")
        #expect(try line("esv").value(isOpen: false) == "Collapsed" && line("esv").value(isOpen: true) == "Expanded")
    }

    @Test func whatAnOpenedLineShows() throws {
        func line(_ id: String) throws -> CreditLine { CreditLine(credit: try #require(Credits.all.first { $0.id == id })) }
        let esv = try #require(Credits.all.first { $0.id == "esv" })
        #expect(try line("esv").opened == [.notice(esv.notice), .link(address: "crossway.org/permissions", url: esv.link)])
        #expect(try line("literata").opened.last == .licenceText)
        #expect(try line("openbible").opened.last == .licenceLink(name: "CC BY 4.0", url: URL(string: "https://creativecommons.org/licenses/by/4.0/")!))
        var withText: [String] = [], withLink: [String] = []
        for credit in Credits.all {
            let last = CreditLine(credit: credit).opened.last
            if last == .licenceText { withText.append(credit.id) }
            if case .licenceLink = last { withLink.append(credit.id) }
        }
        #expect(withText == ["literata", "sourceSerif4", "holybooks", "grdb"])
        #expect(withLink == ["openbible", "theographic"])
    }

    @Test func noWordSaysUsedByPermission() {
        for credit in Credits.all {
            for text in [credit.name, credit.use, credit.notice, credit.license] {
                #expect(!text.localizedCaseInsensitiveContains("used by permission"), "\(credit.id)")
            }
        }
    }

    /// The file is the pinned commit's own, typo and all; a tidy-up must not swap in a generic text.
    @Test func theHolybooksLicenceIsTheUpstreamFile() throws {
        let holybooks = try #require(Credits.all.first { $0.id == "holybooks" })
        let text = try #require(Credits.licenseText(for: holybooks))
        #expect(text.contains("Neither the name of hollybooks"))
        #expect(text.contains("Copyright (c) 2016, Grigory Bakunov"))
    }

    @Test func reflowingALicenceChangesLineBreaksOnly() throws {
        for credit in Credits.all where credit.licenseFile != nil {
            let text = try #require(Credits.licenseText(for: credit))
            let words = { (s: String) in s.split(whereSeparator: \.isWhitespace) }
            #expect(words(LicenseText.reflowed(text)) == words(text), "\(credit.id)")
        }
    }

    @Test func reflowingKeepsHeadingsAndNumberedItemsOnTheirOwnLines() throws {
        let literata = try #require(Credits.all.first { $0.id == "literata" })
        let lines = LicenseText.reflowed(try #require(Credits.licenseText(for: literata))).components(separatedBy: "\n")
        for heading in ["PREAMBLE", "DEFINITIONS", "PERMISSION & CONDITIONS", "TERMINATION", "DISCLAIMER"] {
            #expect(lines.contains(heading), "\(heading)")
        }
        #expect(lines.filter { $0.hasPrefix("1) ") || $0.hasPrefix("5) ") }.count == 2)
        #expect(lines.contains { $0.hasPrefix("The goals of the Open Font License") && $0.contains("partnership with others.") })
        let holybooks = try #require(Credits.all.first { $0.id == "holybooks" })
        let holybooksLines = LicenseText.reflowed(try #require(Credits.licenseText(for: holybooks))).components(separatedBy: "\n")
        #expect(holybooksLines.filter { $0.hasPrefix("* ") }.count == 3)
        #expect(holybooksLines.contains { $0.hasPrefix("* Neither the name of hollybooks") && $0.hasSuffix("permission.") })
    }

    @Test func aboutDrawsThreeSectionsOfLines() {
        let page = AboutView.page()
        #expect(page.map(\.title) == ["Scripture", "Study data", "Typefaces, icon, videos and software"])
        #expect(page.map(\.lines.count) == [8, 3, 6])
        #expect(page.flatMap(\.lines).map(\.credit.id) == Credits.all.map(\.id))
    }

    @MainActor @Test func aboutOpensWithEveryLineClosed() {
        let about = AboutView(info: nil)
        #expect(about.initiallyOpened.isEmpty && about.initiallyLicenceOpened.isEmpty)
    }

    @Test func theShownAddressesAreTheLinksWithoutHttps() {
        for credit in Credits.all {
            #expect(CreditLine.address(credit.link) == credit.link.absoluteString.replacing("https://", with: ""), "\(credit.id)")
        }
    }

    @Test func aboutNamesTheAppAndItsVersion() {
        let info: [String: Any] = ["CFBundleDisplayName": "Bible Carrel", "CFBundleName": "X", "CFBundleShortVersionString": "0.2", "CFBundleVersion": "1"]
        #expect(AboutView.appName(info: info) == "Bible Carrel" && AboutView.versionLine(info: info) == "Version 0.2 (1)")
        #expect(AboutView.appName(info: nil) == "Bible Carrel")
    }

    #if os(macOS)
    @Test func theReadmeAcknowledgesEverySource() throws {
        // README.md at the repository root, from `#filePath` as `SepiaModeTests` finds the sources.
        let acknowledgements = try Self.readmeSection("## Acknowledgements")
        for credit in Credits.all { #expect(acknowledgements.contains(credit.name), "\(credit.name)") }
        #expect(!acknowledgements.localizedCaseInsensitiveContains("used by permission"))
    }

    @Test func theSitesCreditsAreTheApps() throws {
        let site = try Self.siteCredits()                  // [SiteCredit], Decodable, the shape below
        #expect(site.map(\.id) == Credits.all.map(\.id))   // the same sources in the same order
        for (theirs, ours) in zip(site, Credits.all) {
            #expect(theirs.section == ours.section.rawValue, "\(ours.id): section")
            #expect(theirs.name == ours.name, "\(ours.id): name")
            #expect(theirs.use == ours.use, "\(ours.id): use")
            #expect(theirs.notice == ours.notice, "\(ours.id): notice")
            #expect(theirs.license == ours.license, "\(ours.id): licence")
            #expect(theirs.link == ours.link.absoluteString, "\(ours.id): link")
            #expect(theirs.licenseLink == ours.licenseLink?.absoluteString, "\(ours.id): licence link")
            #expect(theirs.licenseFile == ours.licenseFile, "\(ours.id): licence file")
        }
        let linked = try #require(site.first { $0.id == "theographic" }).noticeLinks
        #expect(linked.map(\.phrase) == Self.linkedPhrases(LibraryCredit.linked))   // from the attributed string's link runs
        #expect(linked.map(\.url) == Self.linkedURLs(LibraryCredit.linked))
    }

    /// One entry of the site's `credits.json` (`site/src/_data`), the shape the Sources page reads.
    private struct SiteCredit: Decodable {
        struct NoticeLink: Decodable { let phrase: String; let url: String }
        let id, section, name, use, notice, license, link: String
        let licenseLink, licenseFile: String?
        let noticeLinks: [NoticeLink]
    }

    /// `site/src/_data/credits.json`, found from `#filePath` as the README is.
    private static func siteCredits() throws -> [SiteCredit] {
        let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = package.appending(path: "../../site/src/_data/credits.json").standardized
        return try JSONDecoder().decode([SiteCredit].self, from: Data(contentsOf: file))
    }

    /// The text of each run of `text` that carries a link, in order.
    private static func linkedPhrases(_ text: AttributedString) -> [String] {
        text.runs.filter { $0.link != nil }.map { String(text[$0.range].characters) }
    }

    /// The link of each run of `text` that carries one, in order.
    private static func linkedURLs(_ text: AttributedString) -> [String] {
        text.runs.compactMap { $0.link?.absoluteString }
    }

    /// The text under `heading` in the repository's README, up to the next `## ` heading.
    private static func readmeSection(_ heading: String) throws -> String {
        let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let readme = package.appending(path: "../../README.md").standardized
        let lines = try String(contentsOf: readme, encoding: .utf8).components(separatedBy: "\n")
        let start = try #require(lines.firstIndex(of: heading))
        let rest = lines[(start + 1)...]
        let end = rest.firstIndex { $0.hasPrefix("## ") } ?? lines.endIndex
        return rest[..<end].joined(separator: "\n")
    }
    #endif
}
