import Foundation
internal import CryptoKit
internal import Compression

/// Regional source metadata. No converted model objects or cross-region fallback.
public struct Model3DLocalLibrary: Decodable, Sendable {
    public let schemaVersion: Int
    public let region: SekaiLocale
    public let revision: String
    public let importerRevision: String
    public let roles: [Role]
    public struct Role: Decodable, Identifiable, Sendable {
        public let id: String
        public let characterID: Int
        public let unitID: String
        public let name: String
        public let catalog: Resource
        enum CodingKeys: String, CodingKey { case id, name, catalog; case characterID = "characterId", unitID = "unit" }
    }
    public struct Resource: Decodable, Sendable {
        public let path: String
        public let sha256: String
        public let bytes: Int
        public let decodedBytes: Int?
    }
}

public struct Model3DLocalWardrobe: Decodable, Sendable {
    public let schemaVersion: Int
    public let region: SekaiLocale
    public let revision: String
    fileprivate let role: Model3DCatalog.Role
    private let parts: [SourcePart]
    private let bundles: [String: SourceBundle]
    private let assetBaseURL: URL
    private let platform: String
    private let compatibility: [Compatibility]
    public let character: Model3DCharacter
    private let library: Model3DLibrary
    fileprivate struct SourcePart: Decodable, Sendable {
        let id: String; let type: String; let costumeID: Int; let name: String?
        let attachNode: String?; let modelAssetbundleName: String?; let headCostume3dAssetbundleType: String?
        let primaryBundle: String?; let variationBundle: String?; let bundleKeys: [String]; let status: String
    }
    fileprivate struct SourceBundle: Codable, Sendable { let bytes: Int; let sourceHash: String; let downloadPath: String? }
    private struct Compatibility: Codable, Sendable { let headCostume3dId: Int; let hairCostume3dId: Int; let state: String? }
    private struct SourceRole: Decodable {
        let id: String; let name: String?; let characterId: Int; let unit: String
        let bodyCostume3dId: Int; let headCostume3dId: Int; let hairCostume3dId: Int
        let characterHeightMeters: Double?; let skinColors: [String:String]?; let roleRuntimePath: String?
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, region, revision, role, parts, bundles, assetBaseURL, platform, compatibility }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        region = try c.decode(SekaiLocale.self, forKey: .region)
        revision = try c.decode(String.self, forKey: .revision)
        let source = try c.decode(SourceRole.self, forKey: .role)
        parts = try c.decode([SourcePart].self, forKey: .parts)
        let records = try c.decode([Model3DCatalog.Part].self, forKey: .parts).filter { ["available","empty"].contains($0.metadata.status ?? "") }
        role = .init(id: source.id, name: source.name, characterID: source.characterId, unit: source.unit,
                     bodyCostumeID: source.bodyCostume3dId, headCostumeID: source.headCostume3dId, hairCostumeID: source.hairCostume3dId,
                     height: source.characterHeightMeters, skinColors: source.skinColors, runtimePath: source.roleRuntimePath, parts: records)
        bundles = try c.decode([String: SourceBundle].self, forKey: .bundles)
        assetBaseURL = try c.decode(URL.self, forKey: .assetBaseURL)
        platform = try c.decode(String.self, forKey: .platform)
        compatibility = try c.decodeIfPresent([Compatibility].self, forKey: .compatibility) ?? []
        guard schemaVersion == 2, parts.count <= 32_000, bundles.count <= 32_000,
              Set(parts.map(\.id)).count == parts.count,
              parts.allSatisfy({ Set($0.bundleKeys).count == $0.bundleKeys.count }) else { throw Model3DDeviceSourceClient.Failure.invalidCatalog }
        // Reuse the public wardrobe grouping and regional selection semantics.
        let catalog = Model3DCatalog(schemaVersion: 1, region: region, revision: revision, roles: [role], files: [:])
        library = try Model3DLibrary(catalog: catalog)
        guard let character = library.characters.first else { throw Model3DLibrary.Failure.unknownCharacter }
        self.character = character
    }
    fileprivate func selected(_ selection: Model3DSelection) throws -> (Model3DRenderConfiguration, [SourcePart]) {
        guard selection.locale == region else { throw Model3DLibrary.Failure.wrongLocale }
        guard selection.characterID == character.id else { throw Model3DLibrary.Failure.unknownCharacter }
        let resolved = try library.resolve(selection)
        let ids = [selection.costumeID, selection.hairstyleID, selection.accessoryID].compactMap { $0 }
        var selected: [SourcePart] = []
        for id in ids {
            guard id.hasPrefix(region.rawValue + ":"), let part = parts.first(where: { region.rawValue + ":" + $0.id == id }), part.status == "available" else { throw Model3DLibrary.Failure.unknownVariant }
            selected.append(part)
        }
        if let accessory = selected.first(where: { $0.type == "head_optional" }), let hair = selected.first(where: { $0.type == "hair" }),
           compatibility.contains(where: { $0.headCostume3dId == accessory.costumeID && $0.hairCostume3dId == hair.costumeID && $0.state == "not_available" }) {
            throw Model3DLibrary.Failure.unknownVariant
        }
        // Complete heads retain the role's canonical face/eye fallback even if
        // the last independently selected hairstyle is different.
        if selected.contains(where: { $0.type == "head" }), !selected.contains(where: { $0.type == "hair" && $0.costumeID == role.hairCostumeID }),
           let fallback = parts.first(where: { $0.type == "hair" && $0.costumeID == role.hairCostumeID && $0.status == "available" }) { selected.append(fallback) }
        return (resolved, selected)
    }
    fileprivate func manifest(_ part: SourcePart) throws -> Model3DDeviceSourceManifest {
        guard !part.bundleKeys.isEmpty else { throw Model3DDeviceSourceClient.Failure.unavailablePart }
        let references = try Dictionary(uniqueKeysWithValues: part.bundleKeys.map { key in
            guard let bundle = bundles[key] else { throw Model3DDeviceSourceClient.Failure.invalidCatalog }
            return (key, bundle)
        })
        struct Plan: Encodable {
            let schemaVersion = 2
            let region: String; let platform: String; let sourceRevision: String; let assetBaseURL: URL
            let bundles: [String: SourceBundle]
            let parts: [Part]
            struct Part: Encodable { let id: String; let name: String; let bundles: [String]; let primaryBundle: String?; let variationBundle: String? }
        }
        let plan = Plan(region: region.rawValue, platform: platform, sourceRevision: revision, assetBaseURL: assetBaseURL,
                        bundles: references, parts: [.init(id: part.id, name: part.name ?? part.id, bundles: part.bundleKeys, primaryBundle: part.primaryBundle, variationBundle: part.variationBundle)])
        return try JSONDecoder().decode(Model3DDeviceSourceManifest.self, from: JSONEncoder().encode(plan))
    }
}

