import Foundation

/// An announcement from one edition's userInformations master table.
public struct NewsItem: Hashable, Identifiable, Sendable, Codable, SekaiCachable {
    public var id: String { "\(locale.rawValue)-\(newsID)" }
    public let newsID: Int
    public let locale: SekaiLocale
    public let sequence: Int
    public let displayOrder: Int?
    public let informationType: String
    public let tagName: String
    public var tag: Tag { Tag(rawValue: tagName) ?? .unknown }
    public let browseType: String
    public let platform: String
    public let title: String?
    public var displayTitle: String { title ?? contentURL?.host ?? "#\(newsID)" }
    public let path: String
    public let startDate: Date
    public let endDate: Date?
    public let bannerAssetBundleName: String?

    public enum Tag: String, CaseIterable, Codable, Sendable {
        case information, event, gacha, music, campaign, bug, update, unknown
        public var localizedName: String { switch self.rawValue {
            case "information": NSLocalizedString("News.tag.information", bundle: #bundle, comment: "")
            case "event": NSLocalizedString("News.tag.event", bundle: #bundle, comment: "")
            case "gacha": NSLocalizedString("News.tag.gacha", bundle: #bundle, comment: "")
            case "music": NSLocalizedString("News.tag.music", bundle: #bundle, comment: "")
            case "campaign": NSLocalizedString("News.tag.campaign", bundle: #bundle, comment: "")
            case "bug": NSLocalizedString("News.tag.bug", bundle: #bundle, comment: "")
            case "update": NSLocalizedString("News.tag.update", bundle: #bundle, comment: "")
            case "unknown": NSLocalizedString("News.tag.unknown", bundle: #bundle, comment: "")
            default: String(describing: self.rawValue)
            } }
    }

    /// Absolute regional links are authoritative. Only JP and EN use relative paths.
    public var contentURL: URL? {
        let path = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, ["internal", "external"].contains(browseType) else { return nil }
        if let url = URL(string: path), let scheme = url.scheme {
            return ["https", "http"].contains(scheme.lowercased()) && url.host != nil ? url : nil
        }
        guard browseType == "internal", !path.hasPrefix("//"), !path.contains("\\") else { return nil }
        let base: URL
        switch locale {
        case .jp: base = URL(string: "https://production-web.sekai.colorfulpalette.org/")!
        case .en: base = URL(string: "https://n-production-web.sekai-en.com/")!
        default: return nil
        }
        return URL(string: path, relativeTo: base)?.absoluteURL
    }

    public static func all(in locale: SekaiLocale) async throws -> [NewsItem] {
        let url = URL(string: "https://raw.githubusercontent.com/Sekai-World/\(locale._databasePath)/main/userInformations.json")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        try Task.checkCancellation()
        return try decode(data, in: locale)
    }

    internal static func decode(_ data: Data, in locale: SekaiLocale) throws -> [NewsItem] {
        struct Record: Decodable {
            let id: Int
            let seq: Int
            let displayOrder: Int?
            let informationType: String
            let informationTag: String
            let browseType: String
            let platform: String
            let title: String?
            let path: String
            let startAt: Double
            let endAt: Double?
            let bannerAssetbundleName: String?
        }
        return try JSONDecoder().decode([Record].self, from: data).map {
            NewsItem(newsID: $0.id, locale: locale, sequence: $0.seq, displayOrder: $0.displayOrder,
                     informationType: $0.informationType, tagName: $0.informationTag, browseType: $0.browseType,
                     platform: $0.platform, title: $0.title, path: $0.path,
                     startDate: Date(timeIntervalSince1970: $0.startAt / 1000),
                     endDate: $0.endAt.map { Date(timeIntervalSince1970: $0 / 1000) },
                     bannerAssetBundleName: $0.bannerAssetbundleName)
        }.sorted { $0.startDate == $1.startDate ? $0.newsID > $1.newsID : $0.startDate > $1.startDate }
    }
}
