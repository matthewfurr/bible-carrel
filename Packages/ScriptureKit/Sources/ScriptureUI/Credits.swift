import Foundation

/// One outside source the app uses: a translation, the headings, a typeface, the icon, the videos
/// or a piece of software, with the notice its holder asks for, its licence and a link. About
/// shows the catalogue in three sections, Scripture, Study data, and Typefaces, icon, videos and
/// software; nothing here says a text is used by permission.
public struct Credit: Identifiable, Hashable, Sendable {
    public enum Section: String, CaseIterable, Sendable {
        case scripture = "Scripture", studyData = "Study data", typefacesAndSoftware = "Typefaces, icon, videos and software"
    }

    public let id: String
    public let section: Section
    public let name: String
    public let use: String
    public let notice: String
    public let license: String
    public let link: URL
    /// The licence's text among the module's resources ("Fonts/OFL-Literata.txt"), when About shows it.
    public let licenseFile: String?
    public let translationID: String?
    /// The bundled font files' prefix ("Literata", "SourceSerif4").
    public let fontFamily: String?
    /// The licence's own page, when About shows the licence as a link.
    public var licenseLink: URL? = nil

    /// The words after the dot on About's line; nil for a Bible text, which says nothing more.
    public var shownUse: String? { use == "Bible text" ? nil : use }
}

