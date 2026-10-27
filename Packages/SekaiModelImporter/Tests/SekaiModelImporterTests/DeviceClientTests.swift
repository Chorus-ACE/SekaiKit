import XCTest
@testable import SekaiModelImporter

final class DeviceClientTests: XCTestCase {
    func testSignatureCookieParsingKeepsAllThreePairsAndNoAttributes() throws {
        for separator in ["; ", ", "] {
            let header = "CloudFront-Policy=policy; Path=/; Expires=Wed, 28 Oct 2026 00:00:00 GMT" + separator + "CloudFront-Signature=signature" + separator + "CloudFront-Key-Pair-Id=key"
            XCTAssertEqual(try DeviceModelClient.signatureCookieHeader(header), "CloudFront-Policy=policy; CloudFront-Signature=signature; CloudFront-Key-Pair-Id=key")
        }
        XCTAssertThrowsError(try DeviceModelClient.signatureCookieHeader("CloudFront-Policy=only-one"))
        XCTAssertThrowsError(try DeviceModelClient.signatureCookieHeader(""))
    }
    func testSampleManifestRejectsUntrustedOriginAndMissingDependencies() throws {
        let manifest = try DeviceModelSourceManifest.japaneseSamples()
        XCTAssertNoThrow(try manifest.validate())
        let data = try JSONEncoder().encode(manifest)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["assetBaseURL"] = "https://example.com/android/"
        let unsafe = try JSONDecoder().decode(DeviceModelSourceManifest.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertThrowsError(try unsafe.validate())
        json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]); json["bundles"] = [:]
        let missing = try JSONDecoder().decode(DeviceModelSourceManifest.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertThrowsError(try missing.validate())
    }
    func testCachedRawBundlesConvertWithoutNetworkAndCorruptDerivedCacheRebuilds() async throws {
        guard let fixtures = ProcessInfo.processInfo.environment["SEKAI_RAW_BUNDLE_FIXTURES"] else { throw XCTSkip("Opt-in local resource test") }
        let manifest = try DeviceModelSourceManifest.japaneseSamples()
        let root = FileManager.default.temporaryDirectory.appending(path: "sekai-native-test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appending(path: "raw"), withIntermediateDirectories: true)
        for (key, record) in manifest.bundles {
            try Data(contentsOf: URL(filePath: fixtures).appending(path: key + ".bundle")).write(to: root.appending(path: "raw/" + (try XCTUnwrap(record.sha256)) + ".bundle"))
        }
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [NoNetwork.self]
        let client = DeviceModelClient(cacheDirectory: root, session: URLSession(configuration: config))
        let cold = try await client.prepare(partID: "body-7002", manifest: manifest)
        XCTAssertFalse(cold.cacheHit); XCTAssertEqual(cold.downloadedBytes, 0); XCTAssertEqual(cold.vertexCount, 6822)
        let hot = try await client.prepare(partID: "body-7002", manifest: manifest)
        XCTAssertTrue(hot.cacheHit); XCTAssertEqual(hot.directory, cold.directory); XCTAssertEqual(hot.downloadedBytes, 0)
        var unrelated = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(manifest)) as? [String: Any])
        unrelated["sourceRevision"] = "metadata-only-update"
        var parts = try XCTUnwrap(unrelated["parts"] as? [[String: Any]])
        parts[1]["name"] = "Unrelated name change"; unrelated["parts"] = parts
        let revised = try JSONDecoder().decode(DeviceModelSourceManifest.self, from: JSONSerialization.data(withJSONObject: unrelated))
        let unaffected = try await client.prepare(partID: "body-7002", manifest: revised)
        XCTAssertTrue(unaffected.cacheHit); XCTAssertEqual(unaffected.directory, cold.directory)
        try Data("broken".utf8).write(to: cold.directory.appending(path: "scene.json"))
        let repaired = try await client.prepare(partID: "body-7002", manifest: manifest)
        XCTAssertFalse(repaired.cacheHit); XCTAssertEqual(repaired.downloadedBytes, 0)
        print("DEVICE PIPELINE COLD/HOT", cold.elapsedSeconds, hot.elapsedSeconds, "CACHE BYTES", cold.convertedBytes)
    }
    func testOptionalSmallOfficialDownload() async throws {
        guard ProcessInfo.processInfo.environment["SEKAI_RAW_NETWORK_PROBE"] == "1" else { throw XCTSkip("Explicitly opt in to one small official download") }
        let folder = FileManager.default.temporaryDirectory.appending(path: "sekai-native-network-probe")
        let client = DeviceModelClient(cacheDirectory: folder)
        let result = try await client.prepare(partID: "body-7002", manifest: .japaneseSamples())
        XCTAssertEqual(result.vertexCount, 6822)
        print("OFFICIAL RAW DOWNLOAD", result.downloadedBytes, "TOTAL SECONDS", result.elapsedSeconds, "CONVERTED", result.directory.path)
    }
}
private final class NoNetwork: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { XCTFail("Unexpected network request: \(request.url?.host ?? "")"); client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}
