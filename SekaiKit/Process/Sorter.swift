//===---*- Greatdori! -*---------------------------------------------------===//
//
// Filter.swift
//
// This source file is part of the Greatdori! open source project
//
// Copyright (c) 2025 the Greatdori! project authors
// Licensed under Apache License v2.0
//
// See https://greatdori.com/LICENSE.txt for license information
// See https://greatdori.com/CONTRIBUTORS.txt for the list of Greatdori! project authors
//
//===----------------------------------------------------------------------===//

import Foundation
internal import CryptoKit

/// A type that supports SekaiKit’s sorting keywords and comparisons.
public protocol SekaiSortable {
    /// The sorting keywords supported by this content type.
    static var applicableSortingTypes: [SekaiSorter.Keyword] { get }
    
    /// A Boolean value indicating whether date sorting should be labeled as an event start date.
    static var hasEndingDate: Bool { get }
    
    /// Compares two values using a SekaiKit sorter.
    ///
    /// - Parameters:
    ///   - usingSekaiSorter: The sorter defining the comparison.
    ///   - lhs: The first value.
    ///   - rhs: The second value.
    /// - Returns: Whether `lhs` precedes `rhs`, or `nil` if the comparison is unsupported.
    static func _compare<ValueType>(usingSekaiSorter: SekaiSorter, lhs: ValueType, rhs: ValueType) -> Bool?
}

/// A sorting keyword and direction, with optional persistence of the selection.
public struct SekaiSorter: Sendable, Equatable, Hashable, Codable {
    /// The direction of this sorter.
    public var direction: Direction { didSet { store() } }
    /// The keyword for sorting.
    public var keyword: Keyword { didSet { store() } }
    
    /// Creates a sorter with given direction and keyword.
    /// - Parameters:
    ///   - keyword: The keyword for sorting.
    ///   - direction: The direction of this sorter.
    public init(keyword: Keyword = .id, direction: Direction = .descending) {
        self.keyword = keyword
        self.direction = direction
    }
    
    private var recoveryID: String?
    
    /// Creates a sorter using saved selections for an identifier, if available.
    ///
    /// - Parameter id: The identifier used to look up and persist selections.
    /// - Returns: A sorter with the recovered selections or the default keyword and direction.
    ///
    public static func recoverable(id: String) -> Self {
        let storageURL = URL(filePath: NSHomeDirectory() + "/Documents/SekaiKit_Sorter_Status.plist")
        let decoder = PropertyListDecoder()
        var result: Self = if let _data = try? Data(contentsOf: storageURL),
                              let storage = try? decoder.decode([String: SekaiSorter].self, from: _data) {
            storage[id] ?? .init()
        } else {
            .init()
        }
        result.recoveryID = id
        return result
    }
    
    /// An eight-character digest derived from the sorting keyword and direction.
    ///
    /// Use this value to group equivalent sorting configurations. As a truncated
    /// digest, it is not guaranteed to be unique.
    public var identity: String {
        let desc = """
            \(direction)\
            \(keyword.rawValue)
            """
        return String(SHA256.hash(data: desc.data(using: .utf8)!).map { $0.description }.joined().prefix(8))
    }
    
    private static let _storageLock = NSLock()
    private func store() {
        guard let recoveryID else { return }
        DispatchQueue(label: "com.memz233.SekaiKit.Sorter-Store", qos: .utility).async {
            Self._storageLock.lock()
            let storageURL = URL(filePath: NSHomeDirectory() + "/Documents/SekaiKit_Sorter_Status.plist")
            let decoder = PropertyListDecoder()
            let encoder = PropertyListEncoder()
            if let _data = try? Data(contentsOf: storageURL),
               var storage = try? decoder.decode([String: SekaiSorter].self, from: _data) {
                storage.updateValue(self, forKey: recoveryID)
                try? encoder.encode(storage).write(to: storageURL)
            } else {
                let storage = [recoveryID: self]
                try? encoder.encode(storage).write(to: storageURL)
            }
            Self._storageLock.unlock()
        }
    }
    
    /// The direction in which values are ordered.
    @frozen
    public enum Direction: String, Equatable, Hashable, Codable {
        /// Orders smaller values before larger values.
        case ascending = "ascending"
        /// Orders larger values before smaller values.
        case descending = "descending"
        
