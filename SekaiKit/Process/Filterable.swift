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
            guard filter.permits(item) else { return false }
        }
        
        let maunalValues: [(key: String, value: Int)] = [(Character.filterKey.id, self.characterID)]
        for item in maunalValues {
            guard filter.permits(item.value, inKey: item.key) else { return false }
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
            guard filter.permits(item) else { return false }
        }
        
        let characters = self.characters.map({ Character.mapVirtualSingerID($0, includeMiku: true) })
        
        let requiresMatchAll = filter[Character.matchingStrategyKey]?.first == 1
        let selectedCharacters = filter[Character.filterKey]?.compactMap({$0}) ?? []
        
        if requiresMatchAll {
            guard selectedCharacters.allSatisfy(characters.contains) else { return false }
        } else {
            guard selectedCharacters.contains(where: characters.contains) else { return false }
        }
        
        return true
    }
}

private let hasAppendFilterKey = SekaiFilter.Key(
    id: "song-has-append",
    options: [
        .init(id: 1, selectorName: NSLocalizedString("Filter.option.available", bundle: #bundle, comment: "")),
        .init(id: 0, selectorName: NSLocalizedString("Filter.option.unavailable", bundle: #bundle, comment: ""))
    ]
)

extension Song: SekaiFilterable {
    public static var filterKeys: [SekaiFilter.Key] {
        [Unit.filterKey.withOtherOption, Song.MediaType.filterKey, hasAppendFilterKey]
    }
    
    public func _matches(_ filter: SekaiFilter) -> Bool {
        guard filter["song-has-append"]?.contains(self.difficultyLevel.keys.contains(.append).filterValue) ?? true else { return false }
        guard filter[Song.MediaType.filterKey]?.contains(where: self.availableMedia.map(\.filterValue).contains) ?? true else { return false }
        
        let selectedUnits = filter[Unit.filterKey] ?? []
        let categories = self.categories.compactMap({ $0 == .all ? nil : $0 }).map(\.correspondingUnit?.filterValue)
        
        guard selectedUnits.contains(where: categories.contains) else { return false }
        
        return true
    }
}
