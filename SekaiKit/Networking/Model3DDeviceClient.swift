import Foundation
import SekaiModelImporter

/// Experimental JP raw-source plan. Production wardrobes use Model3DLibrary.
public struct Model3DDeviceSourceManifest: Codable, Sendable {
    internal let raw: DeviceModelSourceManifest
    public var locale: SekaiLocale { .jp }
    public var sourceRevision: String { raw.sourceRevision }
    public var parts: [Part] { raw.parts.map { .init(id: $0.id, name: $0.name) } }
    public struct Part: Identifiable, Sendable { public let id: String; public let name: String }
    private init(raw: DeviceModelSourceManifest) throws { try raw.validate(); self.raw = raw }
    public static func japaneseSamples() throws -> Self { try .init(raw: .japaneseSamples()) }
    public init(from decoder: any Decoder) throws { try self.init(raw: .init(from: decoder)) }
    public func encode(to encoder: any Encoder) throws { try raw.encode(to: encoder) }
}

public struct Model3DDeviceResult: Sendable {
    public let directory: URL
    public let cacheHit: Bool
    public let downloadedBytes: Int
    public let convertedBytes: Int
    public let vertexCount: Int
    public let conversionSeconds: Double
    public let elapsedSeconds: Double
    internal init(_ result: DeviceModelResult) {
        directory = result.directory; cacheHit = result.cacheHit
        downloadedBytes = result.downloadedBytes; convertedBytes = result.convertedBytes
        vertexCount = result.vertexCount; conversionSeconds = result.conversionSeconds; elapsedSeconds = result.elapsedSeconds
    }
}

/// Isolated on-device prototype. Animation, SEKAI shader effects and full wardrobe
/// assembly still use the existing Haruki pipeline; no silent server fallback occurs.
public actor Model3DDeviceClient {
    public static let shared = Model3DDeviceClient()
    public static var thirdPartyNotices: String { DeviceModelImporter.thirdPartyNotices }
    public static var importerRevision: String { DeviceModelImporter.revision }
    private let client: DeviceModelClient
    public init(cacheDirectory: URL? = nil, maximumCacheBytes: Int = 512 * 1024 * 1024) {
        client = .init(cacheDirectory: cacheDirectory, maximumCacheBytes: maximumCacheBytes)
    }
    public func prepare(partID: String, manifest: Model3DDeviceSourceManifest) async throws -> Model3DDeviceResult {
        let result = try await client.prepare(partID: partID, manifest: manifest.raw)
        return .init(result)
    }
}
