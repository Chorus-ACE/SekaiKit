// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SekaiKit",
    platforms: [.iOS(.v17), .macCatalyst(.v17), .macOS(.v14), .visionOS("1.1"), .watchOS(.v10)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SekaiKit",
            targets: ["SekaiKit"]
        ),
    ], dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.10.2"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON", from: "5.0.2"),
        .package(url: "https://github.com/swift-library/swift-gyb", from: "0.0.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SekaiKit",
            dependencies: [
                "Alamofire",
                "SwiftyJSON",
            ],
            path: "SekaiKit/",
            resources: [
                .process("Localizable.xcstrings"),
                .process("Resources")
            ],
            plugins: [
                .plugin(name: "Gyb", package: "swift-gyb")
            ]
        ),
    ]
)

/*

// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "DoriKit",
    platforms: [.iOS(.v17), .macCatalyst(.v17), .macOS(.v14), .visionOS(.v1), .watchOS(.v10)],
    products: [
        .library(name: "DoriKit", type: .dynamic, targets: ["DoriKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.10.2"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON", from: "5.0.2"),
        .package(url: "https://github.com/swift-library/swift-gyb", from: "0.0.1"),
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "601.0.1")
    ],
    targets: [
        .target(
            name: "DoriKit",
            dependencies: [
                "Alamofire",
                "SwiftyJSON",
                "DoriKitMacros",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftOperators", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftParserDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftLexicalLookup", package: "swift-syntax"),
                .product(name: "SwiftIDEUtils", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax")
            ],
            path: "DoriKit/",
            resources: [
                .process("Localizable.xcstrings")
            ],
            swiftSettings: [
                .unsafeFlags(["-enable-experimental-feature", "SymbolLinkageMarkers"]),
                .unsafeFlags(["-enable-experimental-feature", "BuiltinModule"]),
                .unsafeFlags(["-enable-experimental-feature", "ClosureBodyMacro"])
            ],
            plugins: [
                .plugin(name: "Gyb", package: "swift-gyb")
            ]
        ),
        .macro(
            name: "DoriKitMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax")
            ],
            path: "DoriKitMacros/"
        )
    ]
)

*/
