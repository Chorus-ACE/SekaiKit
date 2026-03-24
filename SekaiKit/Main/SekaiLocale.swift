//
//  SekaiKit.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/1/16.
//

import Foundation

@frozen
public enum SekaiLocale: String, CaseIterable, Codable, SekaiCache.Cacheable {
    case jp
    case en
    case tw
    case cn
    case kr
}

extension SekaiLocale {
    @usableFromInline
    @safe
    nonisolated(unsafe)
    internal static var _primaryLocale = SekaiLocale(rawValue: UserDefaults.standard.string(forKey: "_SekaiKit_SekaiAPIPreferredLocale") ?? "jp") ?? .jp
    
    /// The preferred locale.
    @inlinable
    public static var primaryLocale: SekaiLocale {
        get {
            _primaryLocale
        }
        set {
            _primaryLocale = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: "_SekaiKit_SekaiAPIPreferredLocale")
        }
    }
    @usableFromInline
    @safe
    nonisolated(unsafe)
    internal static var _secondaryLocale = SekaiLocale(rawValue: UserDefaults.standard.string(forKey: "_SekaiKit_SekaiAPISecondaryLocale") ?? "en") ?? .en
    /// The secondary preferred locale.
    @inlinable
    public static var secondaryLocale: SekaiLocale {
        get {
            _secondaryLocale
        }
        set {
            _secondaryLocale = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: "_SekaiKit_SekaiAPISecondaryLocale")
        }
    }
}

extension SekaiLocale {
    @usableFromInline
    internal init?(rawIntValue value: Int) {
        switch value {
        case 0: self = .jp
        case 1: self = .en
        case 2: self = .tw
        case 3: self = .cn
        case 4: self = .kr
        default: return nil
        }
    }
    
    internal var rawIntValue: Int {
        switch self {
        case .jp: return 0
        case .en: return 1
        case .tw: return 2
        case .cn: return 3
        case .kr: return 4
        }
    }
    
    public var nsLocale: Locale {
        switch self {
        case .jp: return Locale(identifier: "ja")
        case .en: return Locale(identifier: "en")
        case .tw: return Locale(identifier: "zh-Hant")
        case .cn: return Locale(identifier: "zh-Hans")
        case .kr: return Locale(identifier: "ko")
        }
    }
    
    public var _databasePath: String {
        switch self {
        case .jp: return "sekai-master-db-diff"
        case .en: return "sekai-master-db-en-diff"
        case .tw: return "sekai-master-db-tc-diff"
        case .cn: return "sekai-master-db-cn-diff"
        case .kr: return "sekai-master-db-kr-diff"
        }
    }
    
    public var _assetsPath: String {
        switch self {
        case .jp: return "sekai-jp-assets"
        case .en: return "sekai-en-assets"
        case .tw: return "sekai-tc-assets"
        case .cn: return "sekai-cn-assets"
        case .kr: return "sekai-kr-assets"
        }
    }
}

extension SekaiLocale: Comparable {
    public static func < (lhs: borrowing SekaiLocale, rhs: borrowing SekaiLocale) -> Bool {
        lhs.rawIntValue < rhs.rawIntValue
    }
}

@_eagerMove
public struct LocalizedData<T>: _DestructorSafeContainer {
    public var jp: T?
    public var en: T?
    public var tw: T?
    public var cn: T?
    public var kr: T?
    
    @usableFromInline
    internal init(jp: T?, en: T?, tw: T?, cn: T?, kr: T?) {
        self.jp = jp
        self.en = en
        self.tw = tw
        self.cn = cn
        self.kr = kr
    }
    
    @inlinable
    public init(builder: (SekaiLocale) -> T?) {
        self.init(
            jp: builder(.jp),
            en: builder(.en),
            tw: builder(.tw),
            cn: builder(.cn),
            kr: builder(.kr)
        )
    }
    
    @inlinable
    public init(
        repeating item: T?,
        forLocale locales: Set<SekaiLocale> = .init(SekaiLocale.allCases)
    ) {
        if _fastPath(locales.count == 5) {
            self.init(jp: item, en: item, tw: item, cn: item, kr: item)
        } else {
            self.init {
                locales.contains($0) ? item : nil
            }
        }
    }
    
