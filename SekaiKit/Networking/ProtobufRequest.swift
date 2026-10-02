import Foundation
internal import CryptoKit
internal import SwiftProtobuf

/// Configuration for loading the Protobuf archives published by JSON2Proto.
public enum SekaiProtobuf {
    /// The task-local directory URL containing the `.aar` archives.
    ///
    /// Override this value with `$baseURL.withValue` to use a mirror or a directory
    /// of local fixtures for the current operation.
    @TaskLocal public static var baseURL = URL(string: "https://raw.githubusercontent.com/Chorus-ACE/Sekai-Protobuf-Assets/refs/heads/main/")!

    internal static var cacheKey: String {
        SHA256.hash(data: Data(baseURL.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

internal protocol RegionalProtobufList: SwiftProtobuf.Message {
    associatedtype Item
    var jp: [Item] { get }
    var en: [Item] { get }
    var tc: [Item] { get }
    var cn: [Item] { get }
    var kr: [Item] { get }
}

extension RegionalProtobufList {
    func items(in locale: SekaiLocale) -> [Item] {
        switch locale {
        case .jp: jp
        case .en: en
        case .tw: tc
        case .cn: cn
        case .kr: kr
        }
    }
}

extension _CharacterList: RegionalProtobufList {}
extension _EventList: RegionalProtobufList {}
extension _CardList: RegionalProtobufList {}

internal func requestProtobuf<Message: SwiftProtobuf.Message>(
    _ file: String, as type: Message.Type
) async -> Message? {
    let url = SekaiProtobuf.baseURL.appending(path: file)
    let expectedFile = url.deletingPathExtension().lastPathComponent + ".proto"
    func decode(_ data: Data) -> Message? {
        guard let bytes = try? ProtobufArchive.decode(data, expectedFile: expectedFile) else { return nil }
        return try? Message(serializedBytes: bytes)
    }
    if let data = await SekaiCache._dataFromPreloaded(url),
       let message = decode(data) {
        return message
    }
    if SekaiCache.preferCachedNetworkSource,
       let cache = await NetworkCache.shared.getCache(for: url),
       Date.now.timeIntervalSince(cache.dateUpdated) < 3600,
       let message = decode(cache.data) {
        SekaiCache._finishedLoadSource?(url, cache.data)
        return message
    }
    guard let data = await ProtobufDownloads.shared.data(from: url),
          let message = decode(data) else { return nil }
    if SekaiCache.preferCachedNetworkSource {
        await NetworkCache.shared.updateCache(.init(data: data), for: url)
    }
    SekaiCache._finishedLoadSource?(url, data)
    return message
}

// all() requests five locales concurrently. Share only the in-flight download;
// later calls still revalidate the source, including .realTime cache requests.
internal actor ProtobufDownloads {
    static let shared = ProtobufDownloads()
    private var pending: [URL: Task<Data?, Never>] = [:]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(from url: URL) async -> Data? {
        if let task = pending[url] { return await task.value }
        let task = Task<Data?, Never> {
            if url.isFileURL { return try? Data(contentsOf: url) }
            do {
                let request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData)
                let (data, response) = try await session.data(for: request)
                guard let response = response as? HTTPURLResponse,
                      (200..<300).contains(response.statusCode) else { return nil }
                return data
            } catch {
                return nil
            }
        }
        pending[url] = task
        let data = await task.value
        pending[url] = nil
        return data
    }
}

internal func protobufDate(_ milliseconds: Int64, present: Bool) -> LocalizableData<Date> {
    .unlocalized(present ? Date(timeIntervalSince1970: Double(milliseconds) / 1000) : nil)
}
