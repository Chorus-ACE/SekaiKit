import Foundation
internal import SwiftyJSON

/// A playable story episode in a specific regional edition.
public struct Episode: Hashable, Codable, Identifiable, Sendable, SekaiCachable {
    public var id: String { "\(locale.rawValue)-\(kind.rawValue)-\(episodeID)" }
    public var episodeID: Int
    public var parentID: Int
    public var number: Int
    public var title: String
    public var chapterTitle: String
    public var scenarioID: String
    public var scenarioPath: String
    public var imagePath: String?
    public var locale: SekaiLocale
    public var kind: Kind
    /// The edition's own episode heading, independent of the ordering number.
    public var numberLabel: String? = nil
    public var characterID: Int? = nil

    public enum Kind: String, CaseIterable, Codable, Hashable, Sendable, SekaiCachable {
        case event, unit, card
        public var localizedName: String {
            switch self.rawValue {
            case "card": NSLocalizedString("Episode.kind.card", bundle: #bundle, comment: "")
            case "event": NSLocalizedString("Episode.kind.event", bundle: #bundle, comment: "")
            case "unit": NSLocalizedString("Episode.kind.unit", bundle: #bundle, comment: "")
            default: String(describing: self.rawValue)
            }
        }
    }
    public var imageURL: URL? {
        imagePath.flatMap { URL(string: "https://storage.sekai.best/\(locale._assetsPath)/\($0)") }
    }
    public var scenarioURL: URL? {
        URL(string: "https://storage.sekai.best/\(locale._assetsPath)/\(scenarioPath)")
    }
    public static func all(in locale: SekaiLocale, kind: Kind) async -> [Episode]? {
        guard let list = await requestProtobuf("episode.aar", as: _EpisodeList.self) else { return nil }
        var episodes = list.items(in: locale).filter { $0.kind == kind.rawValue }.map { Episode(protobuf: $0, locale: locale, kind: kind) }
        // Older archives did not retain headings or World Link character associations.
        if kind != .card, !episodes.contains(where: { $0.numberLabel != nil || $0.characterID != nil }),
           let json = await requestJSON("https://raw.githubusercontent.com/Sekai-World/\(locale._databasePath)/main/\(kind == .unit ? "unitStories" : "eventStories").json"),
           let rows = json.array {
            let current = parse(rows, in: locale, kind: kind)
            let headings = Dictionary(current.map { ($0.episodeID, $0) }, uniquingKeysWith: { first, _ in first })
            for index in episodes.indices {
                episodes[index].numberLabel = headings[episodes[index].episodeID]?.numberLabel
                episodes[index].characterID = headings[episodes[index].episodeID]?.characterID
            }
        }
        let characters = episodes.contains { $0.characterID != nil } ? await Character.allInLocale(locale) : nil
        return applyingHeadings(to: episodes, characterNames: Dictionary((characters ?? []).map {
            ($0.id, $0.fullName.majorValue ?? "#\($0.id)")
        }, uniquingKeysWith: { first, _ in first }))
    }

    internal static func applyingHeadings(to episodes: [Episode], characterNames: [Int: String]) -> [Episode] {
        var result = episodes
        for group in Dictionary(grouping: episodes.indices, by: { episodes[$0].parentID }).values {
            let ordered = group.sorted { episodes[$0].number < episodes[$1].number }
            guard let firstCharacter = ordered.firstIndex(where: { episodes[$0].characterID != nil }),
                  let lastCharacter = ordered.lastIndex(where: { episodes[$0].characterID != nil }),
                  let first = ordered.first, episodes[first].kind == .event else { continue }
            for (position, index) in ordered.enumerated() where result[index].numberLabel == nil {
                let episode = episodes[index]
                let peers: [Int]
                let base: String
                if let characterID = episode.characterID {
                    peers = ordered.filter { episodes[$0].characterID == characterID }
                    base = characterNames[characterID] ?? "#\(characterID)"
                } else if position < firstCharacter {
                    peers = Array(ordered[..<firstCharacter])
                    base = headingWords(in: episode.locale).opening
                } else if position > lastCharacter {
                    peers = Array(ordered[(lastCharacter + 1)...])
                    base = headingWords(in: episode.locale).ending
                } else { continue }
                let part = peers.firstIndex(of: index) ?? 0
                let words = headingWords(in: episode.locale)
                let suffix = peers.count == 2 ? (part == 0 ? words.first : words.second) : "\(part + 1)"
                result[index].numberLabel = peers.count == 1 ? base : base + " " + suffix
            }
        }
        return result
    }

    private static func headingWords(in locale: SekaiLocale) -> (opening: String, ending: String, first: String, second: String) {
        switch locale {
        case .jp: ("オープニング", "エンディング", "前編", "後編")
        case .en: ("Opening", "Ending", "Part 1", "Part 2")
        case .tw: ("序幕", "結尾", "前篇", "後篇")
        case .cn: ("序幕", "结尾", "前篇", "后篇")
        case .kr: ("오프닝", "엔딩", "전편", "후편")
        }
    }
    internal static func parse(_ items: [JSON], in locale: SekaiLocale, kind: Kind) -> [Episode] {
        func episode(_ json: JSON, parentID: Int, chapter: String, bundle: String) -> Episode? {
            guard let id = json["id"].int, let title = json["title"].string,
                  let scenario = json["scenarioId"].string, !scenario.isEmpty else { return nil }
            let path: String
            var image: String?
            switch kind {
            case .event:
                path = "event_story/\(bundle)/scenario/\(scenario).asset"
                if let cover = json["assetbundleName"].string { image = "event_story/\(bundle)/episode_image/\(cover).webp" }
            case .unit:
                path = "scenario/unitstory/\(bundle)/\(scenario).asset"
                if let cover = json["assetbundleName"].string { image = "story/episode_image/\(bundle)/\(cover).webp" }
            case .card:
                let directory = locale == .en ? "member_scenario" : "member"
                path = "character/\(directory)/\(bundle)/\(scenario).asset"
                image = "character/member_small/\(bundle)/card_normal.webp"
            }
            return Episode(episodeID: id, parentID: parentID, number: json["episodeNo"].int ?? json["seq"].int ?? 0,
                           title: title, chapterTitle: chapter, scenarioID: scenario, scenarioPath: path, imagePath: image, locale: locale, kind: kind)
                .withHeading(json)
        }
        return items.flatMap { item -> [Episode] in
            switch kind {
            case .event:
                return item["eventStoryEpisodes"].arrayValue.compactMap {
                    episode($0, parentID: item["eventId"].intValue, chapter: item["outline"].stringValue, bundle: item["assetbundleName"].stringValue)
                }
            case .unit:
                return item["chapters"].arrayValue.flatMap { chapter in
                    chapter["episodes"].arrayValue.compactMap {
                        episode($0, parentID: chapter["id"].intValue, chapter: chapter["title"].stringValue, bundle: chapter["assetbundleName"].stringValue)
                    }
                }
            case .card:
                guard let bundle = item["assetbundleName"].string, !bundle.isEmpty else { return [] }
                return [episode(item, parentID: item["cardId"].intValue, chapter: "", bundle: bundle)].compactMap { $0 }
            }
        }
    }
}

extension Episode {
    private func withHeading(_ json: JSON) -> Self {
        var result = self
        result.numberLabel = json["episodeNoLabel"].string
        result.characterID = json["gameCharacterId"].int
        return result
    }
}

/// A transcript in script order, including dialogue and location/title captions.
public struct StoryTranscript: Hashable, Codable, Sendable, SekaiCachable {
    public var lines: [Line]
    public struct Line: Hashable, Codable, Identifiable, Sendable {
        public enum TextKind: String, Codable, Sendable {
            case dialogue, caption, narration
        }
        // Optional so transcripts cached before text kinds were recorded still decode.
        public var textKind: TextKind? = nil
        public var id: Int
        public var speaker: String
        public var text: String
        public var characterIDs: [Int]?
        public var voiceURL: URL?
    }
    public static func load(_ episode: Episode) async -> StoryTranscript? {
        guard let url = episode.scenarioURL else { return nil }
        async let script = requestJSON(url.absoluteString)
        async let catalog = requestProtobuf("episode.aar", as: _EpisodeList.self)
        guard let json = await script else { return nil }
        let mapping = Dictionary((await catalog?.characterModels.items(in: episode.locale) ?? []).map {
            (Int($0.id), Int($0.characterID))
        }, uniquingKeysWith: { first, _ in first })
        return StoryTranscript(json: json, episode: episode, characterMapping: mapping)
    }
    internal init?(json: JSON, episode: Episode? = nil, characterMapping: [Int: Int] = [:]) {
        guard let snippets = json["Snippets"].array, let talks = json["TalkData"].array else { return nil }
        lines = snippets.enumerated().compactMap { offset, snippet in
            guard let index = snippet["ReferenceIndex"].int else { return nil }
            if snippet["Action"].int == 1, talks.indices.contains(index),
               let text = talks[index]["Body"].string, !text.isEmpty {
                let talk = talks[index]
                let ids = Array(Set(talk["TalkCharacters"].arrayValue.compactMap { characterMapping[$0["Character2dId"].intValue] })).sorted()
                var voiceURL: URL?
                if let episode, let voice = talk["Voices"].arrayValue.first?["VoiceId"].string,
                   !voice.hasPrefix("partvoice") {
                    var bundle = json["ScenarioId"].string ?? episode.scenarioID
                    // Sekai Viewer's documented event voice-bundle offset.
                    let parts = bundle.split(separator: "_")
                    if parts.count > 1, parts[0] == "event", let number = Int(parts[1]), (167...176).contains(number) {
                        bundle = bundle.replacingOccurrences(of: "event_\(number)", with: "event_\(number + 1)")
                    }
                    let aliases = ["★4冬弥・泉_前半": "012043_touya01", "★4司・千秋_前半": "013042_tsukasa01", "★4類・夏目_後半": "016042_rui02"]
                    bundle = aliases[bundle] ?? bundle
                    let category = episode.kind == .card ? "card_scenario" : "scenario"
                    voiceURL = URL(string: "https://storage.sekai.best/\(episode.locale._assetsPath)/sound/\(category)/voice/\(bundle)/\(voice).mp3")
                }
                return Line(textKind: .dialogue, id: offset, speaker: talk["WindowDisplayName"].stringValue, text: text, characterIDs: ids, voiceURL: voiceURL)
            }
            let effects = json["SpecialEffectData"].arrayValue
            if snippet["Action"].int == 6, effects.indices.contains(index),
               [8, 18, 24, 38].contains(effects[index]["EffectType"].intValue),
               let text = effects[index]["StringVal"].string, !text.isEmpty {
                return Line(textKind: effects[index]["EffectType"].int == 24 ? .narration : .caption,
                            id: offset, speaker: "", text: text, characterIDs: nil, voiceURL: nil)
            }
            return nil
        }
    }
}
