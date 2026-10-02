//
//  Character.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/2/1.
//

import Foundation
import SekaiKitMacro
import SwiftUI

/// A character appearing in Project Sekai.
@LocalizationsCombinable
public struct Character: Codable, Hashable, Identifiable, Sendable, SekaiCachable, LocalizationsCombinable {
    /// The unique identifier of this record.
    public var id: Int
    /// The identifier used to locate the character’s resources.
    public var resourceID: Int
    
    /// The localized family name of the character.
    public var familyName: LocalizableData<String>
    /// The localized given name of the character.
    public var givenName: LocalizableData<String>
    /// The pronunciation of the character's family name.
    public var familyNameRuby: LocalizableData<String>
    /// The pronunciation of the character's given name.
    public var givenNameRuby: LocalizableData<String>
    /// The English family name for the character.
    public var familyNameEnglish: String?
    /// The English given name for the character.
    public var givenNameEnglish: String
    
    /// The gender recorded for the character, including an undisclosed value.
    public var gender: Gender
    /// The height of the character.
    public var height: Measurement<UnitLength>
    /// The localized voice actor credit, when provided for the character.
    public var characterVoice: LocalizableData<String>
    /// The Gregorian birth month and day parsed from ``literalBirthday``, or `nil` if parsing fails.
    public var birthday: DateComponents?
    /// The localized birthday text to display when ``birthday`` is unavailable.
    public var literalBirthday: LocalizableData<String>
    /// The school the character is in.
    public var school: LocalizableData<String>
    /// The class the character is in at school.
    public var schoolClass: LocalizableData<String>
    
    /// The character's hobby.
    public var hobby: LocalizableData<String>
    /// The special skill of the character.
    public var specialSkill: LocalizableData<String>
    /// The character's favorite food.
    public var favoriteFood: LocalizableData<String>
    /// The character's disliked food.
    public var dislikedFood: LocalizableData<String>
    /// Something that the character is bad at.
    public var weakness: LocalizableData<String>
    /// A localized introduction to the character.
    public var introduction: LocalizableData<String>
    /// The ID of the introduction story for the character.
    public var introductionStoryID: String
    
    /// The height adjustment value for the character's Live2D models.
    public var live2DHeightAdjustment: Float
    /// The figure type of the character, likely for Live2D model rendering.
    public var figure: Figure
    /// The breast size of the character, likely for Live2D model rendering.
    public var breastSize: BreastSize
    
    /// The unit associated with this character or color record.
    public var unit: Unit
    /// The support unit type of the character.
    public var supportUnitType: SupportUnitType
    
    /// The character’s color palettes for the available units.
    public var colorInfo: [CharacterColors]
    
    /// Color information related to a character.
    public struct CharacterColors: Codable, Hashable, Identifiable, Sendable, SekaiCachable {
        /// The unique identifier of this record.
        public var id: Int
        /// The unit associated with this character or color record.
        public var unit: Unit
        /// The character’s representative color for this unit.
        public var mainColor: Color
        /// The base skin color in this palette.
        public var skinColor: Color
        /// The first skin shadow color in this palette.
        public var skinShadowColor1: Color
        /// The second skin shadow color in this palette.
        public var skinShadowColor2: Color
    }
    
    /// Gender of a character.
    public enum Gender: String, CaseIterable, Codable, Hashable, Sendable, SekaiCachable {
        /// A male character.
        case male
        /// A female character.
        case female
        /// A character whose gender is undisclosed.
        case secret
        
        /// The gender label localized for the app’s current language.
        public var localizedName: String {
            NSLocalizedString("Character.gender.\(self.rawValue)", bundle: #bundle, comment: "")
        }
    }
    
    /// The figure classification stored in the character’s model metadata.
    public enum Figure: String, CaseIterable, Codable, Hashable, Sendable, SekaiCachable {
        /// The ladies figure classification.
        case lady = "ladies"
        /// The mens figure classification.
        case men = "mens"
        /// The boys figure classification.
        case boy = "boys"
    }
    
