//
//  SekaiKit.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/1/16.
//

import Foundation

/// A supported regional edition of Project Sekai.
@frozen
public enum SekaiLocale: String, CaseIterable, Codable, SekaiCache.Cacheable {
    /// The Japanese edition.
    case jp
    /// The English edition.
    case en
    /// The Traditional Chinese edition.
    case tw
    /// The Simplified Chinese edition.
    case cn
    /// The Korean edition.
    case kr
}

extension SekaiLocale {
    @usableFromInline
    @safe
    nonisolated(unsafe)
    internal static var _primaryLocale = SekaiLocale(rawValue: UserDefaults.standard.string(forKey: "_SekaiKit_SekaiAPIPreferredLocale") ?? "jp") ?? .jp
    
    /// The preferred game locale, persisted in user defaults.
    ///
    /// The default is the Japanese locale.
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
    /// The secondary game locale, persisted in user defaults.
    ///
    /// The default is the English locale.
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
    
    /// The Foundation locale corresponding to this game edition’s language.
    public var nsLocale: Locale {
        switch self {
        case .jp: return Locale(identifier: "ja")
        case .en: return Locale(identifier: "en")
        case .tw: return Locale(identifier: "zh-Hant")
        case .cn: return Locale(identifier: "zh-Hans")
        case .kr: return Locale(identifier: "ko")
        }
    }
    
    /// The repository path component used to request this locale’s master data.
    public var _databasePath: String {
        switch self {
        case .jp: return "sekai-master-db-diff"
        case .en: return "sekai-master-db-en-diff"
        case .tw: return "sekai-master-db-tc-diff"
        case .cn: return "sekai-master-db-cn-diff"
        case .kr: return "sekai-master-db-kr-diff"
        }
    }
    
    /// The storage path component used to request this locale’s assets.
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
    /// Returns whether a locale precedes another in Japanese, English, Traditional Chinese, Simplified Chinese, and Korean order.
    ///
    /// - Parameters:
    ///   - lhs: The first locale.
    ///   - rhs: The second locale.
    /// - Returns: `true` if `lhs` precedes `rhs`.
    public static func < (lhs: borrowing SekaiLocale, rhs: borrowing SekaiLocale) -> Bool {
        lhs.rawIntValue < rhs.rawIntValue
    }
}

/// Optional values stored separately for each supported game locale.
@_eagerMove
public struct LocalizedData<T>: _DestructorSafeContainer {
    /// The value for the Japanese locale, if available.
    public var jp: T?
    /// The value for the English locale, if available.
    public var en: T?
    /// The value for the Traditional Chinese locale, if available.
    public var tw: T?
    /// The value for the Simplified Chinese locale, if available.
    public var cn: T?
    /// The value for the Korean locale, if available.
    public var kr: T?
    
    @usableFromInline
    internal init(jp: T?, en: T?, tw: T?, cn: T?, kr: T?) {
        self.jp = jp
        self.en = en
        self.tw = tw
        self.cn = cn
        self.kr = kr
    }
    
    /// Creates localized storage by invoking a builder once for each locale.
    ///
    /// - Parameter builder: A closure returning the value for a locale, or `nil` if unavailable.
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
    
    /// Creates localized storage by repeating a value for selected locales.
    ///
    /// - Parameters:
    ///   - item: The value to store.
    ///   - locales: The locales to populate; other locales remain absent.
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
    
    /// Creates localized storage from separate optional values.
    ///
    /// - Parameters:
    ///   - _jp: The Japanese value.
    ///   - en: The English value.
    ///   - tw: The Traditional Chinese value.
    ///   - cn: The Simplified Chinese value.
    ///   - kr: The Korean value.
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
    
