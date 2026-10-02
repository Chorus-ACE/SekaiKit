import Foundation
import XCTest
@testable import SekaiKit

final class ProtobufDownloadTests: XCTestCase {
    func testConcurrentReadersShareDownloadButLaterReadsRefresh() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ProtobufURLProtocol.self]
        let downloads = ProtobufDownloads(session: URLSession(configuration: config))
        let url = URL(string: "https://protobuf.test/\(UUID().uuidString)")!
        async let first = downloads.data(from: url)
        async let second = downloads.data(from: url)
        let results = await [first, second]
        XCTAssertEqual(results, [Data([1, 2, 3]), Data([1, 2, 3])])
        XCTAssertEqual(ProtobufURLProtocol.count(for: url), 1)
        let refreshed = await downloads.data(from: url)
        XCTAssertNotNil(refreshed)
        XCTAssertEqual(ProtobufURLProtocol.count(for: url), 2)
    }

    func testHTTPFailureIsRejectedAndRetried() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ProtobufURLProtocol.self]
        let downloads = ProtobufDownloads(session: URLSession(configuration: config))
        let url = URL(string: "https://protobuf.test/missing/\(UUID().uuidString)")!
        let first = await downloads.data(from: url)
        let second = await downloads.data(from: url)
        XCTAssertNil(first)
        XCTAssertNil(second)
        XCTAssertEqual(ProtobufURLProtocol.count(for: url), 2)
    }
}

private final class ProtobufURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var counts: [URL: Int] = [:]

    static func count(for url: URL) -> Int {
        lock.withLock { counts[url, default: 0] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        Self.lock.withLock { Self.counts[url, default: 0] += 1 }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            let response = HTTPURLResponse(url: url, statusCode: url.path.contains("missing") ? 404 : 200, httpVersion: nil, headerFields: nil)!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: Data([1, 2, 3]))
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
