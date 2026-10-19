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

    public enum Kind: String, CaseIterable, Codable, Hashable, Sendable, SekaiCachable {
        case event, unit, card
        public var localizedName: String {
            NSLocalizedString("Episode.kind.\(rawValue)", bundle: #bundle, comment: "")
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
        return list.items(in: locale).filter { $0.kind == kind.rawValue }.map { Episode(protobuf: $0, locale: locale, kind: kind) }
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

/// A transcript in script order, including dialogue and location/title captions.
public struct StoryTranscript: Hashable, Codable, Sendable, SekaiCachable {
    public var lines: [Line]
    public struct Line: Hashable, Codable, Identifiable, Sendable {
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
                return Line(id: offset, speaker: talk["WindowDisplayName"].stringValue, text: text, characterIDs: ids, voiceURL: voiceURL)
            }
            let effects = json["SpecialEffectData"].arrayValue
            if snippet["Action"].int == 6, effects.indices.contains(index),
               [8, 18, 24, 38].contains(effects[index]["EffectType"].intValue),
               let text = effects[index]["StringVal"].string, !text.isEmpty {
                return Line(id: offset, speaker: "", text: text, characterIDs: nil, voiceURL: nil)
            }
            return nil
        }
    }
}
