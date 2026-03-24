//
//  Filter.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/2/28.
//

import Foundation
internal import CryptoKit

public struct SekaiFilter: Hashable, Sendable, SekaiCachable {
    public var character: Set<Self.Character> = Set(Self.Character.allCases) { didSet { store() } }
    public var unit: Set<Self.Unit> = Set(Self.Unit.allCases) { didSet { store() } }
    public var supportUnit: Set<Self.SupportingUnit> = Set(Self.SupportingUnit.allCases) { didSet { store() } }
    public var cardAttribute: Set<Self.CardAttribute> = Set(Self.CardAttribute.allCases) { didSet { store() } }
    public var cardRarity: Set<Self.CardRarity> = Set(Self.CardRarity.allCases) { didSet { store() } }
    public var cardSource: Set<Self.CardSource> = Set(Self.CardSource.allCases)
    public var skill: Skill? = nil { didSet { store() } }
    
    public init(
        character: Set<Self.Character> = Set(Self.Character.allCases),
        unit: Set<Self.Unit> = Set(Self.Unit.allCases),
        supportUnit: Set<Self.SupportingUnit> = Set(Self.SupportingUnit.allCases),
        cardAttribute: Set<Self.CardAttribute> = Set(Self.CardAttribute.allCases),
        cardRarity: Set<Self.CardRarity> = Set(Self.CardRarity.allCases),
        cardSource: Set<Self.CardSource> = Set(Self.CardSource.allCases),
        skill: Skill? = nil
    ) {
        self.character = character
        self.unit = unit
        self.supportUnit = supportUnit
        self.cardAttribute = cardAttribute
        self.cardRarity = cardRarity
        self.cardSource = cardSource
        self.skill = skill
    }
    
    
    private var recoveryID: String?
    
    public static func recoverable(id: String) -> Self {
        let storageURL = URL(filePath: NSHomeDirectory() + "/Documents/SekaiKit_Filter_Status.plist")
        let decoder = PropertyListDecoder()
        var result: Self = if let _data = try? Data(contentsOf: storageURL),
                              let storage = try? decoder.decode([String: Self].self, from: _data) {
            storage[id] ?? .init()
        } else {
            .init()
        }
        result.recoveryID = id
        return result
    }
    
    public var isFiltered: Bool {
        character != Set(Self.Character.allCases) ||
        unit != Set(Self.Unit.allCases) ||
        supportUnit != Set(Self.SupportingUnit.allCases) ||
        cardAttribute != Set(Self.CardAttribute.allCases) ||
        cardRarity != Set(Self.CardRarity.allCases) ||
        cardSource != Set(Self.CardSource.allCases) ||
        skill != nil
    }
    
    public var identity: String {
        let desc = """
            \(character.sorted { $0.rawValue < $1.rawValue })\
            \(unit.sorted { $0.rawValue < $1.rawValue })\
            \(supportUnit.sorted { $0.value.rawValue < $1.value.rawValue })\
            \(cardAttribute.sorted { $0.rawValue < $1.rawValue })\
            \(cardRarity.sorted { $0.rawValue < $1.rawValue })\
            \(cardSource.sorted { $0.rawValue < $1.rawValue })\
            \(skill?.id)
            """
        
        return String(SHA256.hash(data: desc.data(using: .utf8)!).map { $0.description }.joined().prefix(8))
    }
    
    public mutating func clearAll() {
        character = Set(Self.Character.allCases)
        unit = Set(Self.Unit.allCases)
        supportUnit = Set(Self.SupportingUnit.allCases)
        cardAttribute = Set(Self.CardAttribute.allCases)
        cardRarity = Set(Self.CardRarity.allCases)
        cardSource = Set(Self.CardSource.allCases)
        skill = nil
    }
    
    private static let _storageLock = NSLock()
    private func store() {
        guard let recoveryID else { return }
        DispatchQueue(label: "com.chrous-ace.sekai-kit.filter-store", qos: .utility).async {
            Self._storageLock.lock()
            let storageURL = URL(filePath: NSHomeDirectory() + "/Documents/SekaiKit_Filter_Status.plist")
            let decoder = PropertyListDecoder()
            let encoder = PropertyListEncoder()
            if let _data = try? Data(contentsOf: storageURL),
               var storage = try? decoder.decode([String: Self].self, from: _data) {
                storage.updateValue(self, forKey: recoveryID)
                try? encoder.encode(storage).write(to: storageURL)
            } else {
                let storage = [recoveryID: self]
                try? encoder.encode(storage).write(to: storageURL)
            }
            Self._storageLock.unlock()
        }
    }
}

//public struct SekaiFilter: Hashable, Sendable, SekaiCachable {
//    public var character: Set<Self.Character> = Set(Self.Character.allCases)
//    public var unit: Set<Unit> = Set(Unit.allCases)
//    public var supportUnit: Set<Unit> = Set(Unit.allSupportableUnits)
//    public var cardAttribute: Set<Card.Attribute> = Set(Card.Attribute.allCases)
//    public var cardRarity: Set<Card.Rarity> = Set(Card.Rarity.allCases)
//    public var cardSource: Set<Card.SourceType> = Set(Card.SourceType.allCases)
//    public var skill: Int? = nil
//}
//
public extension SekaiFilter {
    public typealias Unit = SekaiKit.Unit
    public typealias CardAttribute = Card.Attribute
    public typealias CardRarity = Card.Rarity
    public typealias CardSource = Card.SourceType
    public typealias Skill = SekaiKit.Skill
    
