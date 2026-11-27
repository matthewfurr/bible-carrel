// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ScriptureKit",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "ScriptureData", targets: ["ScriptureData"]),
        .library(name: "BibleImporterCore", targets: ["BibleImporterCore"]),
        .library(name: "ScriptureModel", targets: ["ScriptureModel"]),
        .library(name: "ScriptureLLM", targets: ["ScriptureLLM"]),
        .library(name: "ScriptureUI", targets: ["ScriptureUI"]),
        .executable(name: "bible-importer", targets: ["bible-importer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "ScriptureData",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
        .target(
            name: "BibleImporterCore",
            dependencies: ["ScriptureData", .product(name: "GRDB", package: "GRDB.swift")]
        ),
        .executableTarget(
            name: "bible-importer",
            dependencies: ["BibleImporterCore"]
        ),
        .testTarget(
            name: "ScriptureDataTests",
            dependencies: ["ScriptureData", "BibleImporterCore"],
            resources: [.copy("Fixtures")]
        ),
        .target(
            name: "ScriptureModel",
            dependencies: ["ScriptureData"]
        ),
        .testTarget(
            name: "ScriptureModelTests",
            dependencies: ["ScriptureModel"]
        ),
        .target(
            name: "ScriptureLLM",
            dependencies: ["ScriptureData", "ScriptureModel"]
        ),
        .testTarget(
            name: "ScriptureLLMTests",
            dependencies: ["ScriptureLLM"]
        ),
        .target(
            name: "ScriptureUI",
            dependencies: ["ScriptureData", "ScriptureModel", "ScriptureLLM"],
            resources: [.copy("Fonts"), .copy("Kernels"), .copy("Licenses")]
        ),
        .testTarget(
            name: "ScriptureUITests",
            dependencies: ["ScriptureUI", "BibleImporterCore"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "BibleImporterCoreTests",
            dependencies: ["BibleImporterCore"],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
