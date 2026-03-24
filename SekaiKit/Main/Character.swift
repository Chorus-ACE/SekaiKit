//
//  Character.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/2/1.
//

import Foundation
import SekaiKitMacro
import SwiftUI
internal import SwiftyJSON

@LocalizationsCombinable
public struct Character: Codable, Hashable, Identifiable, Sendable, SekaiCachable, LocalizationsCombinable {
    public var id: Int
    /// Sequence value always equals to `id`.
    public var _sequence: Int
    public var resourceID: Int
    
    public var familyName: LocalizableData<String>
    public var givenName: LocalizableData<String>
    public var familyNameRuby: LocalizableData<String>
    public var givenNameRuby: LocalizableData<String>
    public var familyNameEnglish: String?
    public var givenNameEnglish: String
    
    public var gender: Gender
    public var height: Measurement<UnitLength>
    public var characterVoice: LocalizableData<String>
    public var birthday: DateComponents?
    public var literalBirthday: LocalizableData<String>
    public var school: LocalizableData<String>
    public var schoolClass: LocalizableData<String>
    
    public var hobby: LocalizableData<String>
    public var specialSkill: LocalizableData<String>
    public var favoriteFood: LocalizableData<String>
    public var dislikedFood: LocalizableData<String>
    public var weakness: LocalizableData<String>
    public var introduction: LocalizableData<String>
    public var introductionStoryID: String
    
    public var live2DHeightAdjustment: Float
    public var figure: Figure
    public var breastSize: BreastSize
    public var unit: Unit
    public var supportUnitType: SupportUnitType
    
    public var colorInfo: [CharacterColors]
    
    public struct CharacterColors: Codable, Hashable, Identifiable, Sendable, SekaiCachable {
        public var id: Int
        public var unit: Unit
        public var mainColor: Color
        public var skinColor: Color
        public var skinShadowColor1: Color
        public var skinShadowColor2: Color
    }
    
    public enum Gender: String, CaseIterable, Codable, Hashable, Sendable, SekaiCachable {
        case male
        case female
        case secret // Mizuki only
        
        public var localizedName: String {
            NSLocalizedString("Character.gender.\(self.rawValue)", bundle: #bundle, comment: "")
        }
    }
    
    public enum Figure: String, CaseIterable, Codable, Hashable, Sendable, SekaiCachable {
        case lady = "ladies"
        case men = "mens"
        case boy = "boys"
    }
    
    public enum BreastSize: String, CaseIterable, Codable, Hashable, Sendable, SekaiCachable {
        case none
        case extraSmall = "ss" // Mizuki only
        case small = "s"
        case medium = "m"
        case large = "l"
    }
    
    public enum SupportUnitType: String, CaseIterable, Codable, Hashable, Sendable, SekaiCachable {
        case none
        case full
        case unit
    }
    
    public var fullName: LocalizableData<String> {
        var components = PersonNameComponents()
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default        
        
        switch givenName {
        case .localized(let localizedData):
            var result: LocalizedData<String> = .init()
            
            for locale in localizedData.allAvailableLocales {
                components.familyName = self.familyName.localizedData?[locale] ?? self.familyName.majorValue
                components.givenName = self.givenName.localizedData?[locale] ?? self.familyName.majorValue
                
                result.updateValue(formatter.string(from: components), forLocale: locale)
            }
            
            return .localized(result)
        case .unlocalized(let t):
            components.familyName = self.familyName.majorValue
            components.givenName = self.givenName.majorValue
            
            return .unlocalized(formatter.string(from: components))
        }
    }
    
    public var fullNameRuby: LocalizableData<String> {
        var components = PersonNameComponents()
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default
        
        switch givenNameRuby {
        case .localized(let localizedData):
            var result: LocalizedData<String> = .init()
            
            for locale in localizedData.allAvailableLocales {
                components.familyName = self.familyNameRuby.localizedData?[locale] ?? self.familyName.majorValue
                components.givenName = self.givenNameRuby.localizedData?[locale] ?? self.familyName.majorValue
                
                result.updateValue(formatter.string(from: components), forLocale: locale)
            }
            
            return .localized(result)
        case .unlocalized(let t):
            components.familyName = self.familyNameRuby.majorValue
            components.givenName = self.givenNameRuby.majorValue
            
            return .unlocalized(formatter.string(from: components))
        }
    }
    