    /// The size classification stored in the character’s model metadata.
    public enum BreastSize: String, CaseIterable, Codable, Hashable, Sendable, SekaiCachable {
        /// No size or support classification is specified.
        case none
        /// The extra-small size classification.
        case extraSmall = "ss" // Mizuki only
        /// The small size classification.
        case small = "s"
        /// The medium size classification.
        case medium = "m"
        /// The large size classification.
        case large = "l"
    }
    
    /// The scope of unit support recorded for the character.
    public enum SupportUnitType: String, CaseIterable, Codable, Hashable, Sendable, SekaiCachable {
        /// No size or support classification is specified.
        case none
        /// Support across all units.
        case full
        /// Support for a specific unit.
        case unit
    }
    
    /// The full name of a character.
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
    
    /// The pronunciation of the character's full name.
    public var fullNameRuby: LocalizableData<String> {
        switch givenNameRuby {
        case .localized(let localizedData):
            var result: LocalizedData<String> = .init()
            
            for locale in localizedData.allAvailableLocales {
                result.updateValue(combineNames(self.familyNameRuby.localizedData?[locale] ?? self.familyName.majorValue ?? "", self.givenNameRuby.localizedData?[locale] ?? self.familyName.majorValue ?? ""), forLocale: locale)
            }
            
            return .localized(result)
        case .unlocalized(let t):
            return .unlocalized(combineNames(self.familyNameRuby.majorValue ?? "", self.givenNameRuby.majorValue ?? ""))
        }
        
        // Don't use formatter since all family names are expected at first.
        func combineNames(_ familyName: String, _ givenName: String) -> String {
            if familyName.allSatisfy({ $0.isASCII }) {
                return "\(familyName) \(givenName)"
            } else {
                return "\(familyName)\(givenName)"
            }
        }
    }
    
    /// The representative color of the character.
    public var color: Color? {
        return self.colorInfo.first(where: { $0.unit == self.unit })?.mainColor
    }
}

extension Character: ListGettable, GettableByID {
    /// Loads the records available in a locale.
    ///
    /// - Parameter locale: The locale whose records are requested.
    /// - Returns: The records for the locale, or `nil` if the required data cannot be loaded.
    public static func allInLocale(_ locale: SekaiLocale) async -> [Character]? {
        guard let list = await requestProtobuf("character.aar", as: _CharacterList.self) else { return nil }
        return list.items(in: locale).map { Character(protobuf: $0) }
    }
}

extension Character {
    /// Returns characters whose birthdays fall on or immediately around a date.
    ///
    /// If any characters have a birthday on the given day, only those characters
    /// are returned. Otherwise, characters with the next birthday come first,
    /// followed by characters with the previous birthday. The search wraps across
    /// the end of the year and includes everyone sharing either birthday.
    /// Characters within each birthday group are ordered by ID.
    ///
    /// Only Gregorian month and day components are compared. Missing or invalid
    /// birthdays are ignored; February 29 remains a valid birthday in every year.
    /// A character is returned only once when there is a single birthday group.
    /// The character list is loaded using ``ListGettable/allWithCache(trait:)``.
    ///
    /// - Parameters:
    ///   - date: The date to compare with birthdays. The default is the current date.
    ///   - timeZone: The time zone used to determine the date's month and day.
    ///     The default is Japan Standard Time.
    /// - Returns: The matching characters, an empty array if no valid birthdays
    ///   are available, or `nil` if the character list cannot be loaded.
    public static func recentBirthdayCharacters(
        aroundDate date: Date = .now,
        timeZone: TimeZone = TimeZone(identifier: "Asia/Tokyo")!
    ) async -> [Character]? {
        guard let characters = await allWithCache() else { return nil }
        return recentBirthdayCharacters(in: characters, aroundDate: date, timeZone: timeZone)
    }

