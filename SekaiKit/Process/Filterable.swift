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
        let automaticValues: [any SekaiFilterElementProtocol] = [self.unit, self.attribute, self.rarity, self.sourceType]
        for item in automaticValues {
            if !filter.permits(item) {
                return false
            }
        }
        
        let maunalValues: [(key: String, value: Int)] = [(Character.filterKey.id, self.characterID)]
        for item in maunalValues {
            if !filter.permits(item.value, inKey: item.key) {
                return false
            }
        }
        
        return true
    }
}

extension Event: SekaiFilterable {
    public static var filterKeys: [SekaiFilter.Key] {
        [Unit.filterKey.withOtherOption, Card.Attribute.filterKey.withOtherOption, Event.EventType.filterKey, Character.filterKey, Character.matchingStrategyKey]
    }
    
    public func _matches(_ filter: SekaiFilter) -> Bool {
        let automaticValues: [any SekaiFilterElementProtocol] = [self.unit, self.attribute, self.eventType]
        for item in automaticValues {
            if !filter.permits(item) {
                return false
            }
        }
        
        let characters = self.characters.map({ Character.mapVirtualSingerID($0, includeMiku: true) })
        
        let requiresMatchAll = filter[Character.matchingStrategyKey.id]?.first == 1
        let selectedCharacters = filter[Character.filterKey.id]?.compactMap({$0}) ?? []
        
        if requiresMatchAll {
            if !selectedCharacters.allSatisfy({ character in
                self.characters.contains(character)
            }) {
                return false
            }
        } else {
            if !characters.contains(where: { character in
                self.characters.contains(character)
            }) {
                return false
            }
        }
        
        return true
    }
}