    public var color: Color? {
        return self.colorInfo.first(where: { $0.unit == self.unit })?.mainColor
    }
}

extension Character: ListGettable {
    public static func allForLocale(_ locale: SekaiLocale) async -> [Character]? {
        let groupResult = await withTasksResult {
            await requestJSON("https://sekai-world.github.io/\(locale._databasePath)/characterProfiles.json")
        } _: {
            await requestJSON("https://sekai-world.github.io/\(locale._databasePath)/gameCharacters.json")
        } _: {
            await requestJSON("https://sekai-world.github.io/\(locale._databasePath)/gameCharacterUnits.json")
        }
        
        guard let alfa = groupResult.0 else { return nil }
        guard let bravo = groupResult.1 else { return nil }
        let charlie = groupResult.2
        
        let task = Task.detached(priority: .userInitiated) {
            var result: [Character] = []
            
            for (key, av) in alfa {
                guard let bv = bravo.arrayValue[access: Int(key)!] else { continue }
                
                let colors = charlie?.arrayValue.filter({ $0["gameCharacterId"].intValue == Int(key)!+1 }) ?? []
                var colorInfo: [CharacterColors] = []
                if !colors.isEmpty {
                    for cv in colors {
                        colorInfo.append(CharacterColors(
                            id: cv["id"].intValue,
                            unit: Unit(rawValue: cv["unit"].stringValue) ?? .virturalSinger,
                            mainColor: Color(hex: cv["colorCode"].stringValue) ?? .white,
                            skinColor: Color(hex: cv["skinColorCode"].stringValue) ?? .white,
                            skinShadowColor1: Color(hex: cv["skinShadowColorCode1"].stringValue) ?? .white,
                            skinShadowColor2: Color(hex: cv["skinShadowColorCode2"].stringValue) ?? .white
                        ))
                    }
                }
                
                result.append(Character(
                    id: av["characterId"].intValue,
                    _sequence: bv["seq"].intValue,
                    resourceID: bv["resourceId"].intValue,
                    familyName: bv["firstName"].string.localizable(),
                    givenName: bv["givenName"].string.localizable(),
                    familyNameRuby: bv["firstNameRuby"].string.localizable(),
                    givenNameRuby: bv["givenNameRuby"].string.localizable(),
                    familyNameEnglish: bv["firstNameEnglish"].string,
                    givenNameEnglish: bv["givenNameEnglish"].stringValue,
                    gender: Gender(rawValue: bv["gender"].stringValue) ?? .female,
                    height: Measurement(value: bv["height"].doubleValue, unit: .centimeters),
                    characterVoice: av["characterVoice"].string.localizable(),
                    birthday: parseToDateComponents(av["birthday"].stringValue),
                    literalBirthday: av["birthday"].string.localizable(),
                    school: av["school"].string.localizable(),
                    schoolClass: av["schoolYear"].string.localizable(),
                    hobby: av["hobby"].string.localizable(),
                    specialSkill: av["specialSkill"].string.localizable(),
                    favoriteFood: av["favoriteFood"].string.localizable(),
                    dislikedFood: av["hatedFood"].string.localizable(),
                    weakness: av["weak"].string.localizable(),
                    introduction: av["introduction"].string.localizable(),
                    introductionStoryID: av["scenarioId"].stringValue,
                    live2DHeightAdjustment: bv["live2dHeightAdjustment"].floatValue,
                    figure: Figure(rawValue: bv["figure"].stringValue) ?? .lady,
                    breastSize: BreastSize(rawValue: bv["breastSize"].stringValue) ?? .none,
                    unit: Unit(rawValue: bv["unit"].stringValue) ?? .virturalSinger,
                    supportUnitType: SupportUnitType(rawValue: bv["supportUnitType"].stringValue) ?? .none,
                    colorInfo: colorInfo
                ))
                
            }
            return result
        }
        return await task.value
    }
}

extension Character: GettableByID {
    public init?(id: Int) async {
        let _allCharacters = await SekaiCache.withDirectCache(id: "AllCharacters") { await Character.all() }
        guard let allCharacters = _allCharacters, let item = allCharacters.first(where: { $0.id == id }) else {
            return nil
        }
        self = item
    }
}

internal func parseToDateComponents(_ input: String) -> DateComponents? {
    let calendar = Calendar.current
    
    let formatters: [DateFormatter] = {
        let jazh = DateFormatter() // Also ZH
        jazh.locale = Locale(identifier: "ja")
        jazh.dateFormat = "M月d日"
        
        let en = DateFormatter()
        en.locale = Locale(identifier: "en")
        en.dateFormat = "MMM.d"
        
        let ko = DateFormatter()
        ko.locale = Locale(identifier: "ko")
        ko.dateFormat = "M월 d일"
        
        return [jazh, en, ko]
    }()
    
    for formatter in formatters {
        if let date = formatter.date(from: input) {
            return calendar.dateComponents([.month, .day], from: date)
        }
    }
    
    return nil
}

extension Character {
    @inlinable
    public var selectionImageURL: URL {
        .init(string: "https://storage.sekai.best/\(SekaiLocale.primaryLocale._assetsPath)/character/character_select/chr_tl_\(self.id).webp")!
    }
    @inlinable
    public func selectionImageURL(in locale: SekaiLocale = .primaryLocale) -> URL {
        .init(string: "https://storage.sekai.best/\(locale._assetsPath)/character/character_select/chr_tl_\(self.id).webp")!
    }
    @inlinable
    public static func selectionImageURL(forID id: Int, in locale: SekaiLocale = .primaryLocale) -> URL {
        .init(string: "https://storage.sekai.best/\(locale._assetsPath)/character/character_select/chr_tl_\(id).webp")!
    }
}

extension Character: TitleDescribable {
    public var title: String { fullName.majorValue ?? "" }
}



