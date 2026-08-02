//
//  Filterable.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/8/2.
//

import Foundation

extension Card: NeoSekaiFilterable {
    public static var filterKeys: [NeoSekaiFilter.Key] {
        [Unit.filterKey, Card.Attribute.filterKey, Card.Rarity.filterKey, Character.filterKey]
    }
    
    public func _matches(_ filter: NeoSekaiFilter) -> Bool {
        let alpha: [any SekaiFilterElementProtocol] = [self.unit, self.attribute, self.rarity]
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
