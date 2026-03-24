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
        case .unlocalized(let t):
            return nil
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
