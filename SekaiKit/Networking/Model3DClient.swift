import Foundation
internal import CryptoKit

/// Downloads individual Apple Archives on demand; immutable objects are cached across wardrobes.
public actor Model3DClient {
    public static let shared = Model3DClient()
    public enum Failure: Error { case invalidManifest, missingResource, invalidResponse, integrityFailure }
    private let cacheURL: URL
    private let baseURL: URL
    private let session: URLSession
    private var pending: [String: Task<Data, Error>] = [:]

    public init(baseURL: URL = URL(string: "https://raw.githubusercontent.com/Chorus-ACE/Sekai-3D-Assets/main/regions/")!, cacheURL: URL? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.cacheURL = cacheURL ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("SekaiKit/Models3D", isDirectory: true)
    }

    /// Loads only the requested region's index. There is no cross-region fallback.
    public func catalog(for locale: SekaiLocale) async throws -> Model3DCatalog {
        let url = baseURL.appendingPathComponent(locale.rawValue + ".json")
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 64 * 1024 * 1024 else { throw Failure.invalidResponse }
        let catalog = try JSONDecoder().decode(Model3DCatalog.self, from: data)
        guard catalog.schemaVersion == 1, catalog.region == locale else { throw Failure.invalidManifest }
        return catalog
    }

    /// Loads the clothing, hairstyles and accessories of exactly one game region.
    public func library(for locale: SekaiLocale) async throws -> Model3DLibrary {
        try Model3DLibrary(catalog: await catalog(for: locale))
    }

    public func resource(at path: String, in configuration: Model3DRenderConfiguration) async throws -> Data {
        try await resource(at: path, in: configuration.catalog)
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
            let (temporary, response) = try await session.download(from: reference.url)
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
