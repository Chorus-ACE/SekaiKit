//
//  Unit.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/1/16.
//

import Foundation

public enum Unit: String, Hashable, CaseIterable, Codable, Sendable, SekaiCachable {
    case virturalSinger = "piapro"
    case leoNeed = "light_sound"
    case moreMoreJump = "idol"
    case vividBadSquad = "street"
    case wonderlandsShowtime = "theme_park"
    case nightcordAt25 = "school_refusal"
    
    public var localizedName: String {
        NSLocalizedString("Unit.\(self.rawValue)", bundle: #bundle, comment: "")
    }
    
    public var numericID: Int {
        switch self {
        case .virturalSinger:
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
    
    public var members: [Int] {
        switch self {
        case .virturalSinger:
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
    
    public static var allSupportableUnits: [Unit] {
        return Unit.allCases.filter({ $0 != .virturalSinger })
    }
    
    public init?(member id: Int) {
        if let unit = Unit.allCases.first(where: { $0.members.contains(id) }) {
            self = unit
        } else {
            return nil
        }
    }
}

extension Unit {
    @inlinable
    public var logoImageURL: URL {
        .init(string: "https://sekai.best/images/\(SekaiLocale.primaryLocale.rawValue)/logol_outline/logo_\(self.rawValue).png")!
    }
    @inlinable
    public func logoImageURL(in locale: SekaiLocale = SekaiLocale.primaryLocale) -> URL {
        .init(string: "https://sekai.best/images/\(locale.rawValue)/logol_outline/logo_\(self.rawValue).png")!
    }
}