    @inlinable
    public init(
        _jp: T? = nil,
        en: T? = nil,
        tw: T? = nil,
        cn: T? = nil,
        kr: T? = nil
    ) {
        self.init(jp: _jp, en: en, tw: tw, cn: cn, kr: kr)
    }
    
    /// Get localized data for locale.
    /// - Parameter locale: required locale for data.
    /// - Returns: localized data, nil if not available.
    @inlinable
    public func forLocale(_ locale: SekaiLocale) -> T? {
        switch locale {
        case .jp: self.jp
        case .en: self.en
        case .tw: self.tw
        case .cn: self.cn
        case .kr: self.kr
        }
    }
    /// Check if the data available in specific locale.
    /// - Parameter locale: the locale to check.
    /// - Returns: if the data available.
    @inlinable
    public func availableInLocale(_ locale: SekaiLocale) -> Bool {
        forLocale(locale) != nil
    }
    /// Get localized data for preferred locale.
    /// - Parameter allowsFallback: Whether to allow fallback to other locales
    /// if data isn't available in preferred locale.
    /// - Returns: localized data for preferred locale, nil if not available.
    public func forPreferredLocale(allowsFallback: Bool = true) -> T? {
        forLocale(SekaiLocale.primaryLocale) ?? (allowsFallback ? (forLocale(.jp) ?? forLocale(.en) ?? forLocale(.tw) ?? forLocale(.cn) ?? forLocale(.kr) ?? logger.warning("Failed to lookup any candidate of \(T.self) for preferred locale", evaluate: nil)) : nil)
    }
    /// Get localized data for secondary locale.
    /// - Parameter allowsFallback: Whether to allow fallback to other locales
    /// if data isn't available in secondary locale.
    /// - Returns: localized data for secondary locale, nil if not available.
    public func forSecondaryLocale(allowsFallback: Bool = true) -> T? {
        forLocale(SekaiLocale.secondaryLocale) ?? (allowsFallback ? (forLocale(.jp) ?? forLocale(.en) ?? forLocale(.tw) ?? forLocale(.cn) ?? forLocale(.kr) ?? logger.warning("Failed to lookup any candidate of \(T.self) for secondary locale", evaluate: nil)) : nil)
    }
    /// Check if the data available in preferred locale.
    /// - Returns: if the data available.
    @inlinable
    public func availableInPreferredLocale() -> Bool {
        forPreferredLocale(allowsFallback: false) != nil
    }
    /// Check if the data available in secondary locale.
    /// - Returns: if the data available.
    @inlinable
    public func availableInSecondaryLocale() -> Bool {
        forSecondaryLocale(allowsFallback: false) != nil
    }
    /// Check if the available locale of data.
    ///
    /// This function checks if data available in preferred locale first,
    /// if not provided or not available, it checks from jp to kr respectively.
    ///
    /// - Parameter locale: preferred first locale.
    /// - Returns: first available locale of data, nil if none.
    @inlinable
    public func availableLocale(prefer locale: SekaiLocale? = nil) -> SekaiLocale? {
        if availableInLocale(locale ?? .primaryLocale) {
            return locale ?? .primaryLocale
        }
        for locale in SekaiLocale.allCases where availableInLocale(locale) {
            return locale
        }
        return nil
    }
    
    @inlinable
    public mutating func updateValue(_ newValue: T?, forLocale locale: SekaiLocale) {
        switch locale {
        case .jp: self.jp = newValue
        case .en: self.en = newValue
        case .tw: self.tw = newValue
        case .cn: self.cn = newValue
        case .kr: self.kr = newValue
        }
    }
    
    @inlinable
    public subscript(_ locale: SekaiLocale) -> T? {
        @inline(__always)
        get { forLocale(locale) }
        
        _modify {
            switch locale {
            case .jp: yield &jp
            case .en: yield &en
            case .tw: yield &tw
            case .cn: yield &cn
            case .kr: yield &kr
            }
        }
    }
    
    public var allAvailableLocales: [SekaiLocale] {
        let expectedLocales = [SekaiLocale.primaryLocale, SekaiLocale.secondaryLocale] + SekaiLocale.allCases.drop(while: { $0 == .primaryLocale || $0 == .secondaryLocale })
        
        var availableLocales: [SekaiLocale] = []
        for locale in SekaiLocale.allCases where self.availableInLocale(locale) {
            availableLocales.append(locale)
        }
        
        return expectedLocales.filter({ availableLocales.contains($0) })
    }
    
