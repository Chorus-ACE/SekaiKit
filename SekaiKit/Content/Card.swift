//
//  Card.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/1/16.
//

import Foundation
import SekaiKitMacro

/// A collectible character card in Project Sekai.
@LocalizationsCombinable
public struct Card: Hashable, Identifiable, Sendable, SekaiCachable, LocalizationsCombinable {
    /// The unique identifier of the card.
    public var id: Int
    
    /// The localized name of the card.
    public var name: LocalizableData<String>
    /// The identifier of the character featured on the card.
    public var characterID: Int
    /// The unit associated with the card.
    public var unit: Unit
    /// The unit supported by this card, if specified.
    public var supportUnit: Unit?
    
    /// The rarity of the card.
    public var rarity: Rarity
    /// The attribute of the card.
    public var attribute: Attribute
    
    /// The release date of the card in each available locale.
    public var releaseDate: LocalizableData<Date>
    /// The availability category of the card.
    public var sourceType: SourceType
    /// The localized phrase shown when obtaining the card through a gacha.
    public var gachaPhrase: LocalizableData<String>
    
    /// A Boolean value indicating whether the card is already trained when obtained.
    public var isInitiallySpecialTrained: Bool = false // Rarely `true`
    
    /// The identifier of the card’s skill before special training.
    public var skillID: Int
    /// The localized name of the card’s skill before special training.
    public var skillName: LocalizableData<String>
    /// The identifier of the skill after special training, if a separate skill is provided.
    public var specialTrainingSkillID: Int? // Rarely not nil
    /// The localized name of the skill after special training, when available.
    public var specialTrainingSkillName: LocalizableData<String> // Rarely not nil
    
    /// The card’s power values, keyed by parameter type and then by level.
    public var cardParameters: [ParameterType: [Int: Int]]
    /// The fixed power bonus from special training for each parameter type.
    public var specialTrainingFixedBonus: [ParameterType: Int]
//    public var specialTrainingCosts: [String] // TODO
    /// The identifier of the special training reward resource box, if available.
    public var specialTrainingRewardResourceBoxID: Int?
//    public var masterLessonAchieveResources: [Int: [String]] // TODO
    
    /// A Boolean value indicating whether the card is hidden in the archive.
    public var archiveIsHidden: Bool = false // Rarely `true`
    /// The date the card appears in the archive in each available locale.
    public var archivePublishedDate: LocalizableData<Date>
    
    /// The asset bundle name used to locate the card’s images and audio.
    public var assetbundleName: String
    
    /// The sum of the maximum value of each parameter and the fixed special training bonuses.
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
    
    /// A Boolean value indicating whether the card’s rarity supports special training.
    public var canTrain: Bool {
        return self.rarity.canTrain
    }
    
    /// A component of a card’s total power.
    public enum ParameterType: String, CaseIterable, Codable, Hashable, Sendable, SekaiCachable {
        /// The performance parameter.
        case performance = "param1"
        /// The technique parameter.
        case technique = "param3"
        /// The stamina parameter.
        case stamina = "param2"
    }
    
    /// An attribute used to classify cards and calculate event bonuses.
    public enum Attribute: String, Hashable, CaseIterable, Sendable, SekaiCachable, RawRepresentable {
        /// The Cute attribute.
        case cute
        /// The Mysterious attribute.
        case mysterious
        /// The Cool attribute.
        case cool
        /// The Happy attribute.
        case happy
        /// The Pure attribute.
        case pure
        
        /// The uppercase display name of the attribute.
        public var name: String {
            self.rawValue.uppercased()
        }
        
        /// The URL of the bundled attribute icon.
        public var iconImageURL: URL {
            Bundle.module.url(forResource: "icon_attribute_\(self.rawValue)", withExtension: "png")!
        }
    }
    
    /// The rarity tier of a card.
    public enum Rarity: String, CaseIterable, Codable, Hashable, Sendable, SekaiCachable {
        /// A one-star card.
        case one = "rarity_1"
        /// A two-star card.
        case two = "rarity_2"
        /// A three-star card.
        case three = "rarity_3"
        /// A four-star card.
        case four = "rarity_4"
        /// A birthday or anniversary card.
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
        
        /// The display name localized for the app’s current language.
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
        
        /// The number of stars, or `nil` for birthday and anniversary cards.
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
    
    /// The category that describes how a card is made available.
    public enum SourceType: Int, CaseIterable, Codable, Hashable, Sendable, SekaiCachable {
        /// A regularly available card.
        case normal = 1
        /// A birthday or anniversary card.
        case birthday
        /// A card available for a limited period.
        case termLimited 
        /// A Colorful Festival limited card.
        case colorfulFestivalLimited
        /// A Bloom Festival limited card.
        case bloomFestivalLimited
        /// A unit event limited card.
        case unitEventLimited
        /// A collaboration limited card.
        case collaborationLimited // 7
        
        /// The display name localized for the app’s current language.
        public var localizedName: String {
            NSLocalizedString("Card.source-type.\(self.rawValue)", bundle: #bundle, comment: "")
        }
    }
}

extension Card: ListGettable, GettableByID {
    /// Loads the records available in a locale.
    ///
    /// - Parameter locale: The locale whose records are requested.
    /// - Returns: The records for the locale, or `nil` if the required data cannot be loaded.
    public static func allInLocale(_ locale: SekaiLocale = .primaryLocale) async -> [Card]? {
        guard let list = await requestProtobuf("card.aar", as: _CardList.self) else { return nil }
        return list.items(in: locale).map { Card(protobuf: $0) }
    }
}

extension Card {
    /// The URL of the card’s original artwork in the Japanese asset collection.
    @inlinable
    public var beforeTrainingArtURL: URL { // No localizations available
        .init(string: "https://storage.sekai.best/sekai-jp-assets/character/member/\(self.assetbundleName)/card_normal.webp")!
    }

    /// The URL of the trained artwork, or `nil` if the card cannot be trained.
    public var afterTrainingArtURL: URL? {
        guard self.rarity.canTrain else { return nil }
        return .init(string: "https://storage.sekai.best/sekai-jp-assets/character/member/\(self.assetbundleName)/card_after_training.webp")!
    }
    
    /// The URL of the card’s original thumbnail in the Japanese asset collection.
    @inlinable
    public var beforeTrainingThumbnailURL: URL {
        .init(string: "https://storage.sekai.best/sekai-jp-assets/thumbnail/chara/\(self.assetbundleName)_normal.webp")!
    }
    
    /// The URL of the trained thumbnail, or `nil` if the card cannot be trained.
    public var afterTrainingThumbnailURL: URL? {
        guard self.rarity.canTrain else { return nil }
        return .init(string: "https://storage.sekai.best/sekai-jp-assets/thumbnail/chara/\(self.assetbundleName)_after_training.webp")!
    }
}

extension Card {
    /// The URL of the Japanese voice clip played when obtaining the card.
    public var gachaPhraseVoiceURL: URL {
        .init(string: "https://storage.sekai.best/sekai-jp-assets/sound/gacha/get_voice/\(self.assetbundleName)/\(self.assetbundleName).mp3")!
    }
}
