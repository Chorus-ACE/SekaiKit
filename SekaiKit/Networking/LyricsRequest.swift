import Foundation

/// Configuration and fetching for the independently updated lyrics repository.
public enum SekaiLyrics {
    /// Override for a mirror or local fixture directory.
    @TaskLocal public static var baseURL = URL(string: "https://raw.githubusercontent.com/Chorus-ACE/Sekai-Lyrics/main/lyrics/")!

    public enum Failure: Error, Equatable, Sendable {
        case invalidSongID
        case httpStatus(Int)
        case mismatchedSongID
    }

    public static func lyrics(forSongID id: Int) async throws -> Song.Lyrics? {
        guard id > 0 else { throw Failure.invalidSongID }
        let url = baseURL.appending(path: "music_\(id).json")
        func decode(_ data: Data) throws -> Song.Lyrics {
            let lyrics = try JSONDecoder().decode(Song.Lyrics.self, from: data)
            guard lyrics.songID == id else { throw Failure.mismatchedSongID }
            return lyrics
        }
        if let data = await SekaiCache._dataFromPreloaded(url) { return try decode(data) }
        if SekaiCache.preferCachedNetworkSource,
           let cache = await NetworkCache.shared.getCache(for: url),
           Date.now.timeIntervalSince(cache.dateUpdated) < 3600 {
            let lyrics = try decode(cache.data)
            SekaiCache._finishedLoadSource?(url, cache.data)
            return lyrics
        }
        try Task.checkCancellation()
        let data: Data
        if url.isFileURL {
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            data = try Data(contentsOf: url)
        } else {
            var request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData)
            request.timeoutInterval = 30
            let (received, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            if response.statusCode == 404 { return nil }
            guard (200..<300).contains(response.statusCode) else { throw Failure.httpStatus(response.statusCode) }
            data = received
        }
        try Task.checkCancellation()
        let lyrics = try decode(data)
        if SekaiCache.preferCachedNetworkSource {
            await NetworkCache.shared.updateCache(.init(data: data), for: url)
        }
        SekaiCache._finishedLoadSource?(url, data)
        return lyrics
    }
}
