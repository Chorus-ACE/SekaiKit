import XCTest
@testable import SekaiKit

private final class RegionalIndexProtocol: URLProtocol {
    private final class Storage: @unchecked Sendable {
        let lock = NSLock()
        var status = 200
        var data = Data()
        var paths: [String] = []
    }
    private static let storage = Storage()
    static func configure(status: Int = 200, region: String) {
        storage.lock.withLock {
            storage.status = status
            storage.data = Data("{\"schemaVersion\":1,\"region\":\"\(region)\",\"revision\":\"r\",\"roles\":[],\"files\":{}}".utf8)
            storage.paths = []
        }
    }
    static var paths: [String] { storage.lock.withLock { storage.paths } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, data) = Self.storage.lock.withLock {
            Self.storage.paths.append(request.url!.path)
            return (Self.storage.status, Self.storage.data)
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}

final class Model3DRegionalRequestTests: XCTestCase {
    private func client() -> (Model3DClient, URLSession) {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RegionalIndexProtocol.self]
        let session = URLSession(configuration: config)
        return (Model3DClient(baseURL: URL(string: "https://models.example.test/regions/")!, session: session), session)
    }
    func testLibraryFetchesOnlyRequestedRegionalFile() async throws {
        RegionalIndexProtocol.configure(region: "en")
        let (client, session) = client()
        defer { session.invalidateAndCancel() }
        let library = try await client.library(for: .en)
        XCTAssertEqual(library.locale, .en)
        XCTAssertEqual(RegionalIndexProtocol.paths, ["/regions/en.json"])
    }
    func testFailedRegionDoesNotFetchMergedIndexOrFallbackRegion() async {
        RegionalIndexProtocol.configure(status: 503, region: "jp")
        let (client, session) = client()
        defer { session.invalidateAndCancel() }
        do { _ = try await client.library(for: .jp); XCTFail("Expected HTTP failure") } catch { }
        XCTAssertEqual(RegionalIndexProtocol.paths, ["/regions/jp.json"])
    }
    func testIndexRegionMustMatchRequestedRegion() async {
        RegionalIndexProtocol.configure(region: "en")
        let (client, session) = client()
        defer { session.invalidateAndCancel() }
        do { _ = try await client.library(for: .jp); XCTFail("Expected region mismatch") }
        catch { guard case Model3DClient.Failure.invalidManifest = error else { return XCTFail("\(error)") } }
        XCTAssertEqual(RegionalIndexProtocol.paths, ["/regions/jp.json"])
    }
}