public struct Model3DLocalRenderConfiguration: Sendable {
    public let selection: Model3DSelection
    public var locale: SekaiLocale { selection.locale }
    public let hairstyleIsLocked: Bool
    public let recipeJSON: String
    public let revision: String
    fileprivate let directories: [String: URL]
}

/// Downloads original Unity resources only on selection, converts them natively,
/// then exposes locally generated scenes/textures to the embedded Haruki engine.
public actor Model3DLocalClient {
    public static let shared = Model3DLocalClient()
    private let baseURL: URL
    private let session: URLSession
    private let converter: Model3DDeviceClient
    private let metadata: URL
    public init(baseURL: URL = URL(string: "https://raw.githubusercontent.com/Chorus-ACE/Sekai-3D-Assets/main/device/v2/")!,
                cacheDirectory: URL? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL; self.session = session
        let root = cacheDirectory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("SekaiKit/LocalViewer")
        metadata = root.appendingPathComponent("metadata")
        converter = .init(cacheDirectory: root.appendingPathComponent("models"))
    }
    public func library(for locale: SekaiLocale) async throws -> Model3DLocalLibrary {
        let data = try await download("regions/" + locale.rawValue + ".json", maximum: 1024 * 1024)
        let library = try JSONDecoder().decode(Model3DLocalLibrary.self, from: data)
        guard library.schemaVersion == 2, library.region == locale, library.importerRevision == Model3DDeviceClient.importerRevision,
              library.roles.count <= 128, Set(library.roles.map(\.id)).count == library.roles.count else { throw Model3DDeviceSourceClient.Failure.invalidCatalog }
        return library
    }
    public func wardrobe(for roleID: String, in library: Model3DLocalLibrary) async throws -> Model3DLocalWardrobe {
        guard let role = library.roles.first(where: { $0.id == roleID }) else { throw Model3DLibrary.Failure.unknownCharacter }
        let r = role.catalog
        let compressed = r.decodedBytes != nil
        guard r.sha256.count == 64, r.sha256.allSatisfy({ "0123456789abcdef".contains($0) }), r.path == "objects/" + r.sha256 + (compressed ? ".json.deflate" : ".json"),
              r.bytes > 0, r.bytes <= 32 * 1024 * 1024,
              r.decodedBytes.map({ $0 > 0 && $0 <= 32 * 1024 * 1024 }) ?? true else { throw Model3DDeviceSourceClient.Failure.invalidCatalog }
        let file = metadata.appendingPathComponent(r.sha256 + ".json")
        func valid(_ data: Data) -> Bool { data.count == r.bytes && Self.sha(data) == r.sha256 }
        let data: Data
        if let cached = try? Data(contentsOf: file), valid(cached) { data = cached }
        else {
            data = try await download(r.path, maximum: r.bytes)
            guard valid(data) else { throw Model3DDeviceSourceClient.Failure.integrityFailure }
            try FileManager.default.createDirectory(at: metadata, withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
        }
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
        pruneMetadata(protecting: file)
        let decoded: Data
        if let count = r.decodedBytes {
            var output = Data(count: count)
            let size = output.withUnsafeMutableBytes { destination in
                data.withUnsafeBytes { source in
                    compression_decode_buffer(destination.bindMemory(to: UInt8.self).baseAddress!, count,
                        source.bindMemory(to: UInt8.self).baseAddress!, data.count, nil, COMPRESSION_ZLIB)
                }
            }
            guard size == count else { throw Model3DDeviceSourceClient.Failure.integrityFailure }
            decoded = output
        } else { decoded = data }
        let wardrobe = try JSONDecoder().decode(Model3DLocalWardrobe.self, from: decoded)
        guard wardrobe.region == library.region, wardrobe.character.id == roleID else { throw Model3DDeviceSourceClient.Failure.invalidCatalog }
        return wardrobe
    }
    public func prepare(_ selection: Model3DSelection, in wardrobe: Model3DLocalWardrobe) async throws -> Model3DLocalRenderConfiguration {
        let (resolved, parts) = try wardrobe.selected(selection)
        var directories: [String: URL] = [:], payload: [[String: Any]] = []
        for part in parts {
            try Task.checkCancellation()
            let plan = try wardrobe.manifest(part)
            let result = try await converter.prepare(partID: part.id, manifest: plan)
            let key = result.directory.lastPathComponent
            directories[key] = result.directory
            payload.append(["kind": part.type, "sceneURL": "sekai3d://runtime/" + key + "/scene.json",
                "entry": ["id": part.id, "partType": part.type, "costume3dId": part.costumeID, "characterId": wardrobe.character.characterID, "unit": wardrobe.character.unitID, "name": part.name ?? part.id, "attachNode": part.attachNode ?? "Head", "modelAssetbundleName": part.modelAssetbundleName ?? "", "headCostume3dAssetbundleType": part.headCostume3dAssetbundleType ?? ""]])
        }
        var recipe = (try JSONSerialization.jsonObject(with: Data(resolved.recipeJSON.utf8))) as! [String: Any]
        recipe.merge(["roleId": selection.characterID, "characterId": wardrobe.character.characterID,
            "characterHeightMeters": wardrobe.character.height ?? 1.6,
            "defaultHairCostume3dId": wardrobe.role.hairCostumeID,
            "skinColors": wardrobe.role.skinColors ?? [:], "parts": payload]) { _, new in new }
        let json = try JSONSerialization.data(withJSONObject: recipe, options: [.sortedKeys])
        return .init(selection: selection, hairstyleIsLocked: resolved.hairstyleIsLocked, recipeJSON: String(decoding: json, as: UTF8.self), revision: wardrobe.revision, directories: directories)
    }
    public func resource(at path: String, in configuration: Model3DLocalRenderConfiguration) async throws -> Data {
        guard Model3DClient.validPath(path) else { throw Model3DDeviceSourceClient.Failure.invalidCatalog }
        let pieces = path.split(separator: "/", maxSplits: 1)
        guard pieces.count == 2, let root = configuration.directories[String(pieces[0])] else { throw Model3DDeviceSourceClient.Failure.unavailablePart }
        let relative = String(pieces[1])
        guard relative == "scene.json" || (relative.hasPrefix("textures/") && relative.hasSuffix(".png") && relative.count == 77) else { throw Model3DDeviceSourceClient.Failure.invalidCatalog }
        return try Data(contentsOf: root.appendingPathComponent(relative))
    }
    private func download(_ path: String, maximum: Int) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        let (file, response) = try await session.download(for: URLRequest(url: url), delegate: LocalMetadataDownloadLimit(maximum: maximum))
        defer { try? FileManager.default.removeItem(at: file) }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, http.url?.host == url.host,
              let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0, size <= maximum else { throw Model3DDeviceSourceClient.Failure.invalidResponse }
        return try Data(contentsOf: file)
    }
    private func pruneMetadata(protecting current: URL) {
        let fm = FileManager.default
        let entries = ((try? fm.contentsOfDirectory(at: metadata, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])) ?? []).map { url in
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            return (url: url, bytes: values?.fileSize ?? 0, date: values?.contentModificationDate ?? .distantPast)
        }
        var size = entries.reduce(0) { $0 + $1.bytes }
        for entry in entries.sorted(by: { $0.date < $1.date }) where size > 64 * 1024 * 1024 && entry.url != current {
            if (try? fm.removeItem(at: entry.url)) != nil { size -= entry.bytes }
        }
    }
    private static func sha(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}

private final class LocalMetadataDownloadLimit: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let maximum: Int64
    init(maximum: Int) { self.maximum = Int64(maximum) }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > maximum || totalBytesExpectedToWrite > maximum { downloadTask.cancel() }
    }
}
