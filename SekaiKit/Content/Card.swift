//
//  Card.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/1/16.
//

import Foundation
import SekaiKitMacro

@LocalizationsCombinable
public struct Card: Hashable, Identifiable, Sendable, SekaiCachable, LocalizationsCombinable {
    public var id: Int
    /// This value always equals to ten times `id`.
    public var _sequence: Int
    
    public var name: LocalizableData<String>
    public var characterID: Int
    public var unit: Unit
    public var supportUnit: Unit?
    
    public var rarity: Rarity
    public var attribute: Attribute
    
    public var releaseDate: LocalizableData<Date>
    public var sourceType: SourceType
    public var gachaPhrase: LocalizableData<String>
    
    public var isInitiallySpecialTrained: Bool = false // Rarely `true`
    
    public var skillID: Int
    public var skillName: LocalizableData<String>
    public var specialTrainingSkillID: Int? // Rarely not nil
    public var specialTrainingSkillName: LocalizableData<String> // Rarely not nil
    
    public var cardParameters: [ParameterType: [Int: Int]]
    public var specialTrainingFixedBonus: [ParameterType: Int]
//    public var specialTrainingCosts: [String] // TODO
    public var specialTrainingRewardResourceBoxID: Int?
//    public var masterLessonAchieveResources: [Int: [String]] // TODO
    
    public var archiveIsHidden: Bool = false // Rarely `true`
    public var archivePublishedDate: LocalizableData<Date>
    
    public var assetbundleName: String
    
    public var maxPower: Int {
        var maxPower = 0
        for (_, value) in cardParameters {
            maxPower += value.map(\.value).max() ?? 0
        }
        for (_, value) in specialTrainingFixedBonus {
            maxPower += value
        }
        return maxPower
    }
    
    public var canTrain: Bool {
        return self.rarity.canTrain
    }
    
    public enum ParameterType: String, CaseIterable, Codable, Hashable, Sendable, SekaiCachable {
        case performance = "param1"
        case technique = "param3"
        case stamina = "param2"
    }
    
    public enum Attribute: String, Hashable, CaseIterable, Sendable, SekaiCachable, RawRepresentable {
        case cute
        case mysterious
        case cool
        case happy
        case pure
        
        public var name: String {
            self.rawValue.uppercased()
        }
        
        public var iconImageURL: URL {
            Bundle.module.url(forResource: "icon_attribute_\(self.rawValue)", withExtension: "png")!
        }
    }
    
    public enum Rarity: String, CaseIterable, Codable, Hashable, Sendable, SekaiCachable {
        case one = "rarity_1"
        case two = "rarity_2"
        case three = "rarity_3"
        case four = "rarity_4"
        case birthday = "rarity_birthday"
        
        var normalMaxLevel: Int {
            switch self {
            case .one:
                return 20
            case .two:
                return 30
            case .three:
                return 40
            case .four:
                return 50
            case .birthday:
                return 60
            }
        }
        
        var canTrain: Bool {
            return [Self.three, .four].contains(self)
        }
        
        var trainedMaxLevel: Int? {
            switch self {
            case .three:
                return 50
            case .four:
                return 60
            default:
                return nil
            }
        }
        
        public var localizedName: String {
            switch self {
            case .one:
                return "1★"
            case .two:
                return "2★"
            case .three:
                return "3★"
            case .four:
                return "4★"
            case .birthday:
                return NSLocalizedString("Card.rarity.birthday", bundle: #bundle, comment: "")
            }
        }
        
        public var integer: Int? {
            switch self {
            case .one: 1
            case .two: 2
            case .three: 3
            case .four: 4
            case .birthday: nil
            }
        }
    }
    
    public enum SourceType: Int, CaseIterable, Codable, Hashable, Sendable, SekaiCachable {
        case normal = 1
        case birthday
        case termLimited 
        case colorfulFestivalLimited
        case bloomFestivalLimited
        case unitEventLimited
        case collaborationLimited // 7
        
