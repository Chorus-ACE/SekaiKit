import Foundation

/// A small, explicit dependency plan. It contains no converted meshes or textures.
public struct DeviceModelSourceManifest: Codable, Sendable {
    public let schemaVersion: Int
    public let region: String
    public let platform: String
    public let sourceRevision: String
    public let assetBaseURL: URL
    public let bundles: [String: Bundle]
    public let parts: [Part]
    public struct Bundle: Codable, Sendable { public let bytes: Int; public let sha256: String }
    public struct Part: Codable, Identifiable, Sendable { public let id: String; public let name: String; public let bundles: [String] }

    /// Pinned, bounded JP samples for the prototype, not a production wardrobe.
    public static func japaneseSamples() throws -> Self {
        guard let url = Foundation.Bundle.module.url(forResource: "jp-device-samples", withExtension: "json") else { throw ModelImportError.malformed("missing sample manifest") }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
    public func validate() throws {
        guard schemaVersion == 1, region == "jp", platform == "android", parts.count <= 16, bundles.count <= 32,
              assetBaseURL.scheme == "https", assetBaseURL.user == nil, assetBaseURL.password == nil, assetBaseURL.port == nil,
              assetBaseURL.query == nil, assetBaseURL.fragment == nil, let host = assetBaseURL.host,
              host.hasPrefix("production-"), host.hasSuffix("-assetbundle.sekai.colorfulpalette.org"),
              !assetBaseURL.path.contains(".."), assetBaseURL.lastPathComponent == "android", assetBaseURL.hasDirectoryPath, Set(parts.map(\.id)).count == parts.count else {
            throw ModelImportError.unsupported("raw source manifest")
        }
        for (path, bundle) in bundles {
            guard !path.isEmpty, path.count < 1024, !path.hasPrefix("/"), !path.contains(".."),
                  path.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_-/").contains($0) }),
                  bundle.bytes > 0, bundle.bytes <= 32 * 1024 * 1024, Self.validHash(bundle.sha256) else { throw ModelImportError.malformed("raw bundle record") }
        }
        for part in parts {
            guard !part.id.isEmpty, !part.bundles.isEmpty, Set(part.bundles).count == part.bundles.count,
                  part.bundles.allSatisfy({ bundles[$0] != nil }),
                  part.bundles.reduce(0, { $0 + (bundles[$1]?.bytes ?? 0) }) <= 64 * 1024 * 1024 else { throw ModelImportError.malformed("raw part dependencies") }
        }
    }
    static func validHash(_ value: String) -> Bool { value.count == 64 && value.allSatisfy { "0123456789abcdef".contains($0) } }
}
