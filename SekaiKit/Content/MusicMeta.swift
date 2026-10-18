import Foundation
internal import SwiftyJSON

/// Chart statistics published by Sekai Viewer. Scores are source coefficients, not a simulated team score.
public struct MusicMeta: Hashable, Codable, Identifiable, Sendable, SekaiCachable {
    public var id: String { "\(musicID)-\(difficulty.rawValue)" }
    public var musicID: Int
    public var difficulty: Song.Difficulty
    public var duration: Double
    public var baseScore: Double
    public var feverScore: Double
    public var eventRate: Double

    public static func all() async -> [MusicMeta]? {
        guard let json = await requestJSON("https://storage.sekai.best/sekai-best-assets/music_metas.json"), let items = json.array else { return nil }
        return items.compactMap(MusicMeta.init(json:))
    }
    internal init?(json: JSON) {
        guard let id = json["music_id"].int,
              let difficulty = Song.Difficulty(rawValue: json["difficulty"].stringValue),
              let duration = json["music_time"].double, duration.isFinite, duration > 0,
              let base = json["base_score"].double, base.isFinite,
              let fever = json["fever_score"].double, fever.isFinite,
              let rate = json["event_rate"].double, rate.isFinite else { return nil }
        musicID = id
        self.difficulty = difficulty
        self.duration = duration
        baseScore = base
        feverScore = fever
        eventRate = rate
    }
}
