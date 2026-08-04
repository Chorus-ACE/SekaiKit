//
//  SekaiFilterElementProtocol.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/8/2.
//

import Foundation

protocol SekaiFilterElementProtocol {
    var filterValue: Int { get }
    static var filterKey: SekaiFilter.Key { get }
}

extension Unit: SekaiFilterElementProtocol {
    var filterValue: Int { self.numericID }
    static let filterKey = {
        SekaiFilter.Key(id: "unit", options: Self.allCases.map({
            .init(id: $0.filterValue,
                  selectorName: $0.localizedName,
                  selectorImage: $0.iconImageURL)
        }))
    }()
}

extension Card.Attribute: SekaiFilterElementProtocol {
    var filterValue: Int {
        switch self {
        case .cute: 0
        case .mysterious: 1
        case .cool: 2
        case .happy: 3
        case .pure: 4
        }
    }
    
    static let filterKey = {
        SekaiFilter.Key(id: "attribute", options: Self.allCases.map({
            .init(id: $0.filterValue,
                  selectorName: $0.rawValue.uppercased(),
                  selectorImage: Bundle.module.url(forResource: "icon_attribute_\($0.rawValue)", withExtension: "png")) }))
    }()
}

extension Card.Rarity: SekaiFilterElementProtocol {
    var filterValue: Int { self.integer ?? 0 }
    
    static let filterKey = {
        SekaiFilter.Key(id: "rarity", options: Self.allCases.map({
            .init(id: $0.filterValue,
                  selectorName: $0.localizedName,
                  selectorImage: Bundle.module.url(forResource: $0.rawValue, withExtension: "png")) }))
    }()
}

extension Character: SekaiFilterElementProtocol {
    var filterValue: Int { self.id }
    
    static let filterKey = {
        SekaiFilter.Key(id: "character", options: SekaiCache.preCache.characters.map({
            .init(id: $0.id,
                  selectorName: $0.fullName.forPreferredLocale() ?? "",
                  selectorImage: Bundle.module.url(forResource: "chr_ts_\($0.id)", withExtension: "png")) }))
    }()
}

extension SekaiLocale: SekaiFilterElementProtocol {
    var filterValue: Int { self.rawIntValue }
    
    static let filterKey = {
        SekaiFilter.Key(id: "locale", options: Self.allCases.map({
            .init(id: $0.filterValue,
                  selectorName: $0.rawValue.uppercased()) }))
    }()
}

extension Card.SourceType: SekaiFilterElementProtocol {
    var filterValue: Int { self.rawValue }
    
    static let filterKey = {
        SekaiFilter.Key(id: "card-source", options: Self.allCases.map({
            .init(id: $0.filterValue,
                  selectorName: $0.localizedName) }))
    }()
}

extension Event.EventType: SekaiFilterElementProtocol {
    var filterValue: Int {
        switch self {
        case .marathon: 0
        case .cheerfulCarnival: 1
        case .worldLink: 2
        }
    }
    
    static let filterKey = {
        SekaiFilter.Key(id: "rarity", options: Self.allCases.map({
            .init(id: $0.filterValue,
                  selectorName: "Filter.key.event-type.\($0.rawValue)") }))
    }()
}
