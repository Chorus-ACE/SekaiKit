//
//  Filterable.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/8/2.
//

import Foundation

extension Card: SekaiFilterable {
    public static var filterKeys: [SekaiFilter.Key] {
        [Unit.filterKey, Card.Attribute.filterKey, Card.Rarity.filterKey, Character.filterKey, Card.SourceType.filterKey]
    }
    
    public func _matches(_ filter: SekaiFilter) -> Bool {
        let alpha: [any SekaiFilterElementProtocol] = [self.unit, self.attribute, self.rarity, self.sourceType]
        for a in alpha {
            if !filter.contains(a) {
                return false
            }
        }
        
        let bravo: [(key: String, value: Int)] = [("character", self.characterID)]
        for b in bravo {
            if !filter.contains(key: b.key, value: b.value) {
                return false
            }
        }
        
        return true
    }
}

extension Event: SekaiFilterable {
    public static var filterKeys: [SekaiFilter.Key] {
        [Card.Attribute.filterKey]
    }
    
    public func _matches(_ filter: SekaiFilter) -> Bool {
//        let alpha: [any SekaiFilterElementProtocol] = [self.eventType]
        // TODO: Event Filter
        return true
    }
}