    public var allUnavailableLocales: [SekaiLocale] {
        let availableLocales = self.allAvailableLocales
        return SekaiLocale.allCases.filter({ !availableLocales.contains($0) })
    }
    
    public var dictionarized: [SekaiLocale: T] {
        return [.jp: self.jp, .en: self.en, .tw: self.tw, .cn: self.cn, .tw: self.tw].compactMapValues({ $0 })
    }
}


extension LocalizedData: Sendable where T: Sendable {}
extension LocalizedData: Equatable where T: Equatable {}
extension LocalizedData: Hashable where T: Hashable {}
extension LocalizedData: SekaiCache.Cacheable, Codable where T: SekaiCache.Cacheable {}

extension LocalizedData {
    /// Returns localized data containing the results of mapping the given closure
    /// over each locales.
    ///
    /// - Parameter transform: A mapping closure. `transform` accepts an
    ///   element of this localized data as its parameter and returns a transformed
    ///   value of the same or of a different type.
    /// - Returns: Localized data containing the transformed elements of this
    ///   sequence.
    @inlinable
    public func map<R, E>(_ transform: (T?) throws(E) -> R?) throws(E) -> LocalizedData<R> {
        var result = LocalizedData<R>(jp: nil, en: nil, tw: nil, cn: nil, kr: nil)
        for locale in SekaiLocale.allCases {
            result.updateValue(try transform(self.forLocale(locale)), forLocale: locale)
        }
        return result
    }
    
    /// Returns an array containing the non-`nil` results of calling the given
    /// transformation with each element of this localized data.
    ///
    /// Use this method to receive an array of non-optional values when your
    /// transformation produces an optional value.
    ///
    /// - Parameter transform: A closure that accepts an element of this
    ///   localized data as its argument and returns an optional value.
    /// - Returns: An array of the non-`nil` results of calling `transform`
    ///   with each element of the sequence.
    ///
    /// - Complexity: O(*n*), where *n* is the length of this sequence.
    @inlinable
    public func compactMap<ElementOfResult>(
        _ transform: (T?) throws -> ElementOfResult?
    ) rethrows -> [ElementOfResult] {
        return try _compactMap(transform)
    }
    
    // The implementation of compactMap accepting a closure with an optional result.
    // Factored out into a separate function in order to be used in multiple
    // overloads.
    @inlinable
    @inline(__always)
    public func _compactMap<ElementOfResult>(
        _ transform: (T?) throws -> ElementOfResult?
    ) rethrows -> [ElementOfResult] {
        var result: [ElementOfResult] = []
        for locale in SekaiLocale.allCases {
            if let newElement = try transform(self.forLocale(locale)) {
                result.append(newElement)
            }
        }
        return result
    }
    
    @inlinable
    public func enumerated() -> [(locale: SekaiLocale, element: T?)] {
        compactMap { $0 }.enumerated().map { (.init(rawIntValue: $0.offset)!, $0.element) }
    }

    @inlinable
    public var isEmpty: Bool {
        self.jp == nil && self.en == nil && self.tw == nil && self.cn == nil && self.kr == nil
    }
    
    @inlinable
    public func contains(where method: (T?) -> Bool) -> Bool {
        for locale in SekaiLocale.allCases {
            if method(self.forLocale(locale)) {
                return true
            }
        }
        return false
    }
    
    @inlinable
    public func allSatisfy(_ method: (T?) -> Bool) -> Bool {
        for locale in SekaiLocale.allCases {
            if !method(self.forLocale(locale)) {
                return false
            }
        }
        return true
    }
}

extension LocalizedData where T: Collection {
    @inlinable
    public var isValueEmpty: Bool {
        self.jp?.isEmpty != false
        && self.en?.isEmpty != false
        && self.tw?.isEmpty != false
        && self.cn?.isEmpty != false
        && self.kr?.isEmpty != false
    }
}

extension LocalizedData where T: Equatable {
    @inlinable
    public func contains(_ element: T?) -> Bool {
        for locale in SekaiLocale.allCases {
            if self.forLocale(locale) == element {
                return true
            }
        }
        return false
    }
}