        /// The opposite sorting direction.
        @inlinable
        public var reversed: Self {
            switch self {
            case .ascending: .descending
            case .descending: .ascending
            }
        }
        
        /// Reverses the sorting direction.
        @inlinable
        public mutating func reverse() {
            self = self.reversed
        }
    }
    /// The field used to order records.
    public enum Keyword: CaseIterable, Sendable, Equatable, Hashable, Codable {
        /// Orders records by their release or start date in the associated locale.
        case releaseDate(in: SekaiLocale)
        /// Orders songs by chart level for the associated difficulty.
        case level(for: Song.Difficulty)
        /// Orders cards by rarity.
        case rarity
        /// Orders cards by maximum power.
        case maximumStat
        /// Orders records by identifier.
        case id
        
        /// Every supported sorting keyword, including all locale and difficulty variants.
        public static let allCases: [Self] = [
            .releaseDate(in: .jp),
            .releaseDate(in: .en),
            .releaseDate(in: .tw),
            .releaseDate(in: .cn),
            .releaseDate(in: .kr),
            .level(for: .easy),
            .level(for: .normal),
            .level(for: .hard),
            .level(for: .expert),
            .level(for: .master),
            .level(for: .append),
            .rarity,
            .maximumStat,
            .id
        ]
        
        /// The keyword’s zero-based index in ``allCases``.
        public var rawValue: Int {
            return Self.allCases.firstIndex(where: { $0 == self })!
        }
        
        /// The keyword’s localized label using release-date terminology.
        @inline(never)
        public var localizedString: String {
            self.localizedString()
        }
        
