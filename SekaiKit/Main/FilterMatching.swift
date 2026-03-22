//
//  FilterMatching.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/3/22.
//

public protocol SekaiFilterable {
    static var applicableFilteringKeys: [SekaiFilter.Key] { get }
    
    // `matches` only handle single value.
    // Please keep in mind that it does handle values like any `Array` or `characterRequiresMatchAll`.
    // Unexpected value type or cache reading failure will lead to `nil` return.
    func _matches<ValueType>(_ value: ValueType) -> Bool?
}

// MARK: extension PreviewCard
extension Card: SekaiFilterable {
    @inlinable
    public static var applicableFilteringKeys: [SekaiFilter.Key] {
        [.character, .unit, .supportUnit, .cardAttribute, .cardSource, .cardRarity, .skill]
    }
    
    public func _matches<ValueType>(_ value: ValueType) -> Bool? {
        if let character = value as? SekaiFilter.Character {
            return self.characterID == character.rawValue
        } else if let unit = value as? SekaiFilter.Unit {
            return self.unit == unit
        } else if let supportUnit = value as? SekaiFilter.SupportingUnit {
            return self.supportUnit == supportUnit.value
        } else if let cardAttribute = value as? SekaiFilter.CardAttribute {
            return self.attribute == cardAttribute
        } else if let cardSource = value as? SekaiFilter.CardSource {
            return self.sourceType == cardSource
        } else if let cardRarity = value as? SekaiFilter.CardRarity {
            return self.cardRarityType == cardRarity
        } else if let skill = value as? SekaiFilter.Skill { // Skill
            return self.skillID == skill.id
        } else {
            return nil // Unexpected: unexpected value type
        }
    }
}


extension Array where Element: SekaiFilterable {
    public func filter(withSekaiFilter filter: SekaiFilter) -> [Element] {
        var result: [Element] = self
        guard filter.isFiltered else { return result }
//        let cacheCopy: DoriFrontend._FilterCache = FilterCacheManager.shared.read()
        
        result = result.filter { element in
            guard filter.character != Set(SekaiFilter.Character.allCases) else { return true }
            return filter.character.contains { character in
                element._matches(character) ?? true
            }
        } .filter { element in
            guard filter.unit != Set(SekaiFilter.Unit.allCases) else { return true }
            return filter.unit.contains { unit in
                element._matches(unit) ?? true
            }
        } .filter { element in
            guard filter.supportUnit != Set(SekaiFilter.SupportingUnit.allCases) else { return true }
            return filter.supportUnit.contains { unit in
                element._matches(unit) ?? true
            }
        } .filter { element in
            guard filter.cardAttribute != Set(SekaiFilter.CardAttribute.allCases) else { return true }
            return filter.cardAttribute.contains { attribute in
                element._matches(attribute) ?? true
            }
        } .filter { element in
            guard filter.cardRarity != Set(SekaiFilter.CardRarity.allCases) else { return true }
            return filter.cardRarity.contains { rarity in
                element._matches(rarity) ?? true
            }
        } .filter { element in
            guard filter.cardSource != Set(SekaiFilter.CardSource.allCases) else { return true }
            return filter.cardSource.contains { source in
                element._matches(source) ?? true
            }
        } .filter { element in
            guard filter.skill != nil else { return true }
            return element._matches(filter.skill) ?? true
        }
        
        return result
    }
    
    mutating func filter(withSekaiFilter filter: SekaiFilter) {
        self = self.filter(withSekaiFilter: filter)
    }
}
