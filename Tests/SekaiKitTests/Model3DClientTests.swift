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
    func testPublishedArchivesDownloadDecodeAndCache() async throws {
        guard ProcessInfo.processInfo.environment["SEKAI_3D_INTEGRATION"] == "1" else {
            throw XCTSkip("Opt-in integration test downloads a few published model objects")
        }
        let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: cache) }
        let snapshot = ProcessInfo.processInfo.environment["SEKAI_3D_SNAPSHOT_REF"] ?? "main"
        let root = "https://raw.githubusercontent.com/Chorus-ACE/Sekai-3D-Assets/\(snapshot)"
        let client = Model3DClient(baseURL: URL(string: root + "/regions/")!, cacheURL: cache)
        for locale in SekaiLocale.allCases {
            let regional = try await client.catalog(for: locale)
            XCTAssertEqual(regional.region, locale)
            XCTAssertEqual(regional.schemaVersion, 1)
            XCTAssertFalse(try Model3DLibrary(catalog: regional).characters.isEmpty)
        }
        let catalog = try await client.catalog(for: .jp)
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