        /// Returns the localized label for a sorting keyword.
        ///
        /// - Parameter hasEndingDate: Whether date keywords should use start-date terminology.
        /// - Returns: The localized keyword label.
        public func localizedString(hasEndingDate: Bool = false) -> String {
            switch self {
            case .releaseDate(let locale):
                hasEndingDate ? String(localized: "Sorter.keyword.starting-date.\(locale.rawValue.uppercased())", bundle: #bundle) : String(localized: "Sorter.keyword.release-date.\(locale.rawValue.uppercased())", bundle: #bundle)
            case .level(let difficulty):
                String(localized: "Sorter.keyword.level.\(difficulty.name)", bundle: #bundle)
            case .rarity: String(localized: "Sorter.keyword.rarity", bundle: #bundle)
            case .maximumStat: String(localized: "Sorter.keyword.max-power", bundle: #bundle)
            case .id: String(localized: "Sorter.keyword.id", bundle: #bundle)
            }
        }
    }
    
    /// Returns a localized direction label appropriate for a keyword.
    ///
    /// - Parameters:
    ///   - keyword: The keyword to describe, or `nil` to use the current keyword.
    ///   - direction: The direction to describe, or `nil` to use the current direction.
    /// - Returns: The localized direction label.
    public func localizedDirectionName(keyword: Keyword? = nil, direction: Direction? = nil) -> String {
        let isAscending: Bool = (direction ?? self.direction) == .ascending
        switch keyword ?? self.keyword {
        case .releaseDate:
            return isAscending ? String(localized: "Sorter.order.oldest-to-newest", bundle: #bundle) : String(localized: "Sorter.order.newest-to-oldest", bundle: #bundle)
        case .level:
            return isAscending ? String(localized: "Sorter.order.ascending", bundle: #bundle) : String(localized: "Sorter.order.descending", bundle: #bundle)
        case .rarity:
            return isAscending ? String(localized: "Sorter.order.ascending", bundle: #bundle) : String(localized: "Sorter.order.descending", bundle: #bundle)
        case .maximumStat:
            return isAscending ? String(localized: "Sorter.order.ascending", bundle: #bundle) : String(localized: "Sorter.order.descending", bundle: #bundle)
        case .id:
            return isAscending ? String(localized: "Sorter.order.ascending", bundle: #bundle) : String(localized: "Sorter.order.descending", bundle: #bundle)
        }
    }
    
    // `nil` values will always be at the last.
    internal func compare<T: Comparable>(_ lhs: T?, _ rhs: T?) -> Bool {
        guard lhs != nil else { return false }
        guard rhs != nil else { return true }
        
        switch direction {
        case .ascending:
            return unsafe lhs.unsafelyUnwrapped < rhs.unsafelyUnwrapped
        case .descending:
            return unsafe lhs.unsafelyUnwrapped > rhs.unsafelyUnwrapped
        }
    }
    // `nil` return value means equal
    internal func strictCompare<T: Comparable>(_ lhs: T?, _ rhs: T?) -> Bool? {
        if lhs == rhs {
            return nil
        }
        guard lhs != nil else { return false }
        guard rhs != nil else { return true }
        
        switch direction {
        case .ascending:
            return unsafe lhs.unsafelyUnwrapped < rhs.unsafelyUnwrapped
        case .descending:
            return unsafe lhs.unsafelyUnwrapped > rhs.unsafelyUnwrapped
        }
    }
}


extension Set<SekaiSorter.Keyword> {
    /// Returns the sorting keywords in their declaration order.
    ///
    /// - Returns: The keywords sorted by their numeric indices.
    @inlinable
    public func sorted() -> [SekaiSorter.Keyword] {
        self.sorted { $0.rawValue < $1.rawValue }
    }
}

extension Card: SekaiSortable {
    /// The sorting keywords supported by this content type.
    public static var applicableSortingTypes: [SekaiSorter.Keyword] {
        [.releaseDate(in: .jp), .releaseDate(in: .en), .releaseDate(in: .tw), .releaseDate(in: .cn), .releaseDate(in: .kr), .rarity, .maximumStat, .id]
    }
    
    /// A Boolean value indicating whether date sorting should be labeled as an event start date.
    public static var hasEndingDate: Bool { false }
    
    /// Compares two values using a SekaiKit sorter.
    ///
    /// - Parameters:
    ///   - sorter: The sorter defining the comparison.
    ///   - lhs: The first value.
    ///   - rhs: The second value.
    /// - Returns: Whether `lhs` precedes `rhs`, or `nil` if the comparison is unsupported.
    public static func _compare<ValueType>(usingSekaiSorter sorter: SekaiSorter, lhs: ValueType, rhs: ValueType) -> Bool? {
        guard let castedLHS = lhs as? Card, let castedRHS = rhs as? Card else { return nil }
        switch sorter.keyword {
        case .releaseDate(let locale):
            return sorter.strictCompare(
                castedLHS.releaseDate.localizedData?.forLocale(locale)?.corrected(),
                castedRHS.releaseDate.localizedData?.forLocale(locale)?.corrected()
            ) ?? sorter.compare(castedLHS.id, castedRHS.id)
        case .rarity:
            return sorter.compare(castedLHS.rarity.integer ?? 0, castedRHS.rarity.integer ?? 0)
        case .maximumStat:
            return sorter.compare(castedLHS.maxPower, castedRHS.maxPower)
        case .id:
            return sorter.compare(castedLHS.id, castedRHS.id)
        default:
            return nil
        }
    }
}



// MARK: extension PreviewEvent
extension Event: SekaiSortable {
    /// The sorting keywords supported by this content type.
    @inlinable
    public static var applicableSortingTypes: [SekaiSorter.Keyword] {
        [.releaseDate(in: .jp), .releaseDate(in: .en), .releaseDate(in: .tw), .releaseDate(in: .cn), .releaseDate(in: .kr), .id]
    }
    
    /// A Boolean value indicating whether date sorting should be labeled as an event start date.
    @inlinable
    public static var hasEndingDate: Bool { true }
    
    /// Compares two values using a SekaiKit sorter.
    ///
    /// - Parameters:
    ///   - sorter: The sorter defining the comparison.
    ///   - lhs: The first value.
    ///   - rhs: The second value.
    /// - Returns: Whether `lhs` precedes `rhs`, or `nil` if the comparison is unsupported.
    public static func _compare<ValueType>(usingSekaiSorter sorter: SekaiSorter, lhs: ValueType, rhs: ValueType) -> Bool? {
        guard let castedLHS = lhs as? Event, let castedRHS = rhs as? Event else { return nil }
        switch sorter.keyword {
        case .releaseDate(let locale):
            return sorter.strictCompare(
                castedLHS.startDate.localizedData?.forLocale(locale)?.corrected(),
                castedRHS.startDate.localizedData?.forLocale(locale)?.corrected()
            ) ?? sorter.compare(castedLHS.id, castedRHS.id)
        case .id:
            return sorter.compare(castedLHS.id, castedRHS.id)
        default:
            return nil
        }
    }
}

//// MARK: extension PreviewGacha
//extension DoriAPI.Gachas.PreviewGacha: DoriFrontend.Sortable {
//    @inlinable
//    public static var applicableSortingTypes: [DoriFrontend.Sorter.Keyword] {
//        [.releaseDate(in: .jp), .releaseDate(in: .en), .releaseDate(in: .tw), .releaseDate(in: .cn), .releaseDate(in: .kr), .id]
//    }
//    
//    @inlinable
//    public static var hasEndingDate: Bool { true }
//    
//    public static func _compare<ValueType>(usingDoriSorter sorter: DoriFrontend.Sorter, lhs: ValueType, rhs: ValueType) -> Bool? {
//        guard let castedLHS = lhs as? DoriAPI.Gachas.PreviewGacha, let castedRHS = rhs as? DoriAPI.Gachas.PreviewGacha else { return nil }
//        switch sorter.keyword {
//        case .releaseDate(let locale):
//            return sorter.strictCompare(
//                castedLHS.publishedAt.forLocale(locale)?.corrected(),
//                castedRHS.publishedAt.forLocale(locale)?.corrected()
//            ) ?? sorter.compare(castedLHS.id, castedRHS.id)
//        case .id:
//            return sorter.compare(castedLHS.id, castedRHS.id)
//        default:
//            return nil
//        }
//    }
//}
//
//// MARK: extension CardWithBand
//extension DoriFrontend.Cards.CardWithBand: DoriFrontend.Sortable {
//    @inlinable
//    public static var applicableSortingTypes: [DoriFrontend.Sorter.Keyword] {
//        [.releaseDate(in: .jp), .releaseDate(in: .en), .releaseDate(in: .tw), .releaseDate(in: .cn), .releaseDate(in: .kr), .rarity, .maximumStat, .id]
//    }
//    
//    @inlinable
//    public static var hasEndingDate: Bool { false }
//    
//    public static func _compare<ValueType>(usingDoriSorter sorter: DoriFrontend.Sorter, lhs: ValueType, rhs: ValueType) -> Bool? {
//        guard let castedLHS = lhs as? DoriFrontend.Cards.CardWithBand, let castedRHS = rhs as? DoriFrontend.Cards.CardWithBand else { return nil }
//        switch sorter.keyword {
//        case .releaseDate(let locale):
//            return sorter.strictCompare(
//                castedLHS.card.releasedAt.forLocale(locale)?.corrected(),
//                castedRHS.card.releasedAt.forLocale(locale)?.corrected()
//            ) ?? sorter.compare(castedLHS.id, castedRHS.id)
//        case .rarity:
//            return sorter.compare(castedLHS.card.rarity, castedRHS.card.rarity)
//        case .maximumStat:
//            return sorter.compare(castedLHS.card.stat.maximumLevel, castedRHS.card.stat.maximumLevel)
//        case .id:
//            return sorter.compare(castedLHS.id, castedRHS.id)
//        default:
//            return nil
//        }
//    }
//}
//
//// MARK: extension PreviewCard
//extension DoriFrontend.Cards.PreviewCard: DoriFrontend.Sortable {
//    @inlinable
//    public static var applicableSortingTypes: [DoriFrontend.Sorter.Keyword] {
//        [.releaseDate(in: .jp), .releaseDate(in: .en), .releaseDate(in: .tw), .releaseDate(in: .cn), .releaseDate(in: .kr), .rarity, .maximumStat, .id]
//    }
//    
//    @inlinable
//    public static var hasEndingDate: Bool { false }
//    
//    public static func _compare<ValueType>(usingDoriSorter sorter: DoriFrontend.Sorter, lhs: ValueType, rhs: ValueType) -> Bool? {
//        guard let castedLHS = lhs as? DoriFrontend.Cards.PreviewCard, let castedRHS = rhs as? DoriFrontend.Cards.PreviewCard else { return nil }
//        switch sorter.keyword {
//        case .releaseDate(let locale):
//            return sorter.strictCompare(
//                castedLHS.releasedAt.forLocale(locale)?.corrected(),
//                castedRHS.releasedAt.forLocale(locale)?.corrected()
//            ) ?? sorter.compare(castedLHS.id, castedRHS.id)
//        case .rarity:
//            return sorter.compare(castedLHS.rarity, castedRHS.rarity)
//        case .maximumStat:
//            return sorter.compare(castedLHS.stat.maximumLevel, castedRHS.stat.maximumLevel)
//        case .id:
//            return sorter.compare(castedLHS.id, castedRHS.id)
//        default:
//            return nil
//        }
//    }
//}
//
//// MARK: extension PreviewSong
extension Song: SekaiSortable {
    /// The sorting keywords supported by this content type.
    @inlinable
    public static var applicableSortingTypes: [SekaiSorter.Keyword] {
        [.releaseDate(in: .jp), .releaseDate(in: .en), .releaseDate(in: .tw), .releaseDate(in: .cn), .releaseDate(in: .kr), .level(for: .easy), .level(for: .normal), .level(for: .hard), .level(for: .master), .level(for: .expert), .level(for: .append), .id]
    }
    
    /// A Boolean value indicating whether date sorting should be labeled as an event start date.
    @inlinable
    public static var hasEndingDate: Bool { false }
    
    /// Compares two values using a SekaiKit sorter.
    ///
    /// - Parameters:
    ///   - sorter: The sorter defining the comparison.
    ///   - lhs: The first value.
    ///   - rhs: The second value.
    /// - Returns: Whether `lhs` precedes `rhs`, or `nil` if the comparison is unsupported.
    public static func _compare<ValueType>(usingSekaiSorter sorter: SekaiSorter, lhs: ValueType, rhs: ValueType) -> Bool? {
        guard let castedLHS = lhs as? Song, let castedRHS = rhs as? Song else { return nil }
        switch sorter.keyword {
        case .releaseDate(let locale):
            return sorter.strictCompare(
                castedLHS.publishDate.localizedData?.forLocale(locale)?.corrected(),
                castedRHS.publishDate.localizedData?.forLocale(locale)?.corrected()
            ) ?? sorter.compare(castedLHS.id, castedRHS.id)
        case .level(let difficulty):
            return sorter.compare(castedLHS.difficultyLevel[difficulty], castedRHS.difficultyLevel[difficulty])
        case .id:
            return sorter.compare(castedLHS.id, castedRHS.id)
        default:
            return nil
        }
    }
}
//
//// MARK: extension PreviewCampaign
//extension DoriAPI.LoginCampaigns.PreviewCampaign: DoriFrontend.Sortable {
//    @inlinable
//    public static var applicableSortingTypes: [DoriFrontend.Sorter.Keyword] {
//        [.releaseDate(in: .jp), .releaseDate(in: .en), .releaseDate(in: .tw), .releaseDate(in: .cn), .releaseDate(in: .kr), .id]
//    }
//    
//    @inlinable
//    public static var hasEndingDate: Bool { true }
//    
//    public static func _compare<ValueType>(usingDoriSorter sorter: DoriFrontend.Sorter, lhs: ValueType, rhs: ValueType) -> Bool? {
//        guard let castedLHS = lhs as? DoriAPI.LoginCampaigns.PreviewCampaign, let castedRHS = rhs as? DoriAPI.LoginCampaigns.PreviewCampaign else { return nil }
//        switch sorter.keyword {
//        case .releaseDate(let locale):
//            return sorter.strictCompare(
//                castedLHS.publishedAt.forLocale(locale)?.corrected(),
//                castedRHS.publishedAt.forLocale(locale)?.corrected()
//            ) ?? sorter.compare(castedLHS.id, castedRHS.id)
//        case .id:
//            return sorter.compare(castedLHS.id, castedRHS.id)
//        default:
//            return nil
//        }
//    }
//}
//
//// MARK: extension Comic
//extension DoriAPI.Comics.Comic: DoriFrontend.Sortable {
//    @inlinable
//    public static var applicableSortingTypes: [DoriFrontend.Sorter.Keyword] {
//        [.id]
//    }
//    
//    @inlinable
//    public static var hasEndingDate: Bool { false }
//    
//    public static func _compare<ValueType>(usingDoriSorter sorter: DoriFrontend.Sorter, lhs: ValueType, rhs: ValueType) -> Bool? {
//        guard let castedLHS = lhs as? DoriAPI.Comics.Comic, let castedRHS = rhs as? DoriAPI.Comics.Comic else { return nil }
//        switch sorter.keyword {
//            //        case .releaseDate(let locale):
//            //            return sorter.compare(
//            //                castedLHS.publicStartAt.forLocale(locale),
//            //                castedRHS.publicStartAt.forLocale(locale)
//            //            )
//        case .id:
//            return sorter.compare(castedLHS.id, castedRHS.id)
//        default:
//            return nil
//        }
//    }
//}
//
//
//// MARK: extension PreviewCostume
//extension DoriFrontend.Costumes.PreviewCostume: DoriFrontend.Sortable {
//    @inlinable
//    public static var applicableSortingTypes: [DoriFrontend.Sorter.Keyword] {
//        [.releaseDate(in: .jp), .releaseDate(in: .en), .releaseDate(in: .tw), .releaseDate(in: .cn), .releaseDate(in: .kr), .id]
//    }
//    
//    @inlinable
//    public static var hasEndingDate: Bool { false }
//    
//    public static func _compare<ValueType>(usingDoriSorter sorter: DoriFrontend.Sorter, lhs: ValueType, rhs: ValueType) -> Bool? {
//        guard let castedLHS = lhs as? DoriFrontend.Costumes.PreviewCostume, let castedRHS = rhs as? DoriFrontend.Costumes.PreviewCostume else { return nil }
//        switch sorter.keyword {
//        case .releaseDate(let locale):
//            return sorter.strictCompare(
//                castedLHS.publishedAt.forLocale(locale)?.corrected(),
//                castedRHS.publishedAt.forLocale(locale)?.corrected()
//            ) ?? sorter.compare(castedLHS.id, castedRHS.id)
//        case .id:
//            return sorter.compare(castedLHS.id, castedRHS.id)
//        default:
//            return nil
//        }
//    }
//}
//
//// MARK: extension PreviewCharacter
//extension DoriFrontend.Characters.PreviewCharacter: DoriFrontend.Sortable {
//    @inlinable
//    public static var applicableSortingTypes: [DoriFrontend.Sorter.Keyword] {
//        [.id]
//    }
//    
//    @inlinable
//    public static var hasEndingDate: Bool { false }
//    
//    public static func _compare<ValueType>(usingDoriSorter sorter: DoriFrontend.Sorter, lhs: ValueType, rhs: ValueType) -> Bool? {
//        guard let castedLHS = lhs as? DoriFrontend.Characters.PreviewCharacter, let castedRHS = rhs as? DoriFrontend.Characters.PreviewCharacter else { return nil }
//        switch sorter.keyword {
//        case .id:
//            return sorter.compare(castedLHS.id, castedRHS.id)
//        default:
//            return nil
//        }
//    }
//}

// MARK: extension Array
extension Array where Element: SekaiSortable {
    /// Returns the elements ordered by a SekaiKit sorter.
    ///
    /// - Parameter sorter: The sorting keyword and direction to apply.
    /// - Returns: A sorted copy of the array.
    public func sorted(withSekaiSorter sorter: SekaiSorter) -> [Element] {
        var result: [Element] = self
        result = result.sorted {
            Element._compare(usingSekaiSorter: sorter, lhs: $0, rhs: $1) ?? false
        }
        return result
    }
    
    /// Orders the array in place using a SekaiKit sorter.
    ///
    /// - Parameter sorter: The sorting keyword and direction to apply.
    @inline(__always)
    public mutating func sort(withSekaiSorter sorter: SekaiSorter) {
        self = self.sorted(withSekaiSorter: sorter)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
