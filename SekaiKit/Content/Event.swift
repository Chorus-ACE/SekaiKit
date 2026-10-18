//
//  Event.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/1/16.
//


import Foundation
import SekaiKitMacro

/// An event in Project Sekai, including its schedule and bonus conditions.
@LocalizationsCombinable
public struct Event: Codable, Hashable, Identifiable, Sendable, SekaiCachable, LocalizationsCombinable {
    /// The unique identifier of the event.
    public var id: Int
    /// The localized title of the event.
    public var title: LocalizableData<String>
    /// The localized story introduction (`eventStories.outline`), absent in older archives.
    public var outline: LocalizableData<String>
    /// The gameplay format of the event.
    public var eventType: Event.EventType
    
    /// The date event components begin appearing in each locale (`eventOnlyComponentDisplayStartAt`).
    public var displayingStartDate: LocalizableData<Date>
    /// The date event gameplay begins in each locale (`startAt`).
    public var startDate: LocalizableData<Date>
    /// The date event result aggregation begins in each locale (`aggregateAt`).
    public var aggregateDate: LocalizableData<Date>
    /// The date event rankings are announced in each locale (`rankingAnnounceAt`).
    public var rankingAnnouncementDate: LocalizableData<Date>
    /// The date reward distribution begins in each locale (`distributionStartAt`).
    public var distributionStartDate: LocalizableData<Date>
    /// The date event components stop appearing in each locale (`eventOnlyComponentDisplayEndAt`).
    public var displayingEndDate: LocalizableData<Date>
    /// The date the event closes in each locale (`closedAt`).
    public var endDate: LocalizableData<Date>
    /// The date reward distribution ends in each locale (`distributionEndAt`).
    public var distributionEndDate: LocalizableData<Date>
    
    /// The featured unit, if the event has one.
    public var unit: Unit?
    /// The banner character's base ID for a unit-focus event; nil for mixed events and World Link.
    public var focusCharacterID: Int?
    /// The character's one-based unit-focus event count in Japanese release order.
    public var focusCharacterIndex: Int?
    /// The attribute that receives an event bonus, if specified.
    public var attribute: Card.Attribute?
    /// The identifiers of characters that receive an event bonus.
    public var characters: [Int]
    
    /// The bonus value for matching the event attribute, if provided.
    public var attributeBonus: Int?
    /// The bonus value for matching an event character.
    public var characterBonus: Int
    
    /// The identifier of the associated virtual live.
    public var virtualLiveID: Int
    
    /// A Boolean value indicating whether plays with the leader character are counted.
    public var isCountLeaderCharacterPlay: Bool // Rarely `true`
    /// The rank ranges and their corresponding rewards.
    public var eventRankingRewardRanges: [EventRankingRewardRange]
    
    /// The asset bundle name for the event’s visual resources.
    public var assetBundleName: String
    /// The background music asset bundle name recorded for the event.
    public var bgmAssetbundleName: String
    
    /// The gameplay format of an event.
    public enum EventType: String, CaseIterable, Codable, Hashable, SekaiCachable, Sendable {
        /// A marathon event.
        case marathon
        /// A Cheerful Carnival event.
        case cheerfulCarnival = "cheerful_carnival"
        /// A World Link event.
        case worldLink = "world_bloom"
        
        /// The event format name localized for the app’s current language.
        public var localizedName: String {
            NSLocalizedString("Event.type.\(self.rawValue)", bundle: #bundle, comment: "")
        }
    }
    
    /// A rank interval and the rewards assigned to it.
    public struct EventRankingRewardRange: Codable, Hashable, Sendable, SekaiCachable {
//        var id: Int
        /// The upper rank boundary recorded in the event data.
        public var upperBound: Int
        /// The lower rank boundary recorded in the event data.
        public var lowerBound: Int
        /// A Boolean value indicating whether the lower rank boundary is included.
        public var includeLowerBound: Bool // `true` -> Range, `false` -> ClosedRange
        /// The rewards available within this rank interval.
        public var eventRankingRewards: [EventRankingReward]
        