        public var localizedName: String {
            NSLocalizedString("Card.source-type.\(self.rawValue)", bundle: #bundle, comment: "")
        }
    }
}

extension Card: ListGettable {
    public static func allInLocale(_ locale: SekaiLocale = .primaryLocale) async -> [Card]? {
        let json = await requestJSON("https://sekai-world.github.io/\(locale._databasePath)/cards.json")
        
        if let json {
            let task = Task.detached(priority: .userInitiated) {
                var result: [Card] = []
                for (key, value) in json {
                    var cardParams: [ParameterType: [Int: Int]] = [:]
                    for (k, v) in value["cardParameters"] {
                        if let paramType = ParameterType(rawValue: v["cardParameterType"].stringValue) {
                            cardParams[modifying: paramType][accessing: v["cardLevel"].intValue] = v["power"].intValue
                        }
                    }
                    result.append(.init(
                        id: value["id"].intValue,
                        _sequence: value["seq"].intValue,
                        name: value["prefix"].string.localizable(),
                        characterID: value["characterId"].intValue,
                        unit: Unit(member: value["characterId"].intValue) ?? .virturalSinger,
                        supportUnit: Unit(rawValue: value["supportUnit"].stringValue),
                        rarity: Rarity(rawValue: value["cardRarityType"].stringValue) ?? .one,
                        attribute: Card.Attribute(rawValue: value["attr"].stringValue) ?? .cute,
                        releaseDate: value["releaseAt"].date.localizable(),
                        sourceType: SourceType(rawValue: value["cardSupplyId"].intValue) ?? .normal,
                        gachaPhrase: value["gachaPhrase"].stringValue.nilIfEqual(to: "-").localizable(),
                        isInitiallySpecialTrained: value["initialSpecialTrainingStatus"].stringValue == "done",
                        skillID: value["skillId"].intValue,
                        skillName: value["cardSkillName"].string.localizable(),
                        specialTrainingSkillID: value["specialTrainingSkillId"].int,
                        specialTrainingSkillName: value["specialTrainingSkillName"].string.localizable(),
                        cardParameters: cardParams,
                        specialTrainingFixedBonus: [.performance: value["specialTrainingPower1BonusFixed"].intValue, .technique: value["specialTrainingPower3BonusFixed"].intValue, .stamina: value["specialTrainingPower2BonusFixed"].intValue],
//                        specialTrainingCosts: [], // TODO
                        specialTrainingRewardResourceBoxID: value["specialTrainingRewardResourceBoxId"].int,
//                        masterLessonAchieveResources: [:], // TODO
                        archiveIsHidden: value["archiveDisplayType"].string == "hide",
                        archivePublishedDate: .unlocalized(Date(timeIntervalSince1970: TimeInterval(value["archivePublishedAt"].intValue/1000))),
                        assetbundleName: value["assetbundleName"].stringValue
                    ))
                }
                return result
            }
            return await task.value
        } else {
            return nil
        }
    }
}

extension Card: GettableByID {
    public init?(id: Int) async {
        let allItems = await SekaiCache.withDirectCache(id: "AllCards") { await Card.all() }
        guard let item = allItems?.first(where: { $0.id == id }) else {
            return nil
        }
        self = item
    }
}

extension Card {
    @inlinable
    public var beforeTrainingArtURL: URL { // No localizations available
        .init(string: "https://storage.sekai.best/sekai-jp-assets/character/member/\(self.assetbundleName)/card_normal.webp")!
    }

    public var afterTrainingArtURL: URL? {
        guard self.rarity.canTrain else { return nil }
        return .init(string: "https://storage.sekai.best/sekai-jp-assets/character/member/\(self.assetbundleName)/card_after_training.webp")!
    }
    
    @inlinable
    public var beforeTrainingThumbnailURL: URL {
        .init(string: "https://storage.sekai.best/sekai-jp-assets/thumbnail/chara/\(self.assetbundleName)_normal.webp")!
    }
    
    public var afterTrainingThumbnailURL: URL? {
        guard self.rarity.canTrain else { return nil }
        return .init(string: "https://storage.sekai.best/sekai-jp-assets/thumbnail/chara/\(self.assetbundleName)_after_training.webp")!
    }
}
