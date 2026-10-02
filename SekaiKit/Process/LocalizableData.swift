//
//  LocalizableData.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/3/22.
//

/// A value stored either separately for each locale or without a locale association.
public enum LocalizableData<T> {
    /// Values associated with individual game locales.
    case localized(LocalizedData<T>)
    /// A single optional value without a locale association.
    case unlocalized(T?)
    
    /// The preferred localized value with fallback, or the unlocalized value.
    public var majorValue: T? {
        switch self {
        case .localized(let localizedData):
            return localizedData.forPreferredLocale(allowsFallback: true)
        case .unlocalized(let t):
            return t
        }
    }
    
    /// The locale-specific storage, or `nil` when the value is unlocalized.
    public var localizedData: LocalizedData<T>? {
        switch self {
        case .localized(let localizedData):
            return localizedData
        case .unlocalized(_):
            return nil
        }
    }
    
    /// The preferred available locale, or the primary locale for an unlocalized value.
    ///
    /// Returns `nil` when localized storage has no available values.
    public var majorLocale: SekaiLocale? {
        switch self {
        case .localized(let localizedData):
            localizedData.availableLocale()
        case .unlocalized(_):
            SekaiLocale.primaryLocale
        }
    }
    
    /// Sets the value for a locale, converting unlocalized storage if needed.
    ///
    /// An existing unlocalized value is discarded during conversion.
    ///
    /// - Parameters:
    ///   - value: The new value, or `nil` to remove the locale’s value.
    ///   - forLocale: The locale to update.
    public mutating func updateLocalizedValue(_ value: T?, forLocale: SekaiLocale) {
        var localizedData: LocalizedData<T> = .init()
        if case .localized(let givenData) = self {
            localizedData = givenData
        }
        localizedData.updateValue(value, forLocale: forLocale)
        self = .localized(localizedData)
    }
    
    /// Builds localized storage from records keyed by locale.
    ///
    /// Each input contributes only its value for the dictionary key’s locale, or
    /// its unlocalized value when it has no locale-specific storage.
    ///
    /// - Parameter dict: The source values keyed by locale.
    /// - Returns: A value containing the merged localized storage.
    public static func merge(_ dict: [SekaiLocale: LocalizableData]) -> LocalizableData {
        var combinedResult: LocalizedData<T> = .init()
        
        for (locale, data) in dict {
            switch data {
            case .localized(let localizedData):
                combinedResult.updateValue(localizedData[locale], forLocale: locale)
            case .unlocalized(let t):
                combinedResult.updateValue(t, forLocale: locale)
            }
        }
        
        return LocalizableData.localized(combinedResult)
    }
    
    /// A Boolean value indicating whether no value is stored in any locale or unlocalized storage.
    public var isEmpty: Bool {
        switch self {
        case .localized(let localizedData):
            return localizedData.isEmpty
        case .unlocalized(let t):
            return t == nil
        }
    }

    /// Transforms stored values while preserving the localization structure.
    ///
    /// - Parameter transform: A closure applied to the unlocalized value or to each locale’s optional value.
    /// - Returns: A value with the same localization structure and the transformed values.
    /// - Throws: Any error thrown by `transform`.
    @inlinable
    public func map<R, E>(_ transform: (T?) throws(E) -> R?) throws(E) -> LocalizableData<R> {
        switch self {
        case .localized(let localizedData):
            return .localized(try localizedData.map(transform))
        case .unlocalized(let t):
            return .unlocalized(try transform(t))
        }
//        var result = LocalizableData<R>(jp: nil, en: nil, tw: nil, cn: nil, kr: nil)
//        for locale in SekaiLocale.allCases {
//            result.updateValue(try transform(self.forLocale(locale)), forLocale: locale)
//        }
//        return result
    }
}