        /// A resource box granted for an event ranking result.
        public struct EventRankingReward: Codable, Hashable, Sendable, SekaiCachable {
//            var id: Int
//            var eventRankingRewardRangeId: Int
            /// The identifier of the reward’s resource box.
            public var resourceBoxId: Int
            /// The reward condition type, if a condition is specified.
            public var rewardConditionType: String?
        }
    }
    
    
    /// The focus character’s localized given name and unit-focus event count, formatted for the primary locale.
    public var focusCharacterLabel: String? {
        self.focusCharacterLabel()
    }
    
    
    /// Returns the focus character’s localized given name and unit-focus event count.
    ///
    /// - Parameter locale: The locale whose spacing convention is used. The default is the primary locale.
    /// - Returns: The formatted label, or `nil` if the focus character, event count, or character name is unavailable.
    public func focusCharacterLabel(in locale: SekaiLocale = .primaryLocale) -> String? {
        if let id = self.focusCharacterID,
           let index = self.focusCharacterIndex,
           let name = SekaiCache.preCache.character(id: id)?.givenName.forLocale(locale) {
            return "\(name)\(locale == .en ? " " : "")\(index)"
        }
        return nil
    }
}

extension Event: ListGettable, GettableByID {
    /// Loads the records available in a locale.
    ///
    /// - Parameter locale: The locale whose records are requested.
    /// - Returns: The records for the locale, or `nil` if the required data cannot be loaded.
    public static func allInLocale(_ locale: SekaiLocale = .primaryLocale) async -> [Event]? {
        guard let list = await requestProtobuf("event.aar", as: _EventList.self) else { return nil }
        return list.items(in: locale).map { Event(protobuf: $0) }
    }
}

// https://storage.sekai.best/sekai-jp-assets/home/banner/event_ofprayer_2026/event_ofprayer_2026.webp

extension Event {
    /// The event story banner URL using the title’s locale, with the primary locale as a fallback.
    public var bannerImageURL: URL {
        self.bannerImageURL()
    }
    
    /// Returns the event story banner URL for a locale.
    ///
    /// - Parameter locale: The asset locale, or `nil` to use the title’s locale and then the primary locale.
    /// - Returns: The URL of the event story banner.
    public func bannerImageURL(in locale: SekaiLocale? = nil) -> URL {
        .init(string:
                "https://storage.sekai.best/\((locale ?? self.title.majorLocale ?? .primaryLocale )._assetsPath)/event_story/\(self.assetBundleName)/screen_image/banner_event_story.webp")!
    }
    
    /// The home screen banner URL using the title’s locale, with the primary locale as a fallback.
    public var bannerImageAltURL: URL {
        self.bannerImageAltURL()
    }
    
    /// Returns the home screen banner URL for a locale.
    ///
    /// - Parameter locale: The asset locale, or `nil` to use the title’s locale and then the primary locale.
    /// - Returns: The URL of the home screen banner.
    public func bannerImageAltURL(in locale: SekaiLocale? = nil) -> URL {
        .init(string:
                "https://storage.sekai.best/\((locale ?? self.title.majorLocale ?? .primaryLocale )._assetsPath)/home/banner/\(self.assetBundleName)/\(self.assetBundleName).webp")!
    }
    
    // event_runaway_2023
    // https://storage.sekai.best/sekai-tc-asset/home/banner/event_runaway_2023/event_runaway_2023.webp"
    
    /// The event logo URL in the preferred available locale.
    public var logoImageURL: URL {
        self.logoImageURL(in: nil)
    }
    
    /// Returns the event logo URL for a locale.
    ///
    /// - Parameter locale: The asset locale, or `nil` to use the title’s locale and then the primary locale.
    /// - Returns: The URL of the event logo.
    public func logoImageURL(in locale: SekaiLocale? = nil) -> URL {
        .init(string: "https://storage.sekai.best/\((locale ?? self.title.majorLocale ?? .primaryLocale )._assetsPath)/event/\(self.assetBundleName)/logo/logo.webp")!
    }
}


extension Event {
    /// The background music URL constructed from the event’s asset bundle name.
    public var backgroundMusicURL: URL {
        .init(string: "https://storage.sekai.best/sekai-jp-assets/event/\(self.assetBundleName)/bgm/\(self.assetBundleName)_top.mp3")!
    }
}
