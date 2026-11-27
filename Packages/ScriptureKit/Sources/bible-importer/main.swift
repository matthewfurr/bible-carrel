import BibleImporterCore
import Foundation

// Usage: bible-importer --source <dir containing EN/> --output <path> --commit <sha> [--ebible <dir>] [--crossrefs <file>] [--theographic <dir>]

let translationIDs = ["AMP", "ASV", "CPDV", "ERV", "ESV", "KJV", "NASB", "WEB"]

struct Options {
    var source: URL?
    var output: URL?
    var commit = "unknown"
    var ebible: URL?
    var crossReferences: URL?
    var theographic: URL?
}

func parseOptions() -> Options {
    var options = Options()
    var args = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = args.next() {
        switch arg {
        case "--source": options.source = args.next().map { URL(fileURLWithPath: $0) }
        case "--output": options.output = args.next().map { URL(fileURLWithPath: $0) }
        case "--ebible": options.ebible = args.next().map { URL(fileURLWithPath: $0) }
        case "--crossrefs": options.crossReferences = args.next().map { URL(fileURLWithPath: $0) }
        case "--theographic": options.theographic = args.next().map { URL(fileURLWithPath: $0) }
        case "--commit": options.commit = args.next() ?? options.commit
        default:
            FileHandle.standardError.write(Data("Unknown argument: \(arg)\n".utf8))
            exit(64)
        }
    }
    return options
}

struct IndexFile: Decodable {
    struct Version: Decodable { let ID: String; let title: String }
    let versions: [Version]
}

func stderr(_ line: String) {
    FileHandle.standardError.write(Data((line + "\n").utf8))
}

let options = parseOptions()
guard let source = options.source, let output = options.output else {
    stderr("Usage: bible-importer --source <dir containing EN/> --output <path> [--commit <sha>] [--ebible <dir containing engbsb_usfm/ and eng-kjv_usfm/>] [--crossrefs <cross_references.txt>] [--theographic <dir holding Theographic's five tables>]")
    exit(64)
}

do {
    let indexURL = source.appendingPathComponent("EN/index.json")
    let index = try JSONDecoder().decode(IndexFile.self, from: Data(contentsOf: indexURL))
    let titles = Dictionary(uniqueKeysWithValues: index.versions.map { ($0.ID, $0.title) })
    let translations = Dictionary(uniqueKeysWithValues: translationIDs.map { ($0, titles[$0] ?? $0) })

    let writer = try BibleDatabaseWriter(outputURL: output)
    let report = try writer.importAll(from: SourceTree(root: source), translations: translations, sourceCommit: options.commit, ebible: options.ebible, crossReferences: options.crossReferences, theographic: options.theographic)
    for warning in report.warnings {
        stderr("warning: \(warning.message)")
    }
    print("verses: \(report.verseCount), books: \(report.bookCount), links: \(report.crossReferenceCount), people: \(report.personCount), places: \(report.placeCount), events: \(report.eventCount), warnings: \(report.warnings.count)")
} catch {
    stderr("error: \(error)")
    exit(1)
}