    /// Returns the value stored for a locale.
    ///
    /// - Parameter locale: The locale to look up.
    /// - Returns: The stored value, or `nil` if unavailable.
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
    /// Returns whether a value is stored for a locale.
    ///
    /// - Parameter locale: The locale to check.
    /// - Returns: `true` if the locale has a non-`nil` value.
    @inlinable
    public func availableInLocale(_ locale: SekaiLocale) -> Bool {
        forLocale(locale) != nil
    }
    /// Returns the value for the primary locale, optionally falling back to another locale.
    ///
    /// - Parameter allowsFallback: Whether to use the first available locale when the primary value is absent.
    /// - Returns: The selected value, or `nil` if no permitted value is available.
    public func forPreferredLocale(allowsFallback: Bool = true) -> T? {
        forLocale(SekaiLocale.primaryLocale) ?? (allowsFallback ? (forLocale(.jp) ?? forLocale(.en) ?? forLocale(.tw) ?? forLocale(.cn) ?? forLocale(.kr) ?? logger.warning("Failed to lookup any candidate of \(T.self) for preferred locale", evaluate: nil)) : nil)
    }
    /// Returns the value for the secondary locale, optionally falling back to another locale.
    ///
    /// - Parameter allowsFallback: Whether to use the first available locale when the secondary value is absent.
    /// - Returns: The selected value, or `nil` if no permitted value is available.
    public func forSecondaryLocale(allowsFallback: Bool = true) -> T? {
        forLocale(SekaiLocale.secondaryLocale) ?? (allowsFallback ? (forLocale(.jp) ?? forLocale(.en) ?? forLocale(.tw) ?? forLocale(.cn) ?? forLocale(.kr) ?? logger.warning("Failed to lookup any candidate of \(T.self) for secondary locale", evaluate: nil)) : nil)
    }
    /// Returns whether a value is stored for the primary locale.
    ///
    /// - Returns: `true` if the primary locale has a non-`nil` value, without fallback.
    @inlinable
    public func availableInPreferredLocale() -> Bool {
        forPreferredLocale(allowsFallback: false) != nil
    }
    /// Returns whether a value is stored for the secondary locale.
    ///
    /// - Returns: `true` if the secondary locale has a non-`nil` value, without fallback.
    @inlinable
    public func availableInSecondaryLocale() -> Bool {
        forSecondaryLocale(allowsFallback: false) != nil
    }
    /// Returns the first available locale in preference order.
    ///
    /// The supplied locale is checked first, followed by the primary and secondary
    /// locales, and then all locales in their declaration order.
    ///
    /// - Parameter locale: An optional locale to check before the configured preferences.
    /// - Returns: The first locale with a non-`nil` value, or `nil` if all values are absent.
    @inlinable
    public func availableLocale(prefer locale: SekaiLocale? = nil) -> SekaiLocale? {
        if let locale, availableInLocale(locale) {
            return locale
        }
        if availableInLocale(.primaryLocale) {
            return .primaryLocale
        }
        if availableInLocale(.secondaryLocale) {
            return .secondaryLocale
        }
        for locale in SekaiLocale.allCases where availableInLocale(locale) {
            return locale
        }
        return nil
    }
    
    /// Replaces the value stored for a locale.
    ///
    /// - Parameters:
    ///   - newValue: The replacement value, or `nil` to remove the stored value.
    ///   - locale: The locale to update.
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
    
    /// Accesses or modifies the optional value stored for a locale.
    ///
    /// - Parameter locale: The locale to access.
    /// - Returns: The stored value, or `nil` if unavailable.
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
    
    /// The locales with values, beginning with the available primary and secondary locales.
    ///
    /// The current ordering can include a preferred locale more than once.
    public var allAvailableLocales: [SekaiLocale] {
        let expectedLocales = [SekaiLocale.primaryLocale, SekaiLocale.secondaryLocale] + SekaiLocale.allCases.drop(while: { $0 == .primaryLocale || $0 == .secondaryLocale })
        
        var availableLocales: [SekaiLocale] = []
        for locale in SekaiLocale.allCases where self.availableInLocale(locale) {
            availableLocales.append(locale)
        }
        
        return expectedLocales.filter({ availableLocales.contains($0) })
    }
    
