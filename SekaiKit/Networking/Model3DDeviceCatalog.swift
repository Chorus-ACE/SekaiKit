import Foundation
internal import CryptoKit

/// Small regional directory. Character lists and source plans are fetched separately.
public struct Model3DDeviceCatalog: Codable, Sendable {
    public let schemaVersion: Int
    public let region: SekaiLocale
    public let revision: String
    public let sourceRevision: String
    public let importerRevision: String
    public let counts: [String: Int]
    public let characters: [Character]
    public struct Character: Codable, Identifiable, Sendable {
        public let id: Int
        public let name: String
        public let readyCount: Int
        public let partCount: Int
        public let totalCount: Int
        public let catalog: Resource
    }
    public struct Resource: Codable, Sendable {
        public let path: String
        public let sha256: String
        public let bytes: Int
    }
}

public struct Model3DDevicePartCatalog: Codable, Sendable {
    public let schemaVersion: Int
    public let region: SekaiLocale
    public let characterID: Int
    public let parts: [Part]
    public struct Part: Codable, Identifiable, Sendable {
        public let id: String
        public let name: String
        public let characterID: Int
        public let costumeID: Int
        /// Upstream slot: body, hair, head or head_optional.
        public let type: Kind
        public let unit: String?
        public let colorID: Int?
        public let colorName: String?
        public let groupID: Int?
        public let outfitID: Int?
        public let accessoryID: Int?
        /// `ready` means raw dependencies have hashes; it does not certify rendering parity.
        public let status: Status
        public let manifest: Model3DDeviceCatalog.Resource?
        public var isReady: Bool { status == .ready && manifest != nil }
        public enum Kind: Hashable, Sendable, Codable {
            case costume, hairstyle, head, accessory, unknown(String)
            public init(rawValue: String) {
                self = switch rawValue {
                case "body": .costume
                case "hair": .hairstyle
                case "head": .head
                case "head_optional": .accessory
                default: .unknown(rawValue)
                }
            }
            public var rawValue: String {
                switch self {
                case .costume: "body"
                case .hairstyle: "hair"
                case .head: "head"
                case .accessory: "head_optional"
                case .unknown(let raw): raw
                }
            }
            public var localizedName: String {
                if case .unknown(let raw) = self { return raw }
                return NSLocalizedString("Model3DDevice.kind." + rawValue, bundle: .module, comment: "")
            }
            public init(from decoder: any Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
            public func encode(to encoder: any Encoder) throws { var container = encoder.singleValueContainer(); try container.encode(rawValue) }
        }
        public enum Status: Hashable, Sendable, Codable {
            case ready, pending, unsupportedRegion, unknown(String)
            public init(rawValue: String) {
                self = switch rawValue {
                case "ready": .ready
                case "pending": .pending
                case "unsupportedRegion": .unsupportedRegion
                default: .unknown(rawValue)
                }
            }
            public var rawValue: String {
                switch self {
                case .ready: "ready"
                case .pending: "pending"
                case .unsupportedRegion: "unsupportedRegion"
                case .unknown(let raw): raw
                }
            }
            public var localizedName: String {
                if case .unknown(let raw) = self { return raw }
                return NSLocalizedString("Model3DDevice.status." + rawValue, bundle: .module, comment: "")
            }
            public init(from decoder: any Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
            public func encode(to encoder: any Encoder) throws { var container = encoder.singleValueContainer(); try container.encode(rawValue) }
        }

    }
}

/// Fetches only one region, one character and one part at a time. Source Bundles
/// are downloaded by Model3DDeviceClient directly; GitHub serves metadata only.
public actor Model3DDeviceSourceClient {
    public static let shared = Model3DDeviceSourceClient()
    public enum Failure: LocalizedError {
        case invalidResponse, invalidCatalog, incompatibleImporter, unavailablePart, integrityFailure
        case httpStatus(Int)
        public var errorDescription: String? {
            switch self {
            case .invalidResponse: "The model source returned an invalid or oversized response."
            case .invalidCatalog: "The model source catalog is invalid or belongs to another region."
            case .incompatibleImporter: "This source catalog requires an unsupported model importer."
            case .unavailablePart: "This part is still waiting for source verification."
            case .integrityFailure: "The model source metadata failed its integrity check. Please retry."
            case .httpStatus(404): "The model source catalog is not available yet (HTTP 404). Fixed samples remain available."
            case .httpStatus(let status): "The model source request failed (HTTP \(status)). Please retry."
            }
        }
    }
    private let baseURL: URL
    private let session: URLSession
    private let cacheURL: URL
    public init(baseURL: URL = URL(string: "https://raw.githubusercontent.com/Chorus-ACE/Sekai-3D-Assets/main/device/")!,
                cacheDirectory: URL? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.cacheURL = cacheDirectory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("SekaiKit/DeviceSourceMetadata", isDirectory: true)
    }
    public func catalog(for locale: SekaiLocale) async throws -> Model3DDeviceCatalog {
        let data = try await download(path: "regions/" + locale.rawValue + ".json", limit: 1024 * 1024)
        let catalog = try JSONDecoder().decode(Model3DDeviceCatalog.self, from: data)
        guard catalog.schemaVersion == 1, catalog.region == locale,
              catalog.characters.count <= 128, Set(catalog.characters.map(\.id)).count == catalog.characters.count,
              catalog.characters.allSatisfy({ $0.id > 0 && $0.readyCount >= 0 && $0.readyCount <= $0.partCount && $0.partCount <= $0.totalCount }),
              catalog.counts.values.allSatisfy({ $0 >= 0 }) else { throw Failure.invalidCatalog }
        guard catalog.importerRevision == Model3DDeviceClient.importerRevision else { throw Failure.incompatibleImporter }
        return catalog
    }
    public func parts(for characterID: Int, in catalog: Model3DDeviceCatalog) async throws -> Model3DDevicePartCatalog {
        guard let character = catalog.characters.first(where: { $0.id == characterID }) else { throw Failure.invalidCatalog }
        let data = try await object(character.catalog)
        let scoped = try JSONDecoder().decode(Model3DDevicePartCatalog.self, from: data)
        guard scoped.schemaVersion == 1, scoped.region == catalog.region, scoped.characterID == characterID,
              scoped.parts.count == character.partCount, scoped.parts.count <= 32_000,
              Set(scoped.parts.map(\.id)).count == scoped.parts.count,
              scoped.parts.allSatisfy({ $0.characterID == characterID && !$0.id.isEmpty && ($0.status != .ready || $0.manifest != nil) }),
              scoped.parts.filter(\.isReady).count == character.readyCount else { throw Failure.invalidCatalog }
        return scoped
    }
    public func manifest(for part: Model3DDevicePartCatalog.Part, in catalog: Model3DDevicePartCatalog) async throws -> Model3DDeviceSourceManifest {
        guard part.isReady, catalog.parts.contains(where: { $0.id == part.id && $0.manifest?.sha256 == part.manifest?.sha256 }),
              let reference = part.manifest else { throw Failure.unavailablePart }
        // Other regions have independent directories, but their raw formats have
        // not yet been validated by the native importer. Never fall back to JP.
        guard catalog.region == .jp else { throw Failure.incompatibleImporter }
        let data = try await object(reference)
        let manifest = try JSONDecoder().decode(Model3DDeviceSourceManifest.self, from: data)
        guard manifest.locale == catalog.region, manifest.parts.count == 1,
              manifest.parts[0].id == part.id else { throw Failure.invalidCatalog }
        return manifest
    }
    private func object(_ reference: Model3DDeviceCatalog.Resource) async throws -> Data {
        let expected = "objects/" + reference.sha256 + ".json"
        guard reference.sha256.count == 64, reference.sha256.allSatisfy({ "0123456789abcdef".contains($0) }),
              reference.path == expected, reference.bytes > 0, reference.bytes <= 16 * 1024 * 1024 else { throw Failure.invalidCatalog }
        let path = cacheURL.appendingPathComponent(reference.sha256 + ".json")
        if let data = try? Data(contentsOf: path), valid(data, reference) { return data }
        let data = try await download(path: reference.path, limit: reference.bytes)
        guard valid(data, reference) else { throw Failure.integrityFailure }
        try Task.checkCancellation()
        try FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        try data.write(to: path, options: .atomic)
        pruneMetadata(protecting: path)
        return data
    }
    private func download(path: String, limit: Int) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        let (temporary, response) = try await session.download(for: request)
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard let http = response as? HTTPURLResponse else { throw Failure.invalidResponse }
        guard http.statusCode == 200 else { throw Failure.httpStatus(http.statusCode) }
        guard http.url?.host == url.host,
              let size = try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0, size <= limit else { throw Failure.invalidResponse }
        return try Data(contentsOf: temporary)
    }
    private func valid(_ data: Data, _ reference: Model3DDeviceCatalog.Resource) -> Bool {
        data.count == reference.bytes && SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() == reference.sha256
    }
    private func pruneMetadata(protecting protected: URL) {
        let manager = FileManager.default
        let files = (try? manager.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])) ?? []
        var total = 0
        let entries = files.compactMap { url -> (URL, Int, Date)? in
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]), let bytes = values.fileSize else { return nil }
            total += bytes
            return (url, bytes, values.contentModificationDate ?? .distantPast)
        }.sorted { $0.2 < $1.2 }
        for (url, bytes, _) in entries where total > 64 * 1024 * 1024 && url != protected {
            if (try? manager.removeItem(at: url)) != nil { total -= bytes }
        }
    }
}
