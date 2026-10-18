//
//  Filterable.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/8/2.
//

import Foundation

extension Card: SekaiFilterable {
    /// Support units use the same options as the main unit filter.
    public static let supportUnitFilterKey = SekaiFilter.Key(id: "supportUnit", options: Unit.filterKey.options)

    /// The filter keys supported by this content type.
    public static var filterKeys: [SekaiFilter.Key] {
        [Unit.filterKey, Card.supportUnitFilterKey, Card.Attribute.filterKey, Card.Rarity.filterKey, Character.filterKey, Card.SourceType.filterKey]
    }
    
    /// Evaluates the selected options against this record.
    ///
    /// - Parameter filter: The filter selections to apply.
    /// - Returns: `true` if the record satisfies the selections.
    public func _matches(_ filter: SekaiFilter) -> Bool {
        let automaticValues: [any SekaiFilterElementProtocol] = [self.unit, self.attribute, self.rarity, self.sourceType]
        for item in automaticValues {
            guard filter.permits(item) else { return false }
        }
        
        // Cards without a support unit belong to the Virtual Singer option.
        // Only cards with a Virtual Singer main unit have a support unit to filter.
        if unit == .virtualSinger {
            guard filter.permits((supportUnit ?? .virtualSinger).intRawValue, inKey: Self.supportUnitFilterKey.id) else { return false }
        }

        let maunalValues: [(key: String, value: Int)] = [(Character.filterKey.id, self.characterID)]
        for item in maunalValues {
            guard filter.permits(item.value, inKey: item.key) else { return false }
        }
        
        return true
    }
}

extension Event: SekaiFilterable {
    /// The filter keys supported by this content type.
    public static var filterKeys: [SekaiFilter.Key] {
        [Unit.filterKey.withOtherOption, Card.Attribute.filterKey.withOtherOption, Event.EventType.filterKey, Character.filterKey, Character.matchingStrategyKey]
    }
    
    /// Evaluates the selected options against this record.
    ///
    /// - Parameter filter: The filter selections to apply.
    /// - Returns: `true` if the record satisfies the selections.
    public func _matches(_ filter: SekaiFilter) -> Bool {
        let automaticValues: [any SekaiFilterElementProtocol] = [self.unit, self.attribute, self.eventType]
        for item in automaticValues {
            guard filter.permits(item) else { return false }
        }
        
        let characters = self.characters.map({ Character.mapVirtualSingerID($0, includeMiku: true) })
        
        let requiresMatchAll = filter[Character.matchingStrategyKey]?.first == 1
        guard let selection = filter[Character.filterKey] else { return true }
        let selectedCharacters = selection.compactMap { $0 }
        guard !selectedCharacters.isEmpty else { return false }
        
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
    /// An optional exact chart level; an empty selection disables this filter.
    public static let levelFilterKey = SekaiFilter.Key(id: "song-level", allowMultipleSelection: false, options: [], defaultOptions: [])

    /// The filter keys supported by this content type.
    public static var filterKeys: [SekaiFilter.Key] {
        [Unit.filterKey.withOtherOption, Song.MediaType.filterKey, hasAppendFilterKey, levelFilterKey]
    }
    
    /// Evaluates the selected options against this record.
    ///
    /// - Parameter filter: The filter selections to apply.
    /// - Returns: `true` if the record satisfies the selections.
    public func _matches(_ filter: SekaiFilter) -> Bool {
        if let levels = filter[Self.levelFilterKey], !levels.isEmpty {
            guard difficultyLevel.values.contains(where: { levels.contains($0) }) else { return false }
        }
        guard filter["song-has-append"]?.contains(self.difficultyLevel.keys.contains(.append).filterValue) ?? true else { return false }
        if let media = filter[Song.MediaType.filterKey], media != Song.MediaType.filterKey.defaultOptionsID {
            guard availableMedia.contains(where: { media.contains($0.filterValue) }) else { return false }
        }

        if let selectedUnits = filter[Unit.filterKey] {
            // `all` accompanies named categories, but on its own represents mixed-unit music.
            let categories = categories.filter { $0 != .all }
            let units: [Int?] = categories.isEmpty ? [nil] : categories.map { $0.correspondingUnit?.filterValue }
            guard selectedUnits.contains(where: units.contains) else { return false }
        }
        return true
    }
}
