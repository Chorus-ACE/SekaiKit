//
//  Event.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/1/16.
//


import Foundation

public struct Event: Codable, Hashable, Identifiable, Sendable, SekaiCachable {
    public var id: Int
    public var title: String
    public var eventType: Event.EventType
    
    /// The time when the event starts displaying, aka `eventOnlyComponentDisplayStartAt`.
    public var displayingStartDate: Date
    /// The time when the event starts, aka `startAt`.
    public var startDate: Date
    /// The time when the event aggregates, aka `aggregateAt`.
    public var aggregateDate: Date
    /// The time when the ranking of the event is announced, aka `rankingAnnounceAt`.
    public var rankingAnnouncementDate: Date
    /// The time when distribution of the rewards starts, aka `distributionStartAt`
    public var distributionStartDate: Date
    /// The time when the event stops displaying, aka `eventOnlyComponentDisplayEndAt`.
    public var displayingEndDate: Date
    /// The time when the event closes, aka `closedAt`.
    public var closedDate: Date
    /// The time when distribution of the rewards ends, aka `distributionEndAt`.
    public var distributionEndDate: Date
    
    
    public var virturalLiveID: Int?
    public var unit: Unit?
    public var isCountLeaderCharacterPlay: Bool // Rarely `true`
    public var eventRankingRewardRanges: [EventRankingRewardRange]
    
    public var assetBundleName: String
    public var bgmAssetbundleName: String
    
    public enum EventType: String, CaseIterable, Codable, Hashable, SekaiCachable, Sendable {
        case marathon
        case cheerfulCarnival = "cheerful_carnival"
        case worldLink = "world_bloom"
    }
    
    public struct EventRankingRewardRange: Codable, Hashable, Sendable, SekaiCachable {
//        var id: Int
        public var upperBound: Int
        public var lowerBound: Int
        public var includeLowerBound: Bool // `true` -> Range, `false` -> ClosedRange
        public var eventRankingRewards: [EventRankingReward]
        
        public struct EventRankingReward: Codable, Hashable, Sendable, SekaiCachable {
//            var id: Int
//            var eventRankingRewardRangeId: Int
            public var resourceBoxId: Int
            public var rewardConditionType: String?
        }
    }
}

extension Event {
    public static func all(forLocale locale: SekaiLocale = .primaryLocale) async -> [Event]? {
        let groupResult = await withTasksResult {
            await requestJSON("https://sekai-world.github.io/\(locale._databasePath)/events.json")
        } _: {
            await requestJSON("https://sekai-world.github.io/\(locale._databasePath)/eventStories.json")
//        } _: {
//            await requestJSON("https://sekai-world.github.io/\(locale.databasePath)/gameCharacterUnits.json")
        }
        
        guard let alfa = groupResult.0 else { return nil }
        guard let bravo = groupResult.1 else { return nil }
//        let charlie = groupResult.2
        
        let task = Task.detached(priority: .userInitiated) {
            var result: [Event] = []
            for (key, av) in alfa {
                var eventRankingRewardRange: [EventRankingRewardRange] = []
                for range in av["eventRankingRewardRanges"].arrayValue {
                    var singleRangeRewards: [EventRankingRewardRange.EventRankingReward] = []
                    for reward in range["eventRankingRewards"].arrayValue {
                        singleRangeRewards.append(EventRankingRewardRange.EventRankingReward(resourceBoxId: reward["resourceBoxId"].intValue, rewardConditionType: reward["rewardConditionType"].string))
                    }
                    
                    eventRankingRewardRange.append(EventRankingRewardRange(upperBound: range["fromRank"].intValue, lowerBound: range["toRank"].intValue, includeLowerBound: range["isToRankBorder"].boolValue, eventRankingRewards: singleRangeRewards))
                }
                
                result.append(Event(
                    id: av["id"].intValue,
                    title: av["name"].stringValue,
                    eventType: EventType(rawValue: av["eventType"].stringValue) ?? .marathon,
                    displayingStartDate: av["eventOnlyComponentDisplayStartAt"].dateValue,
                    startDate: av["startAt"].dateValue,
                    aggregateDate: av["aggregateAt"].dateValue,
                    rankingAnnouncementDate: av["rankingAnnounceAt"].dateValue,
                    distributionStartDate: av["distributionStartAt"].dateValue,
                    displayingEndDate: av["eventOnlyComponentDisplayEndAt"].dateValue,
                    closedDate: av["closedAt"].dateValue,
                    distributionEndDate: av["distributionEndAt"].dateValue,
                    virturalLiveID: av["virturalLiveId"].int,
                    unit: Unit(rawValue: av["unit"].stringValue),
                    isCountLeaderCharacterPlay: av["isCountLeaderCharacterPlay"].boolValue,
                    eventRankingRewardRanges: eventRankingRewardRange,
                    assetBundleName: av["assetbundleName"].stringValue,
                    bgmAssetbundleName: av["assetbundleName"].stringValue
                ))
//                guard let bv = bravo.arrayValue[access: Int(key)!] else { continue }
            }
            return result
        }
        return await task.value
    }
}

public struct ExtendedCharacter: Codable, Hashable, Identifiable, Sendable, SekaiCachable {
    public var character: Character
    
    public var id: Int { self.character.id }
}

extension Character: ExtendedTypeConvertible {
    public typealias ExtendedType = ExtendedCharacter
}
