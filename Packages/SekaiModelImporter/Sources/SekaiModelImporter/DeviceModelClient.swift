import CryptoKit
import Foundation

public struct DeviceModelResult: Sendable {
    public let directory: URL
    public let cacheHit: Bool
    public let downloadedBytes: Int
    public let convertedBytes: Int
    public let vertexCount: Int
    public let conversionSeconds: Double
    public let elapsedSeconds: Double
}

/// One bounded conversion at a time; raw and converted data have separate hash caches.
public actor DeviceModelClient {
    public static let shared = DeviceModelClient()
    private let root: URL
    private let session: URLSession
    private let maximumCacheBytes: Int
    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private struct RawReceipt: Codable { let bytes: Int; let sha256: String }
    private struct Receipt: Codable {
        let resources: [String: String]
        let vertexCount: Int
        let conversionSeconds: Double
        let convertedBytes: Int
    }
    public init(cacheDirectory: URL? = nil, maximumCacheBytes: Int = 512 * 1024 * 1024, session: URLSession? = nil) {
        root = cacheDirectory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("SekaiKit/DeviceModels", isDirectory: true)
        self.maximumCacheBytes = max(64 * 1024 * 1024, maximumCacheBytes)
        self.session = session ?? URLSession(configuration: .ephemeral)
    }
    private struct CacheIdentity: Encodable {
        let region: String
        let platform: String
        let importerRevision: String
        let partID: String
        let assetBaseURL: URL
        let variationBundle: String?
        let bundles: [String: DeviceModelSourceManifest.Bundle]
    }
    public func prepare(partID: String, manifest: DeviceModelSourceManifest) async throws -> DeviceModelResult {
        while busy { await withCheckedContinuation { waiters.append($0) }; try Task.checkCancellation() }
        try Task.checkCancellation()
        try manifest.validate()
        guard let part = manifest.parts.first(where: { $0.id == partID }) else { throw ModelImportError.malformed("unknown sample part") }
        busy = true; defer { busy = false; let ready = waiters; waiters = []; for waiter in ready { waiter.resume() } }
        let started = Date(), fm = FileManager.default
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let identity = try encoder.encode(CacheIdentity(region: manifest.region, platform: manifest.platform,
            importerRevision: DeviceModelImporter.revision, partID: part.id,
            assetBaseURL: manifest.assetBaseURL, variationBundle: part.variationBundle,
            bundles: Dictionary(uniqueKeysWithValues: part.bundles.map { ($0, manifest.bundles[$0]!) })))
        let destination = root.appendingPathComponent("converted/" + digest(identity), isDirectory: true)
        if let receipt = validReceipt(at: destination) {
            try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: destination.path)
            return .init(directory: destination, cacheHit: true, downloadedBytes: 0, convertedBytes: receipt.convertedBytes, vertexCount: receipt.vertexCount, conversionSeconds: 0, elapsedSeconds: Date().timeIntervalSince(started))
        }
        try fm.createDirectory(at: root.appendingPathComponent("raw"), withIntermediateDirectories: true)
        var input: [Data] = [], downloaded = 0, signed = false
        var sourceCookie: String?
        for key in part.bundles {
            try Task.checkCancellation()
            let entry = manifest.bundles[key]!
            let sourceKey = digest(try encoder.encode([manifest.region, manifest.assetBaseURL.absoluteString, key, String(decoding: encoder.encode(entry), as: UTF8.self)]))
            let mapping = root.appendingPathComponent("raw/" + sourceKey + ".json")
            var actual = entry.sha256.map { RawReceipt(bytes: entry.bytes, sha256: $0) }
            if actual == nil, let data = try? Data(contentsOf: mapping), data.count < 1024 {
                actual = try? JSONDecoder().decode(RawReceipt.self, from: data)
            }
            if let actual, DeviceModelSourceManifest.validHash(actual.sha256), actual.bytes <= 32 * 1024 * 1024,
               let cached = try? Data(contentsOf: root.appendingPathComponent("raw/" + actual.sha256 + ".bundle"), options: .mappedIfSafe),
               cached.count == actual.bytes, digest(cached) == actual.sha256 {
                input.append(cached); continue
            }
            if !signed && manifest.region == "jp" {
                var request = URLRequest(url: URL(string: "https://issue.sekai.colorfulpalette.org/api/signature")!)
                request.httpMethod = "POST"; request.timeoutInterval = 30
                let (_, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw ModelImportError.malformed("source signature response") }
                // The signature endpoint and CDN are separate hosts. Scope the
                // returned CloudFront cookies to this source; never log/persist them.
                sourceCookie = try Self.signatureCookieHeader(http.value(forHTTPHeaderField: "Set-Cookie") ?? "")
                signed = true
            }
            let base = entry.downloadPath.map { manifest.assetBaseURL.appendingPathComponent($0, isDirectory: true) } ?? manifest.assetBaseURL
            let url = base.appendingPathComponent(key)
            var request = URLRequest(url: url, timeoutInterval: 60)
            request.httpShouldHandleCookies = false
            request.setValue(sourceCookie, forHTTPHeaderField: "Cookie")
            let wireLimit = min(32 * 1024 * 1024 + 4, entry.bytes + max(65536, entry.bytes / 10))
            let (temporary, response) = try await session.download(for: request, delegate: RawDownloadLimit(maximum: wireLimit))
            defer { try? fm.removeItem(at: temporary) }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200, http.url?.host == url.host,
                  let size = try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  size <= wireLimit else { throw ModelImportError.malformed("raw download response (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0))") }
            let raw = try UnityFSArchive.normalizeTransport(Data(contentsOf: temporary, options: .mappedIfSafe))
            let hash = digest(raw)
            if let expected = entry.sha256 {
                guard raw.count == entry.bytes, hash == expected else { throw ModelImportError.malformed("raw download integrity") }
            }
            guard raw.count <= 32 * 1024 * 1024 else { throw ModelImportError.budgetExceeded }
            let path = root.appendingPathComponent("raw/" + hash + ".bundle")
            try Task.checkCancellation()
            try raw.write(to: path, options: .atomic)
            try encoder.encode(RawReceipt(bytes: raw.count, sha256: hash)).write(to: mapping, options: .atomic)
            downloaded += size; input.append(raw)
        }
        try Task.checkCancellation()
        let variations = Set(part.bundles.enumerated().filter { $0.element == part.variationBundle }.map(\.offset))
        let conversion = Task.detached(priority: .utility) { try DeviceModelImporter.convert(bundles: input, variationBundleIndices: variations) }
        let result = try await withTaskCancellationHandler { try await conversion.value } onCancel: { conversion.cancel() }
        try Task.checkCancellation()
        let stage = root.appendingPathComponent("staging-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: stage.appendingPathComponent("textures"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: stage) }
        var files = result.texturePNGs
        files["scene.json"] = try JSONEncoder().encode(result.scene)
        guard files.values.reduce(0, { $0 + $1.count }) <= maximumCacheBytes else { throw ModelImportError.budgetExceeded }
        let receipt = Receipt(resources: files.mapValues(digest), vertexCount: result.vertexCount, conversionSeconds: result.elapsedSeconds, convertedBytes: files.values.reduce(0) { $0 + $1.count })
        for (name, bytes) in files { try bytes.write(to: stage.appendingPathComponent(name), options: .atomic) }
        try encoder.encode(receipt).write(to: stage.appendingPathComponent("receipt.json"), options: .atomic)
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.moveItem(at: stage, to: destination)
        prune(protecting: destination)
        return .init(directory: destination, cacheHit: false, downloadedBytes: downloaded, convertedBytes: receipt.convertedBytes, vertexCount: receipt.vertexCount, conversionSeconds: result.elapsedSeconds, elapsedSeconds: Date().timeIntervalSince(started))
    }

    // This endpoint can combine signed cookie pairs with semicolons as well
    // as folded Set-Cookie commas. Cookie attributes must not enter Cookie.
    static func signatureCookieHeader(_ header: String) throws -> String {
        let regex = try NSRegularExpression(pattern: #"(?:^|[;,]\s*)(CloudFront-(?:Policy|Signature|Key-Pair-Id))=([^;,\s]+)"#)
        let range = NSRange(header.startIndex..<header.endIndex, in: header)
        var values: [String: String] = [:]
        for match in regex.matches(in: header, range: range) {
            guard let key = Range(match.range(at: 1), in: header), let value = Range(match.range(at: 2), in: header) else { continue }
            values[String(header[key])] = String(header[value])
        }
        let names = ["CloudFront-Policy", "CloudFront-Signature", "CloudFront-Key-Pair-Id"]
        guard names.allSatisfy({ values[$0] != nil }) else { throw ModelImportError.malformed("source signature cookies") }
        return names.map { $0 + "=" + values[$0]! }.joined(separator: "; ")
    }

    private func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func validReceipt(at directory: URL) -> Receipt? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("receipt.json")), data.count <= 64 * 1024,
              let receipt = try? JSONDecoder().decode(Receipt.self, from: data), receipt.resources["scene.json"] != nil,
              receipt.resources.count <= 128 else { return nil }
        for (name, hash) in receipt.resources {
            guard name == "scene.json" || (name.hasPrefix("textures/") && name.hasSuffix(".png") && DeviceModelSourceManifest.validHash(String(name.dropFirst(9).dropLast(4)))),
                  let data = try? Data(contentsOf: directory.appendingPathComponent(name), options: .mappedIfSafe), digest(data) == hash else { return nil }
        }
        return receipt
    }
    private func prune(protecting directory: URL) {
        let fm = FileManager.default
        struct Item { let url: URL; let bytes: Int; let date: Date }
        func size(_ url: URL) -> Int {
            let paths = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey])?.allObjects as? [URL] ?? []
            return paths.reduce(0) { sum, path in let v = try? path.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]); return sum + (v?.isRegularFile == true ? v?.fileSize ?? 0 : 0) }
        }
        var items: [Item] = []
        for folder in ["raw", "converted"] {
            for url in (try? fm.contentsOfDirectory(at: root.appendingPathComponent(folder), includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])) ?? [] {
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                items.append(.init(url: url, bytes: folder == "raw" ? values?.fileSize ?? 0 : size(url), date: values?.contentModificationDate ?? .distantPast))
            }
        }
        var total = items.reduce(0) { $0 + $1.bytes }
        for item in items.sorted(by: { $0.date < $1.date }) where total > maximumCacheBytes && item.url != directory {
            do { try fm.removeItem(at: item.url); total -= item.bytes } catch { continue }
        }
    }
}

private final class RawDownloadLimit: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let maximum: Int64
    init(maximum: Int) { self.maximum = Int64(maximum) }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > maximum || totalBytesExpectedToWrite > maximum { downloadTask.cancel() }
    }
}