    /// The locales without values, in declaration order.
    public var allUnavailableLocales: [SekaiLocale] {
        let availableLocales = self.allAvailableLocales
        return SekaiLocale.allCases.filter({ !availableLocales.contains($0) })
    }
    
    /// The stored values expressed as a locale-keyed dictionary.
    ///
    /// The current implementation omits the Korean entry.
    public var dictionarized: [SekaiLocale: T] {
        return [.jp: self.jp, .en: self.en, .tw: self.tw, .cn: self.cn, .tw: self.tw].compactMapValues({ $0 })
    }
}


extension LocalizedData: Sendable where T: Sendable {}
extension LocalizedData: Equatable where T: Equatable {}
extension LocalizedData: Hashable where T: Hashable {}
extension LocalizedData: SekaiCache.Cacheable, Codable where T: SekaiCache.Cacheable {}

extension LocalizedData {
    /// Transforms the optional value for every supported locale.
    ///
    /// - Parameter transform: A closure applied to each locale’s value, including `nil`.
    /// - Returns: Localized storage containing the transformed values.
    /// - Throws: Any error thrown by `transform`.
    @inlinable
    public func map<R, E>(_ transform: (T?) throws(E) -> R?) throws(E) -> LocalizedData<R> {
        var result = LocalizedData<R>(jp: nil, en: nil, tw: nil, cn: nil, kr: nil)
        for locale in SekaiLocale.allCases {
            result.updateValue(try transform(self.forLocale(locale)), forLocale: locale)
        }
        return result
    }
    
    /// Transforms every locale’s optional value and collects non-`nil` results.
    ///
    /// - Parameter transform: A closure applied to each value, including `nil`, in locale declaration order.
    /// - Returns: The non-`nil` transformed values in locale declaration order.
    /// - Throws: Any error thrown by `transform`.
    @inlinable
    public func compactMap<ElementOfResult>(
        _ transform: (T?) throws -> ElementOfResult?
    ) rethrows -> [ElementOfResult] {
        return try _compactMap(transform)
    }
    
    // The implementation of compactMap accepting a closure with an optional result.
    // Factored out into a separate function in order to be used in multiple
    // overloads.
    /// Implements transformation and removal of `nil` results for localized storage.
    ///
    /// - Parameter transform: A closure applied to each locale’s optional value.
    /// - Returns: The non-`nil` transformed values in locale declaration order.
    /// - Throws: Any error thrown by `transform`.
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
    
    /// Pairs the non-`nil` values with locale labels derived from their compacted positions.
    ///
    /// Missing values are removed before labels are assigned. These labels can differ
    /// from the values’ original locales when earlier locales have no value.
    ///
    /// - Returns: The compacted values paired with positional locale labels.
    @inlinable
    public func enumerated() -> [(locale: SekaiLocale, element: T?)] {
        compactMap { $0 }.enumerated().map { (.init(rawIntValue: $0.offset)!, $0.element) }
    }

    /// A Boolean value indicating whether every locale’s value is `nil`.
    @inlinable
    public var isEmpty: Bool {
        self.jp == nil && self.en == nil && self.tw == nil && self.cn == nil && self.kr == nil
    }
    
    /// Returns whether any locale’s optional value satisfies a predicate.
    ///
    /// - Parameter method: The predicate to evaluate, including for missing values.
    /// - Returns: `true` if the predicate succeeds for at least one locale.
    @inlinable
    public func contains(where method: (T?) -> Bool) -> Bool {
        for locale in SekaiLocale.allCases {
            if method(self.forLocale(locale)) {
                return true
            }
        }
        return false
    }
    
    /// Returns whether every locale’s optional value satisfies a predicate.
    ///
    /// - Parameter method: The predicate to evaluate, including for missing values.
    /// - Returns: `true` if the predicate succeeds for all locales.
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
    /// A Boolean value indicating whether each locale’s collection is empty or absent.
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
    /// Returns whether any locale stores a value equal to the given optional value.
    ///
    /// - Parameter element: The value to find; `nil` matches an absent locale value.
    /// - Returns: `true` if at least one locale’s value equals `element`.
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
