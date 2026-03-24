//
//  Protocol.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/2/1.
//

public protocol TitleDescribable {
    var title: String { get }
}

public protocol GettableByID {
    init?(id: Int) async
}

public protocol LocalizationsCombinable {
    static func combineLocalizations(_ dict: [SekaiLocale: Self], defaultLocale: SekaiLocale) -> Self?
    
    static func combineLocalizations(_ dict: [SekaiLocale: Self?], defaultLocale: SekaiLocale) -> Self?
}

public protocol ListGettable: Identifiable, Sendable, LocalizationsCombinable {
    static func allForLocale(_ locale: SekaiLocale) async -> [Self]?
}

extension ListGettable {
    private static func _all() async -> [Self]? {
        let groupResult = await withTasksResult {
            await Self.allForLocale(.jp)
        } _: {
            await Self.allForLocale(.en)
        } _: {
            await Self.allForLocale(.tw)
        } _: {
            await Self.allForLocale(.cn)
        }  _: {
            await Self.allForLocale(.kr)
        }
        
        let allResults: [SekaiLocale: [Self]] = [.jp: groupResult.0, .en: groupResult.1, .tw: groupResult.2, .cn: groupResult.3, .kr: groupResult.4].compactMapValues({ $0 })
        var mergedResult = mergeCollections(allResults, defaultLocale: .primaryLocale)
        
        return mergedResult
    }
    
    public static func all() async -> [Self]? {
        return await self._all()
    }
}

extension ListGettable where Self.ID: Comparable {
    public static func all() async -> [Self]? {
        return await self._all()?.sorted(by: { $0.id < $1.id })
    }
}

// MARK: - ExtendedTypeConvertible
public protocol ExtendedTypeConvertible {
    associatedtype ExtendedType
}
