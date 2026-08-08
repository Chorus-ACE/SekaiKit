//
//  Event.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/1/16.
//


import Foundation
import SekaiKitMacro

@LocalizationsCombinable
public struct Event: Codable, Hashable, Identifiable, Sendable, SekaiCachable, LocalizationsCombinable {
    public var id: Int
    public var title: LocalizableData<String>
    public var eventType: Event.EventType
    
    /// The time when the event starts displaying, aka `eventOnlyComponentDisplayStartAt`.
    public var displayingStartDate: LocalizableData<Date>
    /// The time when the event starts, aka `startAt`.
    public var startDate: LocalizableData<Date>
    /// The time when the event aggregates, aka `aggregateAt`.
    public var aggregateDate: LocalizableData<Date>
    /// The time when the ranking of the event is announced, aka `rankingAnnounceAt`.
    public var rankingAnnouncementDate: LocalizableData<Date>
    /// The time when distribution of the rewards starts, aka `distributionStartAt`
    public var distributionStartDate: LocalizableData<Date>
    /// The time when the event stops displaying, aka `eventOnlyComponentDisplayEndAt`.
    public var displayingEndDate: LocalizableData<Date>
    /// The time when the event closes, aka `closedAt`.
    public var closedDate: LocalizableData<Date>
    /// The time when distribution of the rewards ends, aka `distributionEndAt`.
    public var distributionEndDate: LocalizableData<Date>
    
    public var unit: Unit?
    public var attribute: Card.Attribute?
    public var characters: [Int]
    
    public var attributeBonus: Int?
    public var characterBonus: Int
    
    public var virturalLiveID: Int
    
    public var isCountLeaderCharacterPlay: Bool // Rarely `true`
    public var eventRankingRewardRanges: [EventRankingRewardRange]
    
    public var assetBundleName: String
    public var bgmAssetbundleName: String
    
    public enum EventType: String, CaseIterable, Codable, Hashable, SekaiCachable, Sendable {
        case marathon
        case cheerfulCarnival = "cheerful_carnival"
        case worldLink = "world_bloom"
        
        public var localizedName: String {
            NSLocalizedString("Event.type.\(self.rawValue)", bundle: #bundle, comment: "")
        }
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

extension Event: ListGettable {
    public static func allInLocale(_ locale: SekaiLocale = .primaryLocale) async -> [Event]? {
        let groupResult = await withTasksResult {
            await requestJSON("https://sekai-world.github.io/\(locale._databasePath)/events.json")
        } _: {
            await requestJSON("https://sekai-world.github.io/\(locale._databasePath)/eventDeckBonuses.json")
        }
        
        guard let alfa = groupResult.0 else { return nil }
        guard let bravo = groupResult.1 else { return nil }
        
        let task = Task.detached(priority: .userInitiated) {
            var result: [Event] = []
            
            var charResult: [Int: [Int]] = [:]
            var charPercentResult: [Int: Int] = [:]
            var attrResult: [Int: Card.Attribute] = [:]
            var attrPercentResult: [Int: Int] = [:]
            
            for (_, value) in bravo {
                let eventID = value["eventId"].intValue
                
                let char = value["gameCharacterUnitId"].int
                let attr = value["cardAttr"].string
                
                let percentage = value["bonusRate"].intValue
                
                if let char, attr == nil {
                    let castedChar = Character.mapVirtualSingerID(char, includeMiku: true)
                    if !(charResult[eventID]?.contains(castedChar) ?? false) {
                        charResult[eventID] = (charResult[eventID] ?? []) + [castedChar]
                    }
                    charPercentResult[eventID] = percentage
                } else if let attr, let castedAttr = Card.Attribute(rawValue: attr), char == nil {
                    attrResult[eventID] = castedAttr
                    attrPercentResult[eventID] = percentage
                }
            }
            
            for (key, av) in alfa {
                let id = av["id"].intValue
//                guard let bv = bravo.array?.first(where: { $0["id"].int == id }) else { continue }
                
                var eventRankingRewardRange: [EventRankingRewardRange] = []
                for range in av["eventRankingRewardRanges"].arrayValue {
                    var singleRangeRewards: [EventRankingRewardRange.EventRankingReward] = []
                    for reward in range["eventRankingRewards"].arrayValue {
                        singleRangeRewards.append(EventRankingRewardRange.EventRankingReward(resourceBoxId: reward["resourceBoxId"].intValue, rewardConditionType: reward["rewardConditionType"].string))
                    }
                    
                    eventRankingRewardRange.append(EventRankingRewardRange(upperBound: range["fromRank"].intValue, lowerBound: range["toRank"].intValue, includeLowerBound: range["isToRankBorder"].boolValue, eventRankingRewards: singleRangeRewards))
                }
                
                
                result.append(Event(
                    id: id,
                    title: av["name"].string.localizable(),
                    eventType: EventType(rawValue: av["eventType"].stringValue) ?? .marathon,
                    displayingStartDate: av["eventOnlyComponentDisplayStartAt"].date.localizable(),
                    startDate: av["startAt"].date.localizable(),
                    aggregateDate: av["aggregateAt"].date.localizable(),
                    rankingAnnouncementDate: av["rankingAnnounceAt"].date.localizable(),
                    distributionStartDate: av["distributionStartAt"].date.localizable(),
                    displayingEndDate: av["eventOnlyComponentDisplayEndAt"].date.localizable(),
                    closedDate: av["closedAt"].date.localizable(),
                    distributionEndDate: av["distributionEndAt"].date.localizable(),
                    unit: Unit(rawValue: av["unit"].stringValue),
                    attribute: attrResult[id],
                    characters: charResult[id] ?? [],
                    attributeBonus: attrPercentResult[id],
                    characterBonus: charPercentResult[id] ?? 0,
                    virturalLiveID: av["virturalLiveId"].intValue,
                    isCountLeaderCharacterPlay: av["isCountLeaderCharacterPlay"].boolValue,
                    eventRankingRewardRanges: eventRankingRewardRange,
                    assetBundleName: av["assetbundleName"].stringValue,
                    bgmAssetbundleName: av["assetbundleName"].stringValue
//                    outline: bv["outline"].string.localizable()
                ))
            }
            return result
        }
        return await task.value
    }
}

extension Event: GettableByID {
    public init?(id: Int) async {
        let allItems = await SekaiCache.withDirectCache(id: "AllEvents") { await Event.all() }
        guard let item = allItems?.first(where: { $0.id == id }) else {
            return nil
        }
        self = item
    }
}

// https://storage.sekai.best/sekai-jp-assets/home/banner/event_ofprayer_2026/event_ofprayer_2026.webp

extension Event {
    public var bannerImageURL: URL {
        self.bannerImageURL()
    }
    
    public func bannerImageURL(in locale: SekaiLocale = .primaryLocale) -> URL {
        .init(string: "https://storage.sekai.best/\(locale._assetsPath)/home/banner/\(self.assetBundleName)/\(self.assetBundleName).webp")!
    }
    
    public var logoImageURL: URL {
        self.bannerImageURL(in: .primaryLocale)
    }
    
    public func logoImageURL(in locale: SekaiLocale = .primaryLocale) -> URL {
        .init(string: "https://storage.sekai.best/\(locale._assetsPath)/event/\(self.assetBundleName)/logo/logo.webp")!
    }
}


extension Event {
    public var backgroundMusicURL: URL {
        .init(string: "https:storage.sekai.best/sekai-jp-assets/event/\(self.assetBundleName)/bgm/\(self.assetBundleName)_top.mp3")!
    }
}