public enum Credits {
    /// Every source, in the order About lists them within each section.
    public static let all: [Credit] = [
        Credit(
            id: "esv", section: .scripture,
            name: "English Standard Version", use: "Bible text",
            notice: "ESV® Bible (The Holy Bible, English Standard Version®), © 2001 by Crossway, a publishing ministry of Good News Publishers. All rights reserved. \"ESV\" and \"English Standard Version\" are registered trademarks of Crossway.",
            license: "Copyright", link: url("crossway.org/permissions"),
            licenseFile: nil, translationID: "ESV", fontFamily: nil
        ),
        Credit(
            id: "nasb", section: .scripture,
            name: "New American Standard Bible (1995)", use: "Bible text",
            notice: "New American Standard Bible®, Copyright © 1960, 1971, 1977, 1995 by The Lockman Foundation. All rights reserved. www.Lockman.org",
            license: "Copyright", link: url("lockman.org"),
            licenseFile: nil, translationID: "NASB", fontFamily: nil
        ),
        Credit(
            id: "amp", section: .scripture,
            name: "Amplified Bible, Classic Edition", use: "the file labelled AMP",
            notice: "Amplified® Bible Classic (AMPC), Copyright © 1954, 1958, 1962, 1964, 1965, 1987 by The Lockman Foundation. www.Lockman.org",
            license: "Copyright", link: url("lockman.org"),
            licenseFile: nil, translationID: "AMP", fontFamily: nil
        ),
        Credit(
            id: "erv", section: .scripture,
            name: "Easy-to-Read Version", use: "Bible text",
            notice: "HOLY BIBLE: EASY-TO-READ VERSION © Bible League International.",
            license: "Copyright", link: url("bibleleague.org/license-agreement"),
            licenseFile: nil, translationID: "ERV", fontFamily: nil
        ),
        Credit(
            id: "asv", section: .scripture,
            name: "American Standard Version (1901)", use: "Bible text",
            notice: "Public domain.",
            license: "Public domain", link: url("ebible.org/eng-asv"),
            licenseFile: nil, translationID: "ASV", fontFamily: nil
        ),
        Credit(
            id: "kjv", section: .scripture,
            name: "King James Version", use: "and its book titles",
            notice: "Public domain (Crown rights apply in the United Kingdom). Titles from the text \"courtesy of the Crosswire Bible Society and eBible.org\".",
            license: "Public domain", link: url("ebible.org/eng-kjv"),
            licenseFile: nil, translationID: "KJV", fontFamily: nil
        ),
        Credit(
            id: "web", section: .scripture,
            name: "World English Bible", use: "Bible text",
            notice: "Public domain. \"World English Bible\" is a trademark of eBible.org.",
            license: "Public domain", link: url("ebible.org/eng-web"),
            licenseFile: nil, translationID: "WEB", fontFamily: nil
        ),
        Credit(
            id: "cpdv", section: .scripture,
            name: "Catholic Public Domain Version", use: "Bible text",
            notice: "Original Edition. Ronald L. Conte Jr., translator and editor. Public domain.",
            license: "Public domain", link: url("sacredbible.org"),
            licenseFile: nil, translationID: "CPDV", fontFamily: nil
        ),
        Credit(
            id: "bsb", section: .studyData,
            name: "Berean Standard Bible", use: "section headings",
            notice: "The Holy Bible, Berean Standard Bible, BSB is produced in cooperation with Bible Hub, Discovery Bible, OpenBible.com, and the Berean Bible Translation Committee. This text of God's Word has been dedicated to the public domain.",
            license: "Public domain since 2023-04-30", link: url("berean.bible/terms.htm"),
            licenseFile: nil, translationID: nil, fontFamily: nil
        ),
        Credit(
            id: "openbible", section: .studyData,
            name: "OpenBible.info", use: "cross-references",
            notice: "Cross-references from OpenBible.info, CC BY 4.0, drawn chiefly from the Treasury of Scripture Knowledge. Changes: re-keyed to this app's verse table; links with no votes left out.",
            license: "CC BY 4.0", link: url("openbible.info/labs/cross-references"),
            licenseFile: nil, translationID: nil, fontFamily: nil,
            licenseLink: url("creativecommons.org/licenses/by/4.0/")
        ),
        Credit(
            id: "theographic", section: .studyData,
            name: "Theographic Bible Metadata", use: "people, places, events and dictionary entries",
            notice: LibraryCredit.text,
            license: "CC BY-SA 4.0", link: url("github.com/robertrouse/theographic-bible-metadata"),
            licenseFile: nil, translationID: nil, fontFamily: nil,
            licenseLink: url("creativecommons.org/licenses/by-sa/4.0/")
        ),
        Credit(
            id: "literata", section: .typefacesAndSoftware,
            name: "Literata", use: "reading typeface",
            notice: "Copyright 2017 The Literata Project Authors (https://github.com/googlefonts/literata)",
            license: "SIL OFL 1.1", link: url("github.com/googlefonts/literata"),
            licenseFile: "Fonts/OFL-Literata.txt", translationID: nil, fontFamily: "Literata"
        ),
        Credit(
            id: "sourceSerif4", section: .typefacesAndSoftware,
            name: "Source Serif 4", use: "reading typeface",
            notice: "Copyright 2014 - 2023 Adobe (http://www.adobe.com/), with Reserved Font Name ‘Source’. All Rights Reserved. Source is a trademark of Adobe in the United States and/or other countries.",
            license: "SIL OFL 1.1", link: url("github.com/adobe-fonts/source-serif"),
            licenseFile: "Fonts/OFL-SourceSerif4.txt", translationID: nil, fontFamily: "SourceSerif4"
        ),
        Credit(
            id: "3dicons", section: .typefacesAndSoftware,
            name: "3dicons", use: "the app icon's artwork",
            notice: "Icon artwork from 3dicons by Vijay Verma.",
            license: "CC0", link: url("3dicons.co"),
            licenseFile: nil, translationID: nil, fontFamily: nil
        ),
        Credit(
            id: "bibleProject", section: .typefacesAndSoftware,
            name: "BibleProject", use: "links to its book overview videos",
            notice: "Videos by BibleProject, at bibleproject.com.",
            license: "Linking permitted by its terms", link: url("bibleproject.com/terms"),
            licenseFile: nil, translationID: nil, fontFamily: nil
        ),
        Credit(
            id: "holybooks", section: .typefacesAndSoftware,
            name: "bobuk/holybooks", use: "the texts' file layout",
            notice: "Copyright (c) 2016, Grigory Bakunov. All rights reserved.",
            license: "BSD 3-Clause", link: url("github.com/bobuk/holybooks"),
            licenseFile: "Licenses/holybooks-LICENSE.txt", translationID: nil, fontFamily: nil
        ),
        Credit(
            id: "grdb", section: .typefacesAndSoftware,
            name: "GRDB.swift", use: "reading the Bible database",
            notice: "Copyright (C) 2015-2025 Gwendal Roué",
            license: "MIT", link: url("github.com/groue/GRDB.swift"),
            licenseFile: "Licenses/GRDB-LICENSE.txt", translationID: nil, fontFamily: nil
        ),
    ]

    public static func entries(in section: Credit.Section) -> [Credit] {
        all.filter { $0.section == section }
    }

    /// The text of `credit`'s licence file, or nil when it has none or the file is not there.
    public static func licenseText(for credit: Credit) -> String? {
        guard let path = credit.licenseFile, let root = Bundle.module.resourceURL else { return nil }
        return try? String(contentsOf: root.appending(path: path), encoding: .utf8)
    }

    /// The prefixes of the `.ttf` files in ScriptureUI's own `Fonts` folder (a test's `Bundle.module` is the test target's).
    public static func bundledFontFamilies() -> Set<String> {
        guard let fonts = Bundle.module.resourceURL?.appending(path: "Fonts"),
              let files = try? FileManager.default.contentsOfDirectory(at: fonts, includingPropertiesForKeys: nil)
        else { return [] }
        return Set(files.filter { $0.pathExtension == "ttf" }.compactMap {
            $0.deletingPathExtension().lastPathComponent.split(separator: "-").first.map(String.init)
        })
    }

    /// The appendix's addresses are written without the scheme.
    private static func url(_ address: String) -> URL {
        URL(string: "https://" + address)!
    }
}
