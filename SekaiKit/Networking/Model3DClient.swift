import Foundation
internal import CryptoKit

/// A region's published, render-ready wardrobe. Objects are shared across regions by SHA-256.
public struct Model3DCatalog: Decodable, Sendable {
    public let schemaVersion: Int
    public let region: SekaiLocale
    public let revision: String
    public let roles: [Role]
    public let files: [String: Resource]

    public struct Role: Decodable, Identifiable, Sendable {
        public let id: String
        public let name: String?
        public let characterID: Int
        public let unit: String
        public let bodyCostumeID: Int
        public let headCostumeID: Int
        public let hairCostumeID: Int
        public let parts: [Part]
        enum CodingKeys: String, CodingKey {
            case id, name, unit, parts
            case characterID = "characterId"
            case bodyCostumeID = "bodyCostume3dId", headCostumeID = "headCostume3dId", hairCostumeID = "hairCostume3dId"
        }
    }
    public struct Part: Decodable, Identifiable, Sendable {
        public let id: String
        public let costumeID: Int
        public let type: String
        public let name: String
        public let colorName: String
    }
    public struct Resource: Decodable, Sendable {
        public let sha256: String
        public let bytes: Int
        public let archiveBytes: Int
        public let url: URL
    }
}

/// Downloads individual Apple Archives on demand; immutable objects are cached across wardrobes.
public actor Model3DClient {
    public static let shared = Model3DClient()
    public enum Failure: Error { case invalidManifest, missingResource, invalidResponse, integrityFailure }
    private let baseURL: URL
    private let cacheURL: URL
    private var pending: [String: Task<Data, Error>] = [:]

    public init(baseURL: URL = URL(string: "https://raw.githubusercontent.com/Chorus-ACE/Sekai-3D-Assets/main/regions/")!, cacheURL: URL? = nil) {
        self.baseURL = baseURL
        self.cacheURL = cacheURL ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("SekaiKit/Models3D", isDirectory: true)
    }
    public func catalog(for locale: SekaiLocale) async throws -> Model3DCatalog {
        let request = URLRequest(url: baseURL.appendingPathComponent("\(locale.rawValue).json"), cachePolicy: .reloadIgnoringLocalCacheData)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 64 * 1024 * 1024 else { throw Failure.invalidResponse }
        let catalog = try JSONDecoder().decode(Model3DCatalog.self, from: data)
        guard catalog.schemaVersion == 1, catalog.region == locale else { throw Failure.invalidManifest }
        return catalog
    }
    public func resource(at path: String, in catalog: Model3DCatalog) async throws -> Data {
        guard Self.validPath(path), let resource = catalog.files[path] else { throw Failure.missingResource }
        return try await object(resource)
    }
    private func object(_ reference: Model3DCatalog.Resource) async throws -> Data {
        guard reference.sha256.count == 64, reference.sha256.allSatisfy({ "0123456789abcdef".contains($0) }),
              reference.bytes > 0, reference.bytes <= 256 * 1024 * 1024,
              reference.archiveBytes > 0, reference.archiveBytes <= 256 * 1024 * 1024,
              reference.url.scheme == "https", reference.url.host == "github.com",
              reference.url.path.hasPrefix("/Chorus-ACE/Sekai-3D-Assets/releases/download/") else { throw Failure.invalidManifest }
        if let task = pending[reference.sha256] { return try await task.value }
        let file = cacheURL.appendingPathComponent(reference.sha256)
        let task = Task<Data, Error> {
            if let cached = try? Data(contentsOf: file), Self.valid(cached, reference) { return cached }
            let (temporary, response) = try await URLSession.shared.download(from: reference.url)
            defer { try? FileManager.default.removeItem(at: temporary) }
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  (try temporary.resourceValues(forKeys: [.fileSizeKey])).fileSize == reference.archiveBytes else { throw Failure.invalidResponse }
            let archive = try Data(contentsOf: temporary)
            let bytes = try ProtobufArchive.decode(archive, expectedFile: "payload")
            guard Self.valid(bytes, reference) else { throw Failure.integrityFailure }
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try bytes.write(to: file, options: .atomic)
            return bytes
        }
        pending[reference.sha256] = task
        defer { pending.removeValue(forKey: reference.sha256) }
        return try await task.value
    }
    internal nonisolated static func validPath(_ path: String) -> Bool {
        !path.isEmpty && !path.hasPrefix("/") && !path.contains("\\") && !path.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0.isEmpty || $0 == "." || $0 == ".." })
    }
    private nonisolated static func valid(_ data: Data, _ reference: Model3DCatalog.Resource) -> Bool {
        data.count == reference.bytes && SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() == reference.sha256
    }
}