    /// Selects birthday groups from an already loaded character list.
    internal static func recentBirthdayCharacters(
        in characters: [Character],
        aroundDate date: Date,
        timeZone: TimeZone
    ) -> [Character] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.component(.month, from: date) * 100
            + calendar.component(.day, from: date)

        // A leap-year month table validates recurring birthdays without shifting
        // February 29 or normalizing invalid dates into a different month.
        let daysPerMonth = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        var groups: [Int: [Character]] = [:]
        for character in characters {
            guard let month = character.birthday?.month,
                  let day = character.birthday?.day,
                  (1...12).contains(month),
                  (1...daysPerMonth[month - 1]).contains(day) else { continue }
            groups[month * 100 + day, default: []].append(character)
        }

        if let birthdaysToday = groups[today] {
            return birthdaysToday.sorted { $0.id < $1.id }
        }
        let birthdays = groups.keys.sorted()
        guard let first = birthdays.first, let last = birthdays.last else { return [] }
        let next = birthdays.first { $0 > today } ?? first
        let previous = birthdays.last { $0 < today } ?? last
        let selectedDays = next == previous ? [next] : [next, previous]
        return selectedDays.flatMap { day in
            groups[day, default: []].sorted { $0.id < $1.id }
        }
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
    /// The URL of the character selection image for the primary locale.
    public var selectionImageURL: URL {
        Self.selectionImageURL(forID: self.id)
    }
    
    /// Returns the character selection image URL for a locale.
    ///
    /// - Parameter locale: The asset locale. The default is the primary locale.
    /// - Returns: The URL of the character selection image.
    public func selectionImageURL(in locale: SekaiLocale = .primaryLocale) -> URL {
        Self.selectionImageURL(forID: self.id, in: locale)
    }
    
    /// Returns a character selection image URL for an identifier and locale.
    ///
    /// - Parameters:
    ///   - id: The character identifier.
    ///   - locale: The asset locale. The default is the primary locale.
    /// - Returns: The URL of the character selection image.
    public static func selectionImageURL(forID id: Int, in locale: SekaiLocale = .primaryLocale) -> URL {
        //        Bundle.module.url(forResource: "chr_ts_\(id)", withExtension: "png") ??
        .init(string: "https://storage.sekai.best/\(locale._assetsPath)/character/character_select/chr_tl_\(id).webp")!
    }
}

extension Character {
    /// The URL of the bundled character icon, or `nil` if the icon is unavailable.
    public var iconImageURL: URL? {
        Self.iconImageURL(forID: self.id)
    }
    
    /// Returns the bundled icon URL for a character.
    ///
    /// Unit-specific Virtual Singer identifiers are mapped to their base characters,
    /// except for Miku, whose unit-specific icons are preserved.
    ///
    /// - Parameter id: The character identifier.
    /// - Returns: The bundled icon URL, or `nil` if the resource is unavailable.
    public static func iconImageURL(forID id: Int) -> URL? {
        let mappedID = Self.mapVirtualSingerID(id)
        return Bundle.module.url(forResource: "chr_ts_\(mappedID)", withExtension: "png")
    }
}

extension Character {
    /// Maps a unit-specific Virtual Singer identifier to its base character identifier.
    ///
    /// - Parameters:
    ///   - id: The character identifier to map.
    ///   - includeMiku: Whether to map Miku’s unit-specific identifiers as well.
    /// - Returns: The base identifier, or the original identifier if no mapping applies.
    public static func mapVirtualSingerID(_ id: Int, includeMiku: Bool = false) -> Int {
        var vsMappingID: [ClosedRange: Int] = [32...36: 22, 37...41: 23, 42...46: 24, 47...51: 25, 52...56: 26]
        if includeMiku {
            vsMappingID.updateValue(21, forKey: 27...31)
        }
        return vsMappingID.first { $0.key.contains(id) }?.value ?? id
    }
}
