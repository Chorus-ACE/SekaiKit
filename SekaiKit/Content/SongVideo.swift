import Foundation

extension Song {
    /// Video availability and original upload links from one region's own record.
    public struct VideoContent: Hashable, Sendable {
        public var videos: [MusicVideo]
        public var externalURLs: [URL]
    }

    public struct MusicVideo: Hashable, Identifiable, Sendable {
        public var id: String { "\(locale.rawValue)-\(mediaType.rawValue)-\(assetBundleName)" }
        public var locale: SekaiLocale
        public var mediaType: MediaType
        public var assetBundleName: String
        public var caption: String?

        /// The extracted movie filename comes from the bundle's own metadata.
        public func videoURL() async -> URL? {
            let directory = mediaType == .originalMV ? "original_mv" : "sekai_mv"
            let base = "https://storage.sekai.best/\(locale._assetsPath)/live/2dmode/\(directory)/\(assetBundleName)_rip"
            guard let data = await requestJSON("\(base)/moviebundlebuilddata.asset"),
                  let name = data["movieBundleDatas"].array?.first?["usmFileName"].string else { return nil }
            let filename = name.replacingOccurrences(of: #"(-\d{3})?\.usm\.bytes$"#, with: "", options: .regularExpression).lowercased()
            guard !filename.isEmpty, !filename.contains("/"), !filename.contains("\\") else { return nil }
            return URL(string: "\(base)/\(filename).mp4")
        }
    }

    public func videoContent() async -> LocalizedData<VideoContent>? {
        guard let list = await requestProtobuf("song.aar", as: _SongList.self) else { return nil }
        return LocalizedData { locale in
            list.items(in: locale).first(where: { $0.id == id }).map {
                Self.videoContent(protobuf: $0, locale: locale)
            }
        }
    }

    public func videoContent(in locale: SekaiLocale) async -> VideoContent? {
        guard let list = await requestProtobuf("song.aar", as: _SongList.self),
              let record = list.items(in: locale).first(where: { $0.id == id }) else { return nil }
        return Self.videoContent(protobuf: record, locale: locale)
    }

    internal static func videoContent(protobuf record: _Song, locale: SekaiLocale) -> VideoContent {
        var videos: [MusicVideo] = []
        for type in [MediaType._2DMV, .originalMV] where record.media.contains(type.rawValue) {
            let defaultBundle = String(format: "%04d", record.id)
            let variants = type == ._2DMV ? record.assetVariants.filter { $0.musicAssetType == "mv" } : []
            let overriddenVocals = Set(variants.map(\.musicVocalID))
            let hasDefaultVideo = variants.isEmpty || record.vocals.contains { !overriddenVocals.contains($0.id) }
            if hasDefaultVideo {
                videos.append(MusicVideo(locale: locale, mediaType: type, assetBundleName: defaultBundle))
            }
            if !variants.isEmpty {
                for variant in variants.sorted(by: { ($0.seq, $0.id) < ($1.seq, $1.id) }) {
                    guard !videos.contains(where: { $0.mediaType == type && $0.assetBundleName == variant.assetbundleName }) else { continue }
                    let vocal = record.vocals.first { $0.id == variant.musicVocalID }
                    videos.append(MusicVideo(locale: locale, mediaType: type, assetBundleName: variant.assetbundleName,
                                             caption: vocal.flatMap { $0.hasCaption ? $0.caption : nil }))
                }
            }
        }
        var seen = Set<URL>()
        let links = record.originalVideoLinks.compactMap(URL.init(string:)).filter {
            ["http", "https"].contains($0.scheme?.lowercased() ?? "") && seen.insert($0).inserted
        }
        return VideoContent(videos: videos, externalURLs: links)
    }
}
