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
    public struct Bundle: Codable, Sendable {
        public let bytes: Int
        public let sha256: String?
        /// Upstream build identity; never interpreted as a file checksum.
        public let sourceHash: String?
        public let downloadPath: String?
    }
    public struct Part: Codable, Identifiable, Sendable { public let id: String; public let name: String; public let bundles: [String]; public let primaryBundle: String?; public let variationBundle: String? }

    /// Pinned, bounded JP samples for the prototype, not a production wardrobe.
    public static func japaneseSamples() throws -> Self {
        guard let url = Foundation.Bundle.module.url(forResource: "jp-device-samples", withExtension: "json") else { throw ModelImportError.malformed("missing sample manifest") }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
    public func validate() throws {
        guard [1,2].contains(schemaVersion), ["jp","en","tw","kr","cn"].contains(region), platform == (["jp","en"].contains(region) ? "android" : "ios"), parts.count <= 16, bundles.count <= 32,
              assetBaseURL.scheme == "https", assetBaseURL.user == nil, assetBaseURL.password == nil, assetBaseURL.port == nil,
              assetBaseURL.query == nil, assetBaseURL.fragment == nil, let host = assetBaseURL.host,
              trustedHost(host), !assetBaseURL.path.contains(".."), assetBaseURL.hasDirectoryPath, Set(parts.map(\.id)).count == parts.count else {
            throw ModelImportError.unsupported("raw source manifest")
        }
        for (path, bundle) in bundles {
            guard !path.isEmpty, path.count < 1024, !path.hasPrefix("/"), !path.contains(".."),
                  path.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_-/").contains($0) }),
                  bundle.bytes > 0, bundle.bytes <= 32 * 1024 * 1024,
                  (bundle.sha256.map(Self.validHash) ?? (schemaVersion == 2 && bundle.sourceHash.map(Self.validHash) == true)),
                  bundle.downloadPath.map({ !$0.contains("..") && !$0.contains("/") && !$0.contains("\\") && !$0.isEmpty }) ?? true else { throw ModelImportError.malformed("raw bundle record") }
        }
        for part in parts {
            guard part.primaryBundle.map({ part.bundles.contains($0) }) ?? true,
                  part.variationBundle.map({ part.bundles.contains($0) }) ?? true, !part.id.isEmpty, !part.bundles.isEmpty, Set(part.bundles).count == part.bundles.count,
                  part.bundles.allSatisfy({ bundles[$0] != nil }),
                  part.bundles.reduce(0, { $0 + (bundles[$1]?.bytes ?? 0) }) <= 64 * 1024 * 1024 else { throw ModelImportError.malformed("raw part dependencies") }
        }
    }
    private func trustedHost(_ host: String) -> Bool {
        switch region {
        case "jp": host.hasPrefix("production-") && host.hasSuffix("-assetbundle.sekai.colorfulpalette.org") && assetBaseURL.lastPathComponent == "android"
        case "en": host.hasPrefix("n-") && host.hasSuffix("-assetbundle.sekai-en.com") && assetBaseURL.lastPathComponent == "android"
        case "tw": host == "lf16-mkovscdn-sg.bytedgame.com" && assetBaseURL.path.hasPrefix("/obj/sf-game-alisg/gdl_app_5245/AssetBundle/")
        case "kr": host == "lf19-mkkr.bytedgame.com" && assetBaseURL.path.hasPrefix("/obj/sf-game-alisg/gdl_app_292248/AssetBundle/")
        case "cn": host == "lf3-mkcncdn-tos.dailygn.com" && assetBaseURL.path.hasPrefix("/obj/sf-game-lf/gdl_app_5236/AssetBundle/")
        default: false
        }
    }
    static func validHash(_ value: String) -> Bool { value.count == 64 && value.allSatisfy { "0123456789abcdef".contains($0) } }
}
