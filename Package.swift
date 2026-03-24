// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

// swift-tools-version: 5.9
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SekaiKit",
    platforms: [
        .iOS(.v17), .macCatalyst(.v17), .macOS(.v14), .visionOS("1.1"), .watchOS(.v10)
    ],
    products: [
        .library(name: "SekaiKit", targets: ["SekaiKit"]),
        // 建议将宏公开为一个 Product，方便外部使用
        .library(name: "SekaiKitMacro", targets: ["SekaiKitMacro"])
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.10.2"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON", from: "5.0.2"),
        .package(url: "https://github.com/swift-library/swift-gyb", from: "0.0.1"),
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
    ],
    targets: [
        .target(
            name: "SekaiKit",
            dependencies: [
                "Alamofire",
                "SwiftyJSON",
                "SekaiKitMacro"
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

        .target(
            name: "SekaiKitMacro",
            dependencies: ["SekaiKitMacroMacros"],
            path: "SekaiKitMacro/",
        ),

        .macro(
            name: "SekaiKitMacroMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ],
            path: "SekaiKitMacroMacros/",
        ),

//        .testTarget(
//            name: "SekaiKitMacroTests",
//            dependencies: [
//                "SekaiKitMacroMacros",
//                .product(name: "SwiftMacrosTestSupport", package: "swift-syntax"),
//            ]
//        ),
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
