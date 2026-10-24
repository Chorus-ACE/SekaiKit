import XCTest
@testable import SekaiKit

final class Model3DClientTests: XCTestCase {
    func testResourcePathsCannotEscapeCacheNamespace() {
        for path in ["", "/absolute", "../file", "a/../file", "a//file", "a\\file", "a/./file"] {
            XCTAssertFalse(Model3DClient.validPath(path), path)
        }
        XCTAssertTrue(Model3DClient.validPath("parts/_cores/body/hash/part-runtime-core.msgpack.br"))
    }
    func testRegionalArchivePreservesMissingColorLabels() throws {
        let data = Data(#"{"id":"x","costumeID":1,"type":"body","name":"衣服","colorName":null}"#.utf8)
        let part = try JSONDecoder().decode(Model3DCatalog.Part.self, from: data)
        XCTAssertNil(part.colorName)
        XCTAssertEqual(part.name, "衣服")
    }
    func testRegionalManifestKeepsPublishedDefaultsAndUnknownPartTypes() throws {
        let data = Data(#"{"schemaVersion":1,"region":"tw","revision":"abc","files":{},"roles":[{"id":"1:light_sound","characterId":1,"unit":"light_sound","bodyCostume3dId":2,"headCostume3dId":1,"hairCostume3dId":201,"parts":[{"id":"new","costumeID":123,"type":"future_part","name":"衣服","colorName":"通常"}]}]}"#.utf8)
        let catalog = try JSONDecoder().decode(Model3DCatalog.self, from: data)
        XCTAssertEqual(catalog.region, .tw)
        XCTAssertEqual(catalog.roles.first?.hairCostumeID, 201)
        XCTAssertEqual(catalog.roles.first?.parts.first?.type, "future_part")
    }
    private func mergedFixture() throws -> Model3DWardrobe {
        let a = String(repeating: "a", count: 64), b = String(repeating: "b", count: 64)
        func object(_ hash: String) -> [String: Any] {
            ["sha256": hash, "bytes": 1, "archiveBytes": 100, "url": "https://github.com/Chorus-ACE/Sekai-3D-Assets/releases/download/objects-" + hash.prefix(3) + "/" + hash + ".aar"]
        }
        func part(_ id: String, locales: [String]) -> [String: Any] {
            ["id": id, "costumeID": id == "exclusive" ? 9 : 201, "type": id == "exclusive" ? "body" : "hair", "name": ["jp": "衣装", "en": "Outfit"], "colorName": ["jp": "", "en": "Normal"], "locales": locales]
        }
        let source: [String: Any] = [
            "schemaVersion": 2, "revision": "merged", "regions": ["jp": ["revision": "jp1"], "en": ["revision": "en1"]],
            "roles": [["id": "1:u", "characterId": 1, "unit": "u", "name": ["jp": "一歌", "en": "Ichika"],
                       "defaults": ["jp": ["bodyCostume3dId": 2, "headCostume3dId": 1, "hairCostume3dId": 201], "en": ["bodyCostume3dId": 4, "headCostume3dId": 1, "hairCostume3dId": 201]],
                       "parts": [part("exclusive", locales: ["jp"]), part("shared", locales: ["jp", "en"]), part("enOnly", locales: ["en"])]]],
            "objects": [a: object(a), b: object(b)],
            "files": ["core.br": [["object": a, "locales": ["jp"]], ["object": b, "locales": ["en"]]], "jp-only.br": [["object": a, "locales": ["jp"]]]]
        ]
        return try JSONDecoder().decode(Model3DWardrobe.self, from: JSONSerialization.data(withJSONObject: source))
    }
    func testMergedWardrobePreservesTranslationsExclusivesAndRegionalResourceVariants() throws {
        let wardrobe = try mergedFixture()
        XCTAssertEqual(wardrobe.roles.count, 1)
        XCTAssertEqual(wardrobe.roles[0].name[.en], "Ichika")
        XCTAssertEqual(wardrobe.roles[0].parts[0].colorName[.jp], "")
        let en = try wardrobe.catalog(for: .en), jp = try wardrobe.catalog(for: .jp)
        XCTAssertEqual(en.roles[0].bodyCostumeID, 4)
        XCTAssertEqual(jp.roles[0].bodyCostumeID, 2)
        XCTAssertFalse(en.roles[0].parts.contains { $0.id == "exclusive" })
        XCTAssertNotEqual(en.files["core.br"]?.sha256, jp.files["core.br"]?.sha256)
        XCTAssertNil(en.files["jp-only.br"])
    }
    func testMergedSelectionUsesOneCompleteSourceAndRejectsIncompatiblePieces() throws {
        let wardrobe = try mergedFixture()
        XCTAssertEqual(wardrobe.preferredLocale(for: "1:u", requiring: ["shared"], prefer: .en), .en)
        XCTAssertEqual(wardrobe.preferredLocale(for: "1:u", requiring: ["exclusive", "shared"], prefer: .en), .jp)
        XCTAssertNil(wardrobe.preferredLocale(for: "1:u", requiring: ["exclusive", "enOnly"]))
        XCTAssertNil(wardrobe.preferredLocale(for: "1:u", requiring: ["unknown"]))
    }
    func testPublishedArchivesDownloadDecodeAndCache() async throws {
        guard ProcessInfo.processInfo.environment["SEKAI_3D_INTEGRATION"] == "1" else {
            throw XCTSkip("Opt-in integration test downloads a few published model objects")
        }
        let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: cache) }
        let snapshot = ProcessInfo.processInfo.environment["SEKAI_3D_SNAPSHOT_REF"] ?? "main"
        let root = "https://raw.githubusercontent.com/Chorus-ACE/Sekai-3D-Assets/\(snapshot)"
        let client = Model3DClient(cacheURL: cache, wardrobeURL: URL(string: root + "/catalog.json"))
        let live = try await Model3DClient.shared.wardrobe()
        XCTAssertEqual(live.schemaVersion, 2)
        XCTAssertFalse(live.roles.isEmpty)
        let wardrobe = try await client.wardrobe()
        XCTAssertEqual(wardrobe.schemaVersion, 2)
        XCTAssertEqual(wardrobe.regions.allAvailableLocales.count, 5)
        // The merged projection must preserve every published regional resource exactly.
        for locale in SekaiLocale.allCases {
            let url = URL(string: root + "/regions/\(locale.rawValue).json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let original = try JSONDecoder().decode(Model3DCatalog.self, from: data)
            let projection = try wardrobe.catalog(for: locale)
            XCTAssertEqual(Set(projection.roles.map(\.id)), Set(original.roles.map(\.id)))
            XCTAssertEqual(projection.files.count, original.files.count)
            for (path, reference) in original.files {
                XCTAssertEqual(projection.files[path]?.sha256, reference.sha256)
                XCTAssertEqual(projection.files[path]?.archiveBytes, reference.archiveBytes)
                XCTAssertEqual(projection.files[path]?.bytes, reference.bytes)
                XCTAssertEqual(projection.files[path]?.url, reference.url)
            }
        }
        let catalog = try wardrobe.catalog(for: .jp)
        XCTAssertFalse(catalog.roles.isEmpty)
        for prefix in ["parts/by-role/", "parts/_cores/", "_texture_store/"] {
            let path = try XCTUnwrap(catalog.files.keys.sorted().first(where: { $0.hasPrefix(prefix) }))
            let reference = try XCTUnwrap(catalog.files[path])
            let downloaded = try await client.resource(at: path, in: catalog)
            XCTAssertEqual(downloaded.count, reference.bytes)
            let cached = try await client.resource(at: path, in: catalog)
            XCTAssertEqual(cached, downloaded)
            XCTAssertEqual(try Data(contentsOf: cache.appendingPathComponent(reference.sha256)), downloaded)
        }
    }

}
