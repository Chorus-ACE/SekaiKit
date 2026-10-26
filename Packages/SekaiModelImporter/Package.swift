// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "SekaiModelImporter",
    platforms: [.iOS(.v17), .macOS(.v14), .macCatalyst(.v17), .visionOS(.v1), .watchOS(.v10)],
    products: [.library(name: "SekaiModelImporter", targets: ["SekaiModelImporter"])],
    targets: [
        .target(name: "CTextureDecoder", publicHeadersPath: "include", cxxSettings: [.headerSearchPath("vendor")]),
        .target(name: "SekaiModelImporter", dependencies: ["CTextureDecoder"], resources: [.process("Resources")]),
        .testTarget(name: "SekaiModelImporterTests", dependencies: ["SekaiModelImporter"])
    ],
    cxxLanguageStandard: .cxx14
)
