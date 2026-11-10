import Foundation
import XCTest
@testable import SekaiKit

final class CacheBehaviorTests: XCTestCase {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func seed(_ directory: URL, updated: TimeInterval? = nil) throws {
        try [1].dataForCache.write(to: directory.appending(path: "SekaiKit_Array<Int>_test.cache"))
        if let updated {
            try PropertyListEncoder().encode(["Array<Int>_test": updated]).write(
                to: directory.appending(path: "SekaiCacheInfo.plist")
            )
        }
    }

    private func dates(_ directory: URL) throws -> [String: TimeInterval] {
        try PropertyListDecoder().decode([String: TimeInterval].self, from:
            Data(contentsOf: directory.appending(path: "SekaiCacheInfo.plist")))
    }

    func testRealTimeFailureFallsBackToCacheAndFinishes() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try seed(directory)
        let done = expectation(description: "Failed origin completes with cached data")
        let task = Task {
            await SekaiCache.$cacheDirectory.withValue(directory) {
                let result: [Int]? = await SekaiCache.withDirectCache(id: "test", trait: .realTime) { nil }
                XCTAssertEqual(result, [1])
                done.fulfill()
            }
        }
        await fulfillment(of: [done], timeout: 2)
        task.cancel()
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appending(path: "SekaiCacheInfo.plist").path))
    }

    func testFailedRefreshDoesNotRenewExpiryAndNextLoadRetries() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let expired = Date.now.timeIntervalSince1970 - 48 * 60 * 60
        try seed(directory, updated: expired)
        await SekaiCache.$cacheDirectory.withValue(directory) {
            for _ in 0..<2 {
                let attempted = expectation(description: "Expired cache triggers origin")
                let result: [Int]? = await SekaiCache.withDirectCache(id: "test") {
                    attempted.fulfill()
                    return nil
                }
                XCTAssertEqual(result, [1])
                await fulfillment(of: [attempted], timeout: 2)
            }
        }
        XCTAssertEqual(try dates(directory)["Array<Int>_test"], expired)
    }

    func testSuccessfulRefreshPersistsValueAndFreshness() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try seed(directory)
        await SekaiCache.$cacheDirectory.withValue(directory) {
            let refreshed: [Int]? = await SekaiCache.withDirectCache(id: "test", trait: .realTime) { [2] }
            XCTAssertEqual(refreshed, [2])
            let cached: [Int]? = await SekaiCache.withDirectCache(id: "test") {
                XCTFail("Fresh cache must skip origin")
                return nil
            }
            XCTAssertEqual(cached, [2])
        }
        XCTAssertGreaterThan(try XCTUnwrap(dates(directory)["Array<Int>_test"]), Date.now.timeIntervalSince1970 - 5)
    }

    func testConcurrentSuccessfulWritesRetainAllTimestamps() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        await SekaiCache.$cacheDirectory.withValue(directory) {
            await withTaskGroup(of: Void.self) { group in
                for id in 0..<20 {
                    group.addTask {
                        let value: [Int]? = await SekaiCache.withDirectCache(id: "item-\(id)", trait: .realTime) { [id] }
                        XCTAssertEqual(value, [id])
                    }
                }
            }
        }
        XCTAssertEqual(try dates(directory).count, 20)
    }

    @MainActor
    func testPromiseDeliversCacheThenFreshOrigin() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try seed(directory)
        let done = expectation(description: "Cache and origin both delivered")
        done.expectedFulfillmentCount = 2
        var updates: [[Int]?] = []
        let promise = SekaiCache.$cacheDirectory.withValue(directory) {
            SekaiCache.withCache(id: "test", trait: .realTime) { [2] }
                .onUpdate { value, _ in
                    updates.append(value)
                    done.fulfill()
                }
        }
        defer { promise.cancel() }
        await fulfillment(of: [done], timeout: 2)
        XCTAssertEqual(updates, [[1], [2]])
        XCTAssertNotNil(try dates(directory)["Array<Int>_test"])
    }

    func testCancellationDoesNotPersistAnOriginResult() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let started = expectation(description: "Origin started")
        let gate = CacheTestGate()
        let task = Task {
            await SekaiCache.$cacheDirectory.withValue(directory) {
                await SekaiCache.withDirectCache(id: "test", trait: .realTime) {
                    started.fulfill()
                    await gate.wait() // Deliberately ignores task cancellation.
                    return [2]
                }
            }
        }
        await fulfillment(of: [started], timeout: 2)
        task.cancel()
        await gate.open()
        let result = await task.value
        XCTAssertNil(result)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    func testPreloadPublishesToConcurrentReadersAndRejectsOtherURLs() async {
        let url = URL(string: "https://preload.test/source")!
        let gate = CacheTestGate()
        let descriptor = SekaiCache.preload {
            await gate.wait()
            SekaiCache._finishedLoadSource?(url, Data([7]))
            return 7
        }
        async let first = descriptor.sourceData(for: url)
        async let second = descriptor.sourceData(for: url)
        await gate.open()
        let values = await [first, second]
        XCTAssertEqual(values, [Data([7]), Data([7])])
        let mismatch = await descriptor.sourceData(for: url.appending(path: "other"))
        XCTAssertNil(mismatch)
    }

    func testPreloadCompletionWithoutSourceReturnsImmediately() async {
        let descriptor = SekaiCache.preload { Optional<Int>.none }
        _ = await descriptor.value
        let done = expectation(description: "No source completes without waiting for timeout")
        let task = Task {
            let data = await descriptor.sourceData(for: URL(string: "https://preload.test/missing")!)
            XCTAssertNil(data)
            done.fulfill()
        }
        await fulfillment(of: [done], timeout: 1)
        task.cancel()
    }

    func testPreloadTimeoutAndCancelledReaderDoNotAffectOtherReaders() async {
        let url = URL(string: "https://preload.test/slow")!
        let gate = CacheTestGate()
        let descriptor = SekaiCache.preload {
            await gate.wait()
            SekaiCache._finishedLoadSource?(url, Data([8]))
            return 8
        }
        let timedOut = await descriptor.sourceData(for: url, timeout: .milliseconds(20))
        XCTAssertNil(timedOut)
        let done = expectation(description: "Cancelled reader completes")
        let task = Task {
            let data = await descriptor.sourceData(for: url)
            XCTAssertNil(data)
            done.fulfill()
        }
        task.cancel()
        await fulfillment(of: [done], timeout: 1)
        await gate.open()
        let value = await descriptor.value
        XCTAssertEqual(value, 8)
        let data = await descriptor.sourceData(for: url)
        XCTAssertEqual(data, Data([8]))
    }

    func testReleasedPreloadCanFinishSafelyAfterIgnoringCancellation() async {
        let gate = CacheTestGate()
        let started = expectation(description: "Preload started")
        let finished = expectation(description: "Cancelled producer safely publishes")
        var descriptor: SekaiCache.PreloadDescriptor<Int>? = SekaiCache.preload {
            started.fulfill()
            await gate.wait()
            SekaiCache._finishedLoadSource?(URL(string: "https://preload.test/released")!, Data([9]))
            finished.fulfill()
            return 9
        }
        weak let released = descriptor
        await fulfillment(of: [started], timeout: 2)
        descriptor = nil
        XCTAssertNil(released)
        await gate.open()
        await fulfillment(of: [finished], timeout: 2)
    }
}

private actor CacheTestGate {
    private var isOpen = false
    private var waiter: CheckedContinuation<Void, Never>?

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func open() {
        isOpen = true
        waiter?.resume()
        waiter = nil
    }
}
