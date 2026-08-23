//
//  Protocol.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/2/1.
//

extension ListGettable {
    private static func _all() async -> [Self]? {
        let groupResult = await withTasksResult {
            await Self.allInLocale(.jp)
        } _: {
            await Self.allInLocale(.en)
        } _: {
            await Self.allInLocale(.tw)
        } _: {
            await Self.allInLocale(.cn)
        }  _: {
            await Self.allInLocale(.kr)
        }
        
        let allResults: [SekaiLocale: [Self]] = [.jp: groupResult.0, .en: groupResult.1, .tw: groupResult.2, .cn: groupResult.3, .kr: groupResult.4].compactMapValues({ $0 })
        let mergedCollection = mergeCollections(allResults, defaultLocale: .primaryLocale)
        
        return mergedCollection
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

extension ListGettable where Self: SekaiCachable {
    public static func allWithCache(trait: SekaiCache.CacheTrait = .invocationElidable) async -> [Self]? {
        await SekaiCache.withDirectCache(id: "All\(String(describing: Self.Type.self))", trait: trait, invocation: {
            await Self.all()
        })
    }
}

public protocol GettableByID {
    init?(id: Int) async
}

extension GettableByID where Self: ListGettable, Self: SekaiCachable {
    public init?(id: Self.ID) async {
        // Use cache first if available
        if let item = await Self.allWithCache(trait: .invocationElidable)?.first(where: { $0.id == id }) {
            self = item
            return
        }
        
        // If target element not found, fetch again in real time
        guard let item = await Self.allWithCache(trait: .realTime)?.first(where: { $0.id == id }) else { return nil }
        
        self = item
    }
}


public protocol LocalizationsCombinable {
    static func combineLocalizations(_ dict: [SekaiLocale: Self], defaultLocale: SekaiLocale) -> Self?
    
    static func combineLocalizations(_ dict: [SekaiLocale: Self?], defaultLocale: SekaiLocale) -> Self?
}

public protocol ListGettable: Identifiable, Sendable, LocalizationsCombinable {
    static func allInLocale(_ locale: SekaiLocale) async -> [Self]?
}

// MARK: - ExtendedTypeConvertible
public protocol ExtendedTypeConvertible {
    associatedtype ExtendedType: GettableByID, Sendable
}

extension Event: ExtendedTypeConvertible {
    public typealias ExtendedType = ExtendedEvent
}

extension Song: ExtendedTypeConvertible {
    public typealias ExtendedType = ExtendedSong
}
