import Foundation
import XCTest
@testable import SekaiKit

final class Model3DLocalClientTests: XCTestCase {
    func testRegionalDirectoryAndNativeCharacterSelection() async throws {
        guard let base = ProcessInfo.processInfo.environment["SEKAI_LOCAL_VIEWER_BASE"] else { throw XCTSkip("Generated local metadata fixture") }
        let cache = FileManager.default.temporaryDirectory.appendingPathComponent("sekai-native-viewer-tests-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: cache) }
        let client = Model3DLocalClient(baseURL: try XCTUnwrap(URL(string: base)), cacheDirectory: cache)
        let locale = SekaiLocale(rawValue: ProcessInfo.processInfo.environment["SEKAI_LOCAL_VIEWER_REGION"] ?? "jp")!
        let library = try await client.library(for: locale)
        XCTAssertEqual(library.roles.count, 31)
        let wardrobe = try await client.wardrobe(for: ProcessInfo.processInfo.environment["SEKAI_LOCAL_VIEWER_ROLE"] ?? "1:light_sound", in: library)
        let character = wardrobe.character
        XCTAssertEqual(character.locale, locale)
        XCTAssertGreaterThan(character.costumes.count, 100)
        XCTAssertGreaterThan(character.hairstyles.count, 5)
        XCTAssertGreaterThan(character.accessories.count, 100)
        XCTAssertNotNil(character.defaultSelection())
        let initial = try XCTUnwrap(character.defaultSelection())
        let wrongRegion = Model3DSelection(locale: locale == .jp ? .en : .jp, characterID: initial.characterID, costumeID: initial.costumeID, hairstyleID: initial.hairstyleID)
        do {
            _ = try await client.prepare(wrongRegion, in: wardrobe)
            XCTFail("Cross-region selection must fail before raw resource access")
        } catch Model3DLibrary.Failure.wrongLocale { }
        let reference = try XCTUnwrap(library.roles.first(where: { $0.id == character.id })).catalog
        try Data("damaged".utf8).write(to: cache.appendingPathComponent("metadata/" + reference.sha256 + ".json"))
        let repaired = try await client.wardrobe(for: character.id, in: library)
        XCTAssertEqual(repaired.character.costumes.count, character.costumes.count)
        guard ProcessInfo.processInfo.environment["SEKAI_LOCAL_VIEWER_DOWNLOAD"] == "1" else { return }
        // Explicitly bounded experiment: one default character and one existing
        // known wardrobe sample. There is no full-wardrobe download loop.
        let selection = try XCTUnwrap(character.defaultSelection())
        let result = try await client.prepare(selection, in: wardrobe)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(result.recipeJSON.utf8)) as? [String: Any])
        let parts = try XCTUnwrap(json["parts"] as? [[String: Any]])
        XCTAssertEqual(parts.count, selection.accessoryID == nil ? 2 : 3)
        var vertices = 0, motions = 0
        let output = ProcessInfo.processInfo.environment["SEKAI_LOCAL_VIEWER_OUTPUT"].map { URL(filePath: $0) }
        if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true); try Data(result.recipeJSON.utf8).write(to: output.appendingPathComponent("recipe.json")) }
        for part in parts {
            let url = try XCTUnwrap(URL(string: try XCTUnwrap(part["sceneURL"] as? String)))
            let path = String(url.path.dropFirst())
            let data = try await client.resource(at: path, in: result)
            let scene = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let meshes = try XCTUnwrap(scene["meshes"] as? [[String: Any]])
            vertices += meshes.reduce(0) { $0 + (($1["positions"] as? [Double])?.count ?? 0)/3 }
            motions += (scene["animationClips"] as? [Any])?.count ?? 0
            if let output {
                let target = output.appendingPathComponent(path)
                try FileManager.default.createDirectory(at: target.deletingLastPathComponent().appendingPathComponent("textures"), withIntermediateDirectories: true)
                try data.write(to: target)
                for material in (scene["materials"] as? [[String: Any]]) ?? [] {
                    for texture in (material["textures"] as? [String: String] ?? [:]).values {
                        let relative = url.deletingLastPathComponent().appendingPathComponent(texture).path
                        let image = try await client.resource(at: String(relative.dropFirst()), in: result)
                        try image.write(to: output.appendingPathComponent(String(relative.dropFirst())))
                    }
                }
            }
        }
        XCTAssertGreaterThan(vertices, 1000)
        XCTAssertGreaterThan(motions, 0)
        let hot = try await client.prepare(selection, in: wardrobe)
        XCTAssertEqual(hot.recipeJSON, result.recipeJSON)
        if ProcessInfo.processInfo.environment["SEKAI_LOCAL_VIEWER_HEAD_TEST"] == "1" {
            var complete = selection
            complete.accessoryID = try XCTUnwrap(character.accessories.flatMap(\.variants).first(where: \.includesHairstyle)).id
            let head = try await client.prepare(complete, in: wardrobe)
            XCTAssertTrue(head.hairstyleIsLocked)
            if let output { try head.recipeJSON.write(to: output.appendingPathComponent("head-recipe.json"), atomically: true, encoding: .utf8) }
            let headRecipe = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(head.recipeJSON.utf8)) as? [String:Any])
            for part in try XCTUnwrap(headRecipe["parts"] as? [[String:Any]]) {
                let url = try XCTUnwrap(URL(string: try XCTUnwrap(part["sceneURL"] as? String)))
                let path = String(url.path.dropFirst())
                let data = try await client.resource(at: path, in: head)
                let scene = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String:Any])
                XCTAssertFalse((scene["meshes"] as? [Any] ?? []).isEmpty)
                if let output {
                    let target = output.appendingPathComponent(path)
                    try FileManager.default.createDirectory(at: target.deletingLastPathComponent().appendingPathComponent("textures"), withIntermediateDirectories: true)
                    try data.write(to: target)
                    for material in scene["materials"] as? [[String:Any]] ?? [] {
                        for texture in (material["textures"] as? [String:String] ?? [:]).values {
                            let relative = String(url.deletingLastPathComponent().appendingPathComponent(texture).path.dropFirst())
                            let image = try await client.resource(at: relative, in: head)
                            try image.write(to: output.appendingPathComponent(relative))
                        }
                    }
                }
            }
        }
        print("LOCAL CHARACTER", character.id, "VERTICES", vertices, "ANIMATION CLIPS", motions)
    }

    func testAllPublishedRegionsHaveIndependentWardrobes() async throws {
        guard let base = ProcessInfo.processInfo.environment["SEKAI_LOCAL_VIEWER_BASE"], base.hasPrefix("https:") else { throw XCTSkip("Opt-in published regional metadata") }
        let client = Model3DLocalClient(baseURL: try XCTUnwrap(URL(string: base)))
        for locale in [SekaiLocale.jp, .en, .tw, .kr, .cn] {
            let library = try await client.library(for: locale)
            let wardrobe = try await client.wardrobe(for: "1:light_sound", in: library)
            XCTAssertEqual(wardrobe.region, locale)
            XCTAssertEqual(wardrobe.character.locale, locale)
            XCTAssertNotNil(wardrobe.character.defaultSelection())
            print("REGIONAL WARDROBE", locale.rawValue, library.roles.count, wardrobe.character.costumes.count, wardrobe.character.hairstyles.count, wardrobe.character.accessories.count)
        }
    }
}