extension LocalizableData: Sendable where T: Sendable {}
extension LocalizableData: Equatable where T: Equatable {}
extension LocalizableData: Hashable where T: Hashable {}
extension LocalizableData: SekaiCache.Cacheable, Codable where T: SekaiCache.Cacheable {}

extension LocalizableData: ExpressibleByStringLiteral where T: ExpressibleByStringLiteral {
    /// Creates an unlocalized value from a string literal.
    ///
    /// - Parameter value: The literal used to create the wrapped value.
    public init(stringLiteral value: T.StringLiteralType) {
        self = .unlocalized(T(stringLiteral: value))
    }
}

extension LocalizableData: ExpressibleByUnicodeScalarLiteral where T: ExpressibleByUnicodeScalarLiteral {
    /// Creates an unlocalized value from a Unicode scalar literal.
    ///
    /// - Parameter value: The literal used to create the wrapped value.
    public init(unicodeScalarLiteral value: T.UnicodeScalarLiteralType) {
        self = .unlocalized(T(unicodeScalarLiteral: value))
    }
}

extension LocalizableData: ExpressibleByExtendedGraphemeClusterLiteral where T: ExpressibleByExtendedGraphemeClusterLiteral {
    /// Creates an unlocalized value from a extended grapheme cluster literal.
    ///
    /// - Parameter value: The literal used to create the wrapped value.
    public init(extendedGraphemeClusterLiteral value: T.ExtendedGraphemeClusterLiteralType) {
        self = .unlocalized(T(extendedGraphemeClusterLiteral: value))
    }
}

extension LocalizableData: ExpressibleByIntegerLiteral where T: ExpressibleByIntegerLiteral {
    /// Creates an unlocalized value from a integer literal.
    ///
    /// - Parameter value: The literal used to create the wrapped value.
    public init(integerLiteral value: T.IntegerLiteralType) {
        self = .unlocalized(T(integerLiteral: value))
    }
}

extension LocalizableData: ExpressibleByFloatLiteral where T: ExpressibleByFloatLiteral {
    /// Creates an unlocalized value from a floating-point literal.
    ///
    /// - Parameter value: The literal used to create the wrapped value.
    public init(floatLiteral value: T.FloatLiteralType) {
        self = .unlocalized(T(floatLiteral: value))
    }
}

extension LocalizableData: ExpressibleByBooleanLiteral where T: ExpressibleByBooleanLiteral {
    /// Creates an unlocalized value from a Boolean literal.
    ///
    /// - Parameter value: The literal used to create the wrapped value.
    public init(booleanLiteral value: T.BooleanLiteralType) {
        self = .unlocalized(T(booleanLiteral: value))
    }
}

extension LocalizableData: ExpressibleByNilLiteral {
    /// Creates an absent unlocalized value from a `nil` literal.
    ///
    /// - Parameter nilLiteral: The `nil` literal.
    public init(nilLiteral: ()) {
        self = .unlocalized(nil)
    }
}


extension LocalizableData where T: Collection {
    /// A Boolean value indicating whether every stored collection is empty or absent.
    public var isCollectionEmpty: Bool {
        switch self {
        case .localized(let localizedData):
            for locale in localizedData.allAvailableLocales {
                if !(localizedData[locale]?.isEmpty ?? true) {
                    return false
                }
            }
            return true
        case .unlocalized(let t):
            return t?.isEmpty ?? true
        }
    }
}

extension Optional {
    func localizable() -> LocalizableData<Wrapped> {
        return .unlocalized(self)
    }
}

internal func mergeCollections<T: LocalizationsCombinable & Identifiable>(
    _ data: [SekaiLocale: [T]],
    defaultLocale: SekaiLocale
) -> [T] {
    var allElements: [T.ID: [SekaiLocale: T]] = [:]
    
    for (locale, list) in data {
        for element in list {
            allElements[modifying: element.id][accessing: locale] = element
        }
    }
    
    return allElements.compactMap({ id, items in
        return T.combineLocalizations(items, defaultLocale: defaultLocale)
    })
}
