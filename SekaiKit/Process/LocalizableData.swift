//
//  LocalizableData.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/3/22.
//

public enum LocalizableData<T> {
    case localized(LocalizedData<T>)
    case unlocalized(T?)
    
    public var majorValue: T? {
        switch self {
        case .localized(let localizedData):
            return localizedData.forPreferredLocale(allowsFallback: true)
        case .unlocalized(let t):
            return t
        }
    }
    
    public var localizedData: LocalizedData<T>? {
        switch self {
        case .localized(let localizedData):
            return localizedData
        case .unlocalized(_):
            return nil
        }
    }
    
    public var majorLocale: SekaiLocale? {
        switch self {
        case .localized(let localizedData):
            localizedData.availableLocale()
        case .unlocalized(_):
            SekaiLocale.primaryLocale
        }
    }
    
    public mutating func updateLocalizedValue(_ value: T?, forLocale: SekaiLocale) {
        var localizedData: LocalizedData<T> = .init()
        if case .localized(let givenData) = self {
            localizedData = givenData
        }
        localizedData.updateValue(value, forLocale: forLocale)
        self = .localized(localizedData)
    }
    
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
    
    public var isEmpty: Bool {
        switch self {
        case .localized(let localizedData):
            return localizedData.isEmpty
        case .unlocalized(let t):
            return t == nil
        }
    }

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
    public init(stringLiteral value: T.StringLiteralType) {
        self = .unlocalized(T(stringLiteral: value))
    }
}

extension LocalizableData: ExpressibleByUnicodeScalarLiteral where T: ExpressibleByUnicodeScalarLiteral {
    public init(unicodeScalarLiteral value: T.UnicodeScalarLiteralType) {
        self = .unlocalized(T(unicodeScalarLiteral: value))
    }
}

extension LocalizableData: ExpressibleByExtendedGraphemeClusterLiteral where T: ExpressibleByExtendedGraphemeClusterLiteral {
    public init(extendedGraphemeClusterLiteral value: T.ExtendedGraphemeClusterLiteralType) {
        self = .unlocalized(T(extendedGraphemeClusterLiteral: value))
    }
}

extension LocalizableData: ExpressibleByIntegerLiteral where T: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: T.IntegerLiteralType) {
        self = .unlocalized(T(integerLiteral: value))
    }
}

extension LocalizableData: ExpressibleByFloatLiteral where T: ExpressibleByFloatLiteral {
    public init(floatLiteral value: T.FloatLiteralType) {
        self = .unlocalized(T(floatLiteral: value))
    }
}

extension LocalizableData: ExpressibleByBooleanLiteral where T: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: T.BooleanLiteralType) {
        self = .unlocalized(T(booleanLiteral: value))
    }
}

extension LocalizableData: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .unlocalized(nil)
    }
}


extension LocalizableData where T: Collection {
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
