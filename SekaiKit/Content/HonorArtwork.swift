import Foundation

extension HonorGroup {
    public enum Kind: String, Codable, Hashable, Sendable, CaseIterable {
        case character, event, achievement, birthday
        case rankMatch = "rank_match"
        case unknown
        public var localizedName: String {
            switch self {
            case .character: String(localized: "Honor.kind.character", bundle: .module)
            case .event: String(localized: "Honor.kind.event", bundle: .module)
            case .achievement: String(localized: "Honor.kind.achievement", bundle: .module)
            case .birthday: String(localized: "Honor.kind.birthday", bundle: .module)
            case .rankMatch: String(localized: "Honor.kind.rank-match", bundle: .module)
            case .unknown: String(localized: "Honor.kind.unknown", bundle: .module)
            }
        }
    }
    public var type: Kind { Kind(rawValue: honorType ?? "") ?? .unknown }
}

extension Honor {
    /// Regional layers in a 380 × 80 title. Event/ranked titles are not single images.
    public struct Artwork: Hashable, Sendable {
        public var backgroundURLs: [URL]
        public var overlayURLs: [URL]
        public var frameURLs: [URL]
        public var overlayRect: CGRect
        public var rarity: Rarity
        public var medalLevel: Int?
        public var birthdayMedals: Bool
    }

    public func artwork(in locale: SekaiLocale? = nil, level: Int? = nil) -> Artwork? {
        let locale = locale ?? record.majorLocale ?? .primaryLocale
        guard let configuration = record.value(in: locale) else { return nil }
        let selectedLevel = level.flatMap { selected in configuration.levels?.first { $0.level == selected } }
            ?? configuration.levels?.min(by: { ($0.level ?? 0) < ($1.level ?? 0) })
        let bundle = selectedLevel?.assetBundleName ?? configuration.assetBundleName
        guard let bundle, !bundle.isEmpty else { return nil }
        let group = configuration.group
        let isRankMatch = group?.type == .rankMatch
        let background = group?.backgroundAssetBundleName ?? bundle
        let directory = isRankMatch ? "rank_live/honor" : "honor"
        func images(_ path: String) -> [URL] {
            ["webp", "png"].compactMap { URL(string: "https://storage.sekai.best/\(locale._assetsPath)/\(path).\($0)") }
        }
        var overlayURLs: [URL] = []
        if isRankMatch {
            overlayURLs = images("rank_live/honor/\(bundle)/main")
        } else if group?.type == .event {
            overlayURLs = images("honor/\(bundle)/rank_main")
        } else if configuration.honorMissionType != nil {
            overlayURLs = images("honor/\(bundle)/scroll")
        }
        let rarity = Rarity(rawValue: selectedLevel?.honorRarity ?? configuration.honorRarity ?? "") ?? .unknown
        let rarityNumber = [Rarity.low: 1, .middle: 2, .high: 3, .highest: 4][rarity]
        let frameURLs: [URL]
        if let frame = group?.frameName, let rarityNumber {
            frameURLs = images("honor_frame/\(frame)/frame_degree_m_\(rarityNumber)")
        } else { frameURLs = [] }
        let fullOverlay = bundle.range(of: #"_cp\d+$"#, options: .regularExpression) != nil
        let rect = fullOverlay ? CGRect(x: 0, y: 0, width: 1, height: 1)
            : CGRect(x: 200.0 / 380, y: 0, width: 180.0 / 380, height: 78.0 / 80)
        return Artwork(backgroundURLs: images("\(directory)/\(background)/degree_main"),
                       overlayURLs: overlayURLs, frameURLs: frameURLs, overlayRect: rect, rarity: rarity,
                       medalLevel: group?.isMedalDisplayed == true ? (level ?? selectedLevel?.level) : nil,
                       birthdayMedals: group?.type == .birthday)
    }

    /// The artwork's background; use `artwork` to render rank/frame overlays as well.
    public func imageURL(in locale: SekaiLocale? = nil, level: Int? = nil) -> URL? {
        artwork(in: locale, level: level)?.backgroundURLs.first
    }
}
