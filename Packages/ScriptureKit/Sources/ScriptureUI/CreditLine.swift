import Foundation

/// What one line of About's sources says and shows, apart from how it is drawn: its words, what
/// VoiceOver reads and what its opened row holds.
struct CreditLine: Equatable {
    enum Part: Equatable {
        case notice(String)
        case link(address: String, url: URL)
        case licenceText
        case licenceLink(name: String, url: URL)
    }

    let credit: Credit
    let name: String
    /// The words after the dot; nil for a Bible text.
    let use: String?
    let licence: String

    init(credit: Credit) {
        self.credit = credit
        name = credit.name
        use = credit.shownUse
        licence = credit.license
    }

    /// What follows the name when there is a use: " · " and the use, the dot held to the use by a
    /// no-break space, so a line that wraps breaks before the dot and never leaves it at a line's end.
    var afterName: String? { use.map { " \u{00B7}\u{00A0}\($0)" } }

    /// The name, the use when there is one and the licence, as VoiceOver reads the line.
    var spoken: String { [name, use, licence].compactMap { $0 }.joined(separator: ", ") }

    func value(isOpen: Bool) -> String { isOpen ? "Expanded" : "Collapsed" }

    /// The notice, the link, then the licence's text when it has a file, else the licence as a link.
    var opened: [Part] {
        var parts: [Part] = [.notice(credit.notice), .link(address: Self.address(credit.link), url: credit.link)]
        if Credits.licenseText(for: credit) != nil {
            parts.append(.licenceText)
        } else if let url = credit.licenseLink {
            parts.append(.licenceLink(name: credit.license, url: url))
        }
        return parts
    }

    /// A link's address as the catalogue writes it: no scheme, no trailing slash.
    static func address(_ url: URL) -> String {
        var path = url.path(percentEncoded: false)
        while path.hasSuffix("/") { path.removeLast() }
        return (url.host() ?? url.absoluteString) + path
    }
}
