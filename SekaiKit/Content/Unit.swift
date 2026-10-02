//
//  Unit.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/1/16.
//

import Foundation

/// A musical unit appearing in Project Sekai.
public enum Unit: String, Hashable, CaseIterable, Codable, Sendable, SekaiCachable {
    /// Virtual Singers.
    case virtualSinger = "piapro"
    /// Leo/need.
    case leoNeed = "light_sound"
    /// MORE MORE JUMP!.
    case moreMoreJump = "idol"
    /// Vivid BAD SQUAD.
    case vividBadSquad = "street"
    /// Wonderlands×Showtime.
    case wonderlandsShowtime = "theme_park"
    /// Nightcord at 25:00.
    case nightcordAt25 = "school_refusal"
    
    /// The unit name localized for the app’s current language.
    public var localizedName: String {
        NSLocalizedString("Unit.\(self.rawValue)", bundle: #bundle, comment: "")
    }
    
    /// A placeholder unit name repeated for all locales.
    ///
    /// Use ``localizedName`` for the current localized display name.
    public var name: LocalizedData<String> {
        .init(repeating: "Unit Localized Name Placeholder")
//        switch self {
//        case .virturalSinger:
//                .init(jp: "", en: "", tw: "", cn: "", kr: "")
//        case .leoNeed:
//            <#code#>
//        case .moreMoreJump:
//            <#code#>
//        case .vividBadSquad:
//            <#code#>
//        case .wonderlandsShowtime:
//            <#code#>
//        case .nightcordAt25:
//            <#code#>
//        }
//        NSLocalizedString("Unit.\(self.rawValue)", bundle: #bundle, comment: "")
    }
    
    /// The numeric unit identifier used by the game’s assets.
    public var intRawValue: Int {
        switch self {
        case .virtualSinger:
            return 6
        case .leoNeed:
            return 1
        case .moreMoreJump:
            return 2
        case .vividBadSquad:
            return 3
        case .wonderlandsShowtime:
            return 4
        case .nightcordAt25:
            return 5
        }
    }
    
    /// The base character identifiers of the unit’s members.
    public var members: [Int] {
        switch self {
        case .virtualSinger:
            return [21, 22, 23, 24, 25, 26]
        case .leoNeed:
            return [1, 2, 3, 4]
        case .moreMoreJump:
            return [5, 6, 7, 8]
        case .vividBadSquad:
            return [9, 10, 11, 12]
        case .wonderlandsShowtime:
            return [13, 14, 15, 16]
        case .nightcordAt25:
            return [17, 18, 19, 20]
        }
    }
    
    /// The units that Virtual Singers can support, excluding the Virtual Singer group.
    public static var allSupportableUnits: [Unit] {
        return Unit.allCases.filter({ $0 != .virtualSinger })
    }
    
    /// Creates the unit containing a base character identifier.
    ///
    /// The initializer returns `nil` when no unit’s member list contains the identifier.
    ///
    /// - Parameter id: The base character identifier to look up.
    public init?(member id: Int) {
        if let unit = Unit.allCases.first(where: { $0.members.contains(id) }) {
            self = unit
        } else {
            return nil
        }
    }
}


//public struct UnitInfo: Hashable, Codable, Sendable, Identifiable, SekaiCachable {
//    public var id: Int { get }
//    public var name: String
//    public var description: String
//    
//    public static func allInLocale(_ locale: SekaiLocale) async -> [UnitInfo]? {
//        <#code#>
//    }
//}

extension Unit {
    /// The unit logo URL for the primary locale.
    @inlinable
    public var logoImageURL: URL {
        .init(string: "https://sekai.best/images/\(SekaiLocale.primaryLocale.rawValue)/logol_outline/logo_\(self.rawValue).png")!
    }
    /// Returns the unit logo URL for a locale.
    ///
    /// - Parameter locale: The asset locale. The default is the primary locale.
    /// - Returns: The unit logo URL.
    @inlinable
    public func logoImageURL(in locale: SekaiLocale = SekaiLocale.primaryLocale) -> URL {
        .init(string: "https://sekai.best/images/\(locale.rawValue)/logol_outline/logo_\(self.rawValue).png")!
    }
    
    /// The URL of the unit icon bundled with SekaiKit.
    public var iconImageURL: URL {
        Bundle.module.url(forResource: "unit_logo_\(self.intRawValue)", withExtension: "png")!
    }
}
