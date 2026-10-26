import Foundation
import XCTest
@testable import SekaiKit
import CryptoKit

final class Model3DDeviceSourceTests: XCTestCase {
    func testPublishedCharacterPlansValidateMembershipAndHashes() async throws {
        guard let source = ProcessInfo.processInfo.environment["SEKAI_DEVICE_SOURCE_BASE_URL"] else {
            throw XCTSkip("Opt-in local HTTP fixture; never downloads source Bundles")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let client = Model3DDeviceSourceClient(baseURL: try XCTUnwrap(URL(string: source)), cacheDirectory: root)
        let catalog = try await client.catalog(for: .jp)
        XCTAssertEqual(catalog.region, .jp)
        XCTAssertFalse(catalog.characters.isEmpty)
        let scoped = try await client.parts(for: 1, in: catalog)
        let body = try XCTUnwrap(scoped.parts.first { $0.costumeID == 7002 && $0.type == .costume && $0.isReady })
        let plan = try await client.manifest(for: body, in: scoped)
        XCTAssertEqual(plan.parts.first?.id, body.id)
        XCTAssertEqual(plan.locale, .jp)
        // Cached immutable metadata is independently checked; damaged cache entries
        // must be fetched again and repaired, not returned to the importer.
        let reference = try XCTUnwrap(body.manifest)
        let cached = root.appendingPathComponent(reference.sha256 + ".json")
        try Data("damaged".utf8).write(to: cached)
        _ = try await client.manifest(for: body, in: scoped)
        let repaired = try Data(contentsOf: cached)
        XCTAssertEqual(SHA256.hash(data: repaired).map { String(format: "%02x", $0) }.joined(), reference.sha256)
        if let pending = scoped.parts.first(where: { !$0.isReady }) {
            do {
                _ = try await client.manifest(for: pending, in: scoped)
                XCTFail("A pending part must never cause a raw-resource download")
            } catch Model3DDeviceSourceClient.Failure.unavailablePart { }
        }
        // The same numeric part IDs in another region cannot borrow this JP plan.
        var wrong = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(scoped)) as? [String: Any])
        wrong["region"] = "en"
        let english = try JSONDecoder().decode(Model3DDevicePartCatalog.self, from: JSONSerialization.data(withJSONObject: wrong))
        do {
            _ = try await client.manifest(for: body, in: english)
            XCTFail("Cross-region import must be explicit")
        } catch Model3DDeviceSourceClient.Failure.incompatibleImporter { }
        // The SDK alone can consume a newly generated source plan and convert from
        // existing raw cache, without a bundled sample manifest or server exports.
        if let fixtures = ProcessInfo.processInfo.environment["SEKAI_RAW_BUNDLE_FIXTURES"] {
            let rawCache = root.appendingPathComponent("models/raw")
            try FileManager.default.createDirectory(at: rawCache, withIntermediateDirectories: true)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
            let bundles = try XCTUnwrap(json["bundles"] as? [String: [String: Any]])
            for (key, bundle) in bundles {
                let hash = try XCTUnwrap(bundle["sha256"] as? String)
                let data = try Data(contentsOf: URL(filePath: fixtures).appendingPathComponent(key + ".bundle"))
                try data.write(to: rawCache.appendingPathComponent(hash + ".bundle"))
            }
            let importer = Model3DDeviceClient(cacheDirectory: root.appendingPathComponent("models"))
            let result = try await importer.prepare(partID: body.id, manifest: plan)
            XCTAssertEqual(result.vertexCount, 6822)
            XCTAssertEqual(result.downloadedBytes, 0)
            let cached = try await importer.prepare(partID: body.id, manifest: plan)
            XCTAssertTrue(cached.cacheHit)
        }
    }
    func testOptionalPublishedRegionalCatalogs() async throws {
        guard ProcessInfo.processInfo.environment["SEKAI_DEVICE_PUBLISHED_PROBE"] == "1" else {
            throw XCTSkip("Opt-in published metadata probe; never downloads original Bundles")
        }
        let client = Model3DDeviceSourceClient()
        for locale in SekaiLocale.allCases {
            let root = try await client.catalog(for: locale)
            XCTAssertEqual(root.region, locale)
            let character = try XCTUnwrap(root.characters.first { $0.id == 1 })
            let parts = try await client.parts(for: character.id, in: root)
            XCTAssertEqual(parts.region, locale)
            XCTAssertEqual(parts.parts.count, character.partCount)
            if locale != .jp {
                XCTAssertFalse(parts.parts.contains(where: \.isReady))
                XCTAssertTrue(parts.parts.allSatisfy { $0.status == .unsupportedRegion })
            } else if let ready = parts.parts.first(where: \.isReady) {
                let plan = try await client.manifest(for: ready, in: parts)
                XCTAssertEqual(plan.parts.first?.id, ready.id)
            }
        }
    }
    func testUnknownPartCategoriesRemainDecodable() throws {
        let json = #"{"id":"x","name":"future","characterID":1,"costumeID":2,"type":"future_kind","status":"future_status"}"#
        let part = try JSONDecoder().decode(Model3DDevicePartCatalog.Part.self, from: Data(json.utf8))
        XCTAssertEqual(part.type, .unknown("future_kind"))
        XCTAssertEqual(part.status, .unknown("future_status"))
        XCTAssertFalse(part.isReady)
        let encoded = try JSONEncoder().encode(part)
        let roundtrip = try JSONDecoder().decode(Model3DDevicePartCatalog.Part.self, from: encoded)
        XCTAssertEqual(roundtrip.type.rawValue, "future_kind")
        XCTAssertEqual(roundtrip.status.rawValue, "future_status")
    }
    func testSourceReferenceCannotEscapeContentAddressedDirectory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let client = Model3DDeviceSourceClient(baseURL: URL(string: "https://invalid.example/")!, cacheDirectory: root)
        let json = #"{"schemaVersion":1,"region":"jp","revision":"r","sourceRevision":"s","importerRevision":"native-rest-pose-v1","counts":{},"characters":[{"id":1,"name":"A","readyCount":0,"partCount":0,"totalCount":0,"catalog":{"path":"../private","sha256":"bad","bytes":1}}]}"#
        let catalog = try JSONDecoder().decode(Model3DDeviceCatalog.self, from: Data(json.utf8))
        do {
            _ = try await client.parts(for: 1, in: catalog)
            XCTFail("Invalid references must fail before any network request")
        } catch Model3DDeviceSourceClient.Failure.invalidCatalog { }
    }
}
