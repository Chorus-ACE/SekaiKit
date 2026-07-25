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

public protocol SekaiSortable {
    static var applicableSortingTypes: [SekaiSorter.Keyword] { get }
    
    static var hasEndingDate: Bool { get }
    
    static func _compare<ValueType>(usingSekaiSorter: SekaiSorter, lhs: ValueType, rhs: ValueType) -> Bool?
}

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
    
    /// Create a sorter which can restore to its latest selections across sessions.
    /// - Parameter id: An identifier for restoration.
    /// - Returns: A sorter which stores its selections automaticlly and can be restore by provided ID.
    public static func recoverable(id: String) -> Self {
        let storageURL = URL(filePath: NSHomeDirectory() + "/Documents/DoriKit_Sorter_Status.plist")
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
    
    /// A string identity of the sorter.
    ///
    /// This allows you to identify whether two sorters have the same effect,
    /// which is useful when working with ``SekaiCache``.
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
    
    /// Represents direction of a sorter.
    @frozen
    public enum Direction: String, Equatable, Hashable, Codable {
        case ascending = "ascending"
        case descending = "descending"
        
        /// The reversed direction of current.
        @inlinable
        public var reversed: Self {
            switch self {
            case .ascending: .descending
            case .descending: .ascending
            }
        }
        
        /// Reverse the direction.
        @inlinable
        public mutating func reverse() {
            self = self.reversed
        }
    }
    /// Represents keyword of a sorter.
    public enum Keyword: CaseIterable, Sendable, Equatable, Hashable, Codable {
        case releaseDate(in: SekaiLocale)
        case difficultyReleaseDate(in: SekaiLocale)
        case mvReleaseDate(in: SekaiLocale)
//        case level(for: Songs.DifficultyType)
        case rarity
        case maximumStat
        case id
        
        public static let allCases: [Self] = [
            .releaseDate(in: .jp),
            .releaseDate(in: .en),
            .releaseDate(in: .tw),
            .releaseDate(in: .cn),
            .releaseDate(in: .kr),
            .difficultyReleaseDate(in: .jp),
            .difficultyReleaseDate(in: .en),
            .difficultyReleaseDate(in: .tw),
            .difficultyReleaseDate(in: .cn),
            .difficultyReleaseDate(in: .kr),
            .mvReleaseDate(in: .jp),
            .mvReleaseDate(in: .en),
            .mvReleaseDate(in: .tw),
            .mvReleaseDate(in: .cn),
            .mvReleaseDate(in: .kr),
//            .level(for: .easy),
//            .level(for: .normal),
//            .level(for: .hard),
//            .level(for: .expert),
//            .level(for: .special),
            .rarity,
            .maximumStat,
            .id
        ]
        
        public var rawValue: Int {
            return Self.allCases.firstIndex(where: { $0 == self })!
        }
        
        /// Localized description text for keyword.
        @inline(never)
        public var localizedString: String {
            switch self {
            case .releaseDate(let locale):
                String(localized: "FILTER_SORT_KEYWORD_RELEASE_DATE_IN_\(locale.rawValue.uppercased())", bundle: #bundle)
            case .difficultyReleaseDate(let locale):
                String(localized: "FILTER_SORT_KEYWORD_DIFFICULTY_RELEASE_DATE_IN_\(locale.rawValue.uppercased())", bundle: #bundle)
            case .mvReleaseDate(in: let locale):
                String(localized: "FILTER_SORT_KEYWORD_MV_RELEASE_DATE_IN_\(locale.rawValue.uppercased())", bundle: #bundle)
//            case .level(let difficultyLevel):
//                String(localized: "FILTER_SORT_KEYWORD_LEVEL_FOR_\(difficultyLevel.rawStringValue.uppercased())", bundle: #bundle)
            case .rarity: String(localized: "FILTER_SORT_KEYWORD_RARITY", bundle: #bundle)
            case .maximumStat: String(localized: "FILTER_SORT_KEYWORD_MAXIMUM_STAT", bundle: #bundle)
            case .id: String(localized: "FILTER_SORT_KEYWORD_ID", bundle: #bundle)
            }
        }
        
        /// Localized description text for keyword.
        /// - Parameter hasEndingDate: A boolean value that indicates
        ///     whether the type has an ending date
        ///     (i.e. can be *removed*, *stopped*, or etc.)
        /// - Returns: A localized description text for keyword.
        public func localizedString(hasEndingDate: Bool = false) -> String {
            switch self {
            case .releaseDate(let locale):
                hasEndingDate ? String(localized: "FILTER_SORT_KEYWORD_START_DATE_IN_\(locale.rawValue.uppercased())", bundle: #bundle) : String(localized: "FILTER_SORT_KEYWORD_RELEASE_DATE_IN_\(locale.rawValue.uppercased())", bundle: #bundle)
            case .difficultyReleaseDate(let locale):
                String(localized: "FILTER_SORT_KEYWORD_DIFFICULTY_RELEASE_DATE_IN_\(locale.rawValue.uppercased())", bundle: #bundle)
            case .mvReleaseDate(let locale):
                String(localized: "FILTER_SORT_KEYWORD_MV_RELEASE_DATE_IN_\(locale.rawValue.uppercased())", bundle: #bundle)
//            case .level(let difficultyLevel):
//                String(localized: "FILTER_SORT_KEYWORD_LEVEL_FOR_\(difficultyLevel.rawStringValue.uppercased())", bundle: #bundle)
            case .rarity: String(localized: "FILTER_SORT_KEYWORD_RARITY", bundle: #bundle)
            case .maximumStat: String(localized: "FILTER_SORT_KEYWORD_MAXIMUM_STAT", bundle: #bundle)
            case .id: String(localized: "FILTER_SORT_KEYWORD_ID", bundle: #bundle)
            }
        }
    }
    
    /// Returns a localized name of given direction with keyword.
    /// - Parameters:
    ///   - keyword: The keyword for direction, nil to use the current one.
    ///   - direction: The direction, nil to use the current one.
    /// - Returns: A localized name of given direction with keyword.
    public func localizedDirectionName(keyword: Keyword? = nil, direction: Direction? = nil) -> String {
        let isAscending: Bool = (direction ?? self.direction) == .ascending
        switch keyword ?? self.keyword {
        case .releaseDate:
            return isAscending ? String(localized: "FILTER_SORT_ORDER_OLDEST_TO_NEWEST", bundle: #bundle) : String(localized: "FILTER_SORT_ORDER_NEWEST_TO_OLDEST", bundle: #bundle)
        case .difficultyReleaseDate:
            return isAscending ? String(localized: "FILTER_SORT_ORDER_OLDEST_TO_NEWEST", bundle: #bundle) : String(localized: "FILTER_SORT_ORDER_NEWEST_TO_OLDEST", bundle: #bundle)
        case .mvReleaseDate:
            return isAscending ? String(localized: "FILTER_SORT_ORDER_OLDEST_TO_NEWEST", bundle: #bundle) : String(localized: "FILTER_SORT_ORDER_NEWEST_TO_OLDEST", bundle: #bundle)
//        case .level:
//            return isAscending ? String(localized: "FILTER_SORT_ORDER_ASCENDING", bundle: #bundle) : String(localized: "FILTER_SORT_ORDER_DESCENDING", bundle: #bundle)
        case .rarity:
            return isAscending ? String(localized: "FILTER_SORT_ORDER_ASCENDING", bundle: #bundle) : String(localized: "FILTER_SORT_ORDER_DESCENDING", bundle: #bundle)
        case .maximumStat:
            return isAscending ? String(localized: "FILTER_SORT_ORDER_ASCENDING", bundle: #bundle) : String(localized: "FILTER_SORT_ORDER_DESCENDING", bundle: #bundle)
        case .id:
            return isAscending ? String(localized: "FILTER_SORT_ORDER_ASCENDING", bundle: #bundle) : String(localized: "FILTER_SORT_ORDER_DESCENDING", bundle: #bundle)
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
    @inlinable
    public func sorted() -> [SekaiSorter.Keyword] {
        self.sorted { $0.rawValue < $1.rawValue }
    }
}
//
//// MARK: extension PreviewEvent
//extension SekaiEvents.PreviewEvent: DoriFrontend.Sortable {
//    @inlinable
//    public static var applicableSortingTypes: [DoriFrontend.Sorter.Keyword] {
//        [.releaseDate(in: .jp), .releaseDate(in: .en), .releaseDate(in: .tw), .releaseDate(in: .cn), .releaseDate(in: .kr), .id]
//    }
//    
//    @inlinable
//    public static var hasEndingDate: Bool { true }
//    
//    public static func _compare<ValueType>(usingDoriSorter sorter: DoriFrontend.Sorter, lhs: ValueType, rhs: ValueType) -> Bool? {
//        guard let castedLHS = lhs as? DoriAPI.Events.PreviewEvent, let castedRHS = rhs as? DoriAPI.Events.PreviewEvent else { return nil }
//        switch sorter.keyword {
//        case .releaseDate(let locale):
//            return sorter.strictCompare(
//                castedLHS.startAt.forLocale(locale)?.corrected(),
//                castedRHS.startAt.forLocale(locale)?.corrected()
//            ) ?? sorter.compare(castedLHS.id, castedRHS.id)
//        case .id:
//            return sorter.compare(castedLHS.id, castedRHS.id)
//        default:
//            return nil
//        }
//    }
//}
//
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
//extension DoriAPI.Songs.PreviewSong: DoriFrontend.Sortable {
//    @inlinable
//    public static var applicableSortingTypes: [DoriFrontend.Sorter.Keyword] {
//        [.releaseDate(in: .jp), .releaseDate(in: .en), .releaseDate(in: .tw), .releaseDate(in: .cn), .releaseDate(in: .kr), .difficultyReleaseDate(in: .jp), .difficultyReleaseDate(in: .en), .difficultyReleaseDate(in: .tw), .difficultyReleaseDate(in: .cn), .difficultyReleaseDate(in: .kr), .mvReleaseDate(in: .jp), .mvReleaseDate(in: .en), .mvReleaseDate(in: .tw), .mvReleaseDate(in: .cn), .mvReleaseDate(in: .kr), .level(for: .easy), .level(for: .normal), .level(for: .hard), .level(for: .expert), .level(for: .special), .id]
//    }
//    
//    @inlinable
//    public static var hasEndingDate: Bool { false }
//    
//    public static func _compare<ValueType>(usingDoriSorter sorter: DoriFrontend.Sorter, lhs: ValueType, rhs: ValueType) -> Bool? {
//        guard let castedLHS = lhs as? DoriAPI.Songs.PreviewSong, let castedRHS = rhs as? DoriAPI.Songs.PreviewSong else { return nil }
//        switch sorter.keyword {
//        case .releaseDate(let locale):
//            return sorter.strictCompare(
//                castedLHS.publishedAt.forLocale(locale)?.corrected(),
//                castedRHS.publishedAt.forLocale(locale)?.corrected()
//            ) ?? sorter.compare(castedLHS.id, castedRHS.id)
//        case .difficultyReleaseDate(let locale):
//            return sorter.compare(
//                castedLHS.difficulty[.special]?.publishedAt?.forLocale(locale)?.corrected(),
//                castedRHS.difficulty[.special]?.publishedAt?.forLocale(locale)?.corrected()
//            )
//        case .mvReleaseDate(let locale):
//            var finalReleaseDateForLHS: Date?
//            var finalReleaseDateForRHS: Date?
//            if let allMVDictForLHS = castedLHS.musicVideos {
//                let mvListForLHS = Array(allMVDictForLHS.values)
//                let mvDatesForLHS = mvListForLHS.compactMap{ $0.startAt.forLocale(locale) }.sorted(by: <)
//                finalReleaseDateForLHS = mvDatesForLHS.first
//            } else {
//                finalReleaseDateForLHS = nil
//            }
//            if let allMVDictForRHS = castedRHS.musicVideos {
//                let mvListForRHS = Array(allMVDictForRHS.values)
//                let mvDatesForRHS = mvListForRHS.compactMap{ $0.startAt.forLocale(locale) }.sorted(by: <)
//                finalReleaseDateForRHS = mvDatesForRHS.first
//            } else {
//                finalReleaseDateForRHS = nil
//            }
//            return sorter.compare(finalReleaseDateForLHS?.corrected(), finalReleaseDateForRHS?.corrected())
//        case .level(let difficulty):
//            return sorter.compare(castedLHS.difficulty[difficulty]?.playLevel, castedRHS.difficulty[difficulty]?.playLevel)
//        case .id:
//            return sorter.compare(castedLHS.id, castedRHS.id)
//        default:
//            return nil
//        }
//    }
//}
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
    public func sorted(withSekaiSorter sorter: SekaiSorter) -> [Element] {
        var result: [Element] = self
        result = result.sorted {
            Element._compare(usingSekaiSorter: sorter, lhs: $0, rhs: $1) ?? false
        }
        return result
    }
    
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