    enum Keys: String, CaseIterable, Codable, Hashable, Sendable, SekaiCachable {
        case character
        case unit
        case supportUnit
        case cardAttribute
        case cardRarity
        case cardSource
        case skill
        
        public var localizedName: String {
            NSLocalizedString("Filter.keys.\(self.rawValue)", bundle: #bundle, comment: "")
        }
    }
    
    public enum Character: Int, CaseIterable, Codable, Hashable, Sendable, SekaiCachable {
        case ichika = 1
        case saki
        case honami
        case shiho
        
        case minori = 5
        case haruka
        case airi
        case shizuku

        case kohane = 9
        case an
        case akito
        case toya
        
        case tsukasa = 13
        case emu
        case nene
        case rui

        case kanade = 17
        case mafuyu
        case ena
        case mizuki

        case miku = 21
        case rin
        case len
        case luka
        case meiko
        case kaito
        
        public var name: String {
            NSLocalizedString("Filter.key.character.\(self.rawValue)", bundle: #bundle, comment: "")
        }
    }
    
    public struct SupportingUnit: Hashable, Codable, Sendable, SekaiCachable {
        public var value: SekaiKit.Unit
        
        public static var allCases: [SupportingUnit] {
            return SekaiKit.Unit.allSupportableUnits.map(SupportingUnit.init)
        }
    }
}

extension SekaiFilter {
    public enum Key: Int, CaseIterable, Hashable {
        case character
        case unit
        case supportUnit
        case cardAttribute
        case cardRarity
        case cardSource
        case skill
    }
}

extension SekaiFilter.Key: Identifiable {
    public var id: Int { self.rawValue }
}

extension Set<SekaiFilter.Key> {
    @inlinable
    public func sorted() -> [SekaiFilter.Key] {
        self.sorted { $0.rawValue < $1.rawValue }
    }
}
extension Array<SekaiFilter.Key> {
    @inlinable
    public func sorted() -> [SekaiFilter.Key] {
        self.sorted { $0.rawValue < $1.rawValue }
    }
}

extension SekaiFilter.Key {
    @inline(never)
    public var localizedString: String {
        switch self {
        case .character: String(localized: "Filter.key.character", bundle: #bundle)
        case .unit: String(localized: "Filter.key.unit", bundle: #bundle)
        case .supportUnit: String(localized: "Filter.key.support-unit", bundle: #bundle)
        case .cardAttribute: String(localized: "Filter.key.card-attribute", bundle: #bundle)
        case .cardRarity: String(localized: "Filter.key.card-rarity", bundle: #bundle)
        case .cardSource: String(localized: "Filter.key.card-source", bundle: #bundle)
        case .skill: String(localized: "Filter.key.skill", bundle: #bundle)
        }
    }
}


extension SekaiFilter.Key: Comparable {
    @inlinable
    public static func < (lhs: SekaiFilter.Key, rhs: SekaiFilter.Key) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension SekaiFilter: MutableCollection {
    public typealias Element = AnyHashable
    
    @inlinable
    public var startIndex: Key { .character }
    @inlinable
    public var endIndex: Key { .skill }
    @inlinable
    public func index(after i: Key) -> Key {
        .init(rawValue: i.rawValue + 1)!
    }
    
    public subscript(position: Key) -> AnyHashable {
        get {
            switch position {
            case .character: self.character
            case .unit: self.unit
            case .supportUnit: self.supportUnit
            case .cardAttribute: self.cardAttribute
            case .cardRarity: self.cardRarity
            case .cardSource: self.cardSource
            case .skill: self.skill
            }
        }
        set {
            self.updateValue(newValue, forKey: position)
        }
    }
    
    /// Update a value of filter for key.
    ///
    /// - Parameters:
    ///   - value: Type-erased value.
    ///   - key: Key for filter item.
    ///
    /// The underlying value of type-erased value passed to this method must match the actual value type of key,
    /// or this method logs the event and does nothing.
    public mutating func updateValue(_ value: AnyHashable, forKey key: Key) {
        let expectedValueType = type(of: self[key])
        let valueType = type(of: value)
        typeCheck: if valueType != expectedValueType {
//            if key == .released && valueType == Bool.self {
//                break typeCheck
//            }
            logger.critical("Failed to update value of filter, expected \(expectedValueType), but got \(valueType)")
            return
        }
        switch key {
        case .character:
            self.character = value as! Set<Self.Character>
        case .unit:
            self.unit = value as! Set<Self.Unit>
        case .supportUnit:
            self.supportUnit = value as! Set<Self.SupportingUnit>
        case .cardAttribute:
            self.cardAttribute = value as! Set<Self.CardAttribute>
        case .cardRarity:
            self.cardRarity = value as! Set<Self.CardRarity>
        case .cardSource:
            self.cardSource = value as! Set<Self.CardSource>
        case .skill:
            self.skill = value as! Skill?
        }
    }
}

extension SekaiFilter {
    @_typeEraser(_AnySelectable)
    public protocol _Selectable: Hashable {
        var selectorText: String { get }
        var selectorImageURL: URL? { get }
    }
    public struct _AnySelectable: _Selectable, Equatable, Hashable {
        private let _selectorText: String
        private let _selectorImageURL: URL?
        
        public let value: AnyHashable
        
        public init<T: _Selectable>(erasing value: T) {
            self._selectorText = value.selectorText
            self._selectorImageURL = value.selectorImageURL
            self.value = value
        }
        public init<T: _Selectable>(_ value: T) {
            self.init(erasing: value)
        }
        internal init<T: _Selectable>(_ value: T, selectorText: String, selectorImageURL: URL? = nil) {
            self._selectorText = selectorText
            self._selectorImageURL = selectorImageURL
            self.value = value
        }
        
        public var selectorText: String { _selectorText }
        public var selectorImageURL: URL? { _selectorImageURL }
    }
}
extension SekaiFilter._Selectable {
    public var selectorImageURL: URL? { nil }
    
    public func isEqual(to selectable: any SekaiFilter._Selectable) -> Bool {
        self.selectorText == selectable.selectorText
    }
}

extension SekaiFilter.Character: SekaiFilter._Selectable {
    public var selectorText: String {
        self.name
    }
    public var selectorImageURL: URL? {
        Bundle.module.url(forResource: "chr_ts_\(self.rawValue)", withExtension: "png")
    }
}

extension SekaiFilter.Unit: SekaiFilter._Selectable {
    public var selectorText: String {
        self.localizedName
    }
    public var selectorImageURL: URL? {
        Bundle.module.url(forResource: "unit_logo_\(self.numericID)", withExtension: "png")
    }
}

extension SekaiFilter.SupportingUnit: SekaiFilter._Selectable {
    public var selectorText: String {
        self.value.localizedName
    }
    public var selectorImageURL: URL? {
        Bundle.module.url(forResource: "unit_logo_\(self.value.numericID)", withExtension: "png")
    }
}

extension SekaiFilter.CardAttribute: SekaiFilter._Selectable {
    public var selectorText: String {
        self.rawValue.uppercased()
    }
    public var selectorImageURL: URL? {
        Bundle.module.url(forResource: "icon_attribute_\(self.rawValue)", withExtension: "png")
    }
}

extension SekaiFilter.CardSource: SekaiFilter._Selectable {
    public var selectorText: String {
        self.localizedName
    }
}

extension SekaiFilter.CardRarity: SekaiFilter._Selectable {
    public var selectorText: String {
        self.localizedName
    }
    public var selectorImageURL: URL? {
        Bundle.module.url(forResource: self.rawValue, withExtension: "png")
    }
}

extension Optional<SekaiFilter.Skill>: SekaiFilter._Selectable {
    @inline(never)
    public var selectorText: String {
        if let skill = self {
            skill.description // FIXME: Localization?
        } else {
            String(localized: "Filter.skill.any", bundle: #bundle)
        }
    }
}

extension SekaiFilter.Key {
    public var selector: (type: SelectionType, items: [SelectorItem<SekaiFilter._AnySelectable>]) {
        switch self {
        case .character:
            (.multiple, SekaiFilter.Character.allCases.map {
                SelectorItem(SekaiFilter._AnySelectable($0))
            })
        case .unit:
            (.multiple, SekaiFilter.Unit.allCases.map {
                SelectorItem(SekaiFilter._AnySelectable($0))
            })
        case .supportUnit:
            (.multiple, SekaiFilter.SupportingUnit.allCases.map {
                SelectorItem(SekaiFilter._AnySelectable($0))
            })
        case .cardAttribute:
            (.multiple, SekaiFilter.CardAttribute.allCases.map {
                SelectorItem(SekaiFilter._AnySelectable($0))
            })
        case .cardSource:
            (.multiple, SekaiFilter.CardSource.allCases.map {
                SelectorItem(SekaiFilter._AnySelectable($0))
            })
        case .cardRarity:
            (.multiple, SekaiFilter.CardRarity.allCases.map {
                SelectorItem(SekaiFilter._AnySelectable($0))
            })
        case .skill:
//            (.single, Skills.all.map {
//                SelectorItem(SekaiFilter._AnySelectable($0))
//            } ?? [])
            (.single, [])
            
            // FIXME: All Skills
        }
    }
    
    public struct SelectorItem<T: SekaiFilter._Selectable> {
        public let item: T
        
        internal init(_ item: T) {
            self.item = item
        }
        
        public var text: String {
            item.selectorText
        }
        public var imageURL: URL? {
            item.selectorImageURL
        }
    }
    
    @frozen
    public enum SelectionType {
        case single
        case multiple
    }
}


extension SekaiFilter.Key.SelectorItem: Equatable where T: Equatable {}
extension SekaiFilter.Key.SelectorItem: Hashable where T: Hashable {}
