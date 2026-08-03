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
    static var filterKey: SekaiFilter.Key {
        .init(id: "unit", options: Self.allCases.map({
            .init(id: $0.filterValue,
                  selectorName: $0.localizedName,
                  selectorImage: $0.iconImageURL)
        }))
    }
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
    
    static var filterKey: SekaiFilter.Key {
        .init(id: "attribute", options: Self.allCases.map({
            .init(id: $0.filterValue,
                  selectorName: $0.rawValue.uppercased(),
                  selectorImage: Bundle.module.url(forResource: "icon_attribute_\($0.rawValue)", withExtension: "png")) }))
    }
}

extension Card.Rarity: SekaiFilterElementProtocol {
    var filterValue: Int { self.integer ?? 0 }
    
    static var filterKey: SekaiFilter.Key {
        .init(id: "rarity", options: Self.allCases.map({
            .init(id: $0.filterValue,
                  selectorName: "Filter.key.rarity.\($0.rawValue)",
                  selectorImage: Bundle.module.url(forResource: $0.rawValue, withExtension: "png")) }))
    }
}

extension Character: SekaiFilterElementProtocol {
    var filterValue: Int { self.id }
    
    static var filterKey: SekaiFilter.Key {
        .init(id: "character", options: SekaiCache.preCache.characters.map({
            .init(id: $0.id,
                  selectorName: $0.fullName.forPreferredLocale() ?? "",
                  selectorImage: Bundle.module.url(forResource: "chr_ts_\($0.id)", withExtension: "png")) }))
    }
}

extension SekaiLocale: SekaiFilterElementProtocol {
    var filterValue: Int { self.rawIntValue }
    
    static var filterKey: SekaiFilter.Key {
        .init(id: "locale", options: Self.allCases.map({
            .init(id: $0.filterValue,
                  selectorName: $0.rawValue.uppercased()) }))
    }
}

extension Card.SourceType: SekaiFilterElementProtocol {
    var filterValue: Int { self.rawValue }
    
    static var filterKey: SekaiFilter.Key {
        .init(id: "card-source", options: Self.allCases.map({
            .init(id: $0.filterValue,
                  selectorName: $0.localizedName) }))
    }
}

extension Event.EventType: SekaiFilterElementProtocol {
    var filterValue: Int {
        switch self {
        case .marathon: 0
        case .cheerfulCarnival: 1
        case .worldLink: 2
        }
    }
    
    static var filterKey: SekaiFilter.Key {
        .init(id: "rarity", options: Self.allCases.map({
            .init(id: $0.filterValue,
                  selectorName: "Filter.key.event-type.\($0.rawValue)") }))
    }
}
