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
        guard !allResults.isEmpty else { return nil }
        let mergedCollection = mergeCollections(allResults, defaultLocale: .primaryLocale)
        
        return mergedCollection
    }
    
    /// Loads and combines records from all supported locales.
    ///
    /// Locales whose requests fail are omitted. Localized fields are combined by
    /// identifier, with the primary locale preferred for other fields.
    ///
    /// - Returns: The combined records, or `nil` if every locale fails to load.
    public static func all() async -> [Self]? {
        return await self._all()
    }
}

extension ListGettable where Self.ID: Comparable {
    /// Loads and combines records from all supported locales.
    ///
    /// Locales whose requests fail are omitted. Localized fields are combined by
    /// identifier, with the primary locale preferred for other fields.
    ///
    /// - Returns: The combined records sorted by ascending identifier, or `nil` if every locale fails to load.
    public static func all() async -> [Self]? {
        return await self._all()?.sorted(by: { $0.id < $1.id })
    }
}

extension ListGettable where Self: SekaiCachable {
    /// Loads the combined records using SekaiKit’s cache policy.
    ///
    /// - Parameter trait: The cache policy. The default allows a sufficiently recent cache to skip fetching.
    /// - Returns: The combined records, or `nil` if no result is available.
    public static func allWithCache(trait: SekaiCache.CacheTrait = .invocationElidable) async -> [Self]? {
        let baseURL = SekaiProtobuf.baseURL
        let usesProtobuf = Self.self == Character.self || Self.self == Event.self || Self.self == Card.self
        let suffix = usesProtobuf ? "_protobuf_\(SekaiProtobuf.cacheKey)" : ""
        return await SekaiCache.withDirectCache(id: "All\(String(describing: Self.Type.self))\(suffix)", trait: trait, invocation: {
            // SekaiCache uses a detached task, so carry the selected source explicitly.
            await SekaiProtobuf.$baseURL.withValue(baseURL) {
                await SekaiCache.$preferCachedNetworkSource.withValue(trait != .realTime) {
                    await Self.all()
                }
            }
        })
    }
}

/// A type that can asynchronously load an instance by identifier.
public protocol GettableByID {
    /// Loads an instance with the specified identifier.
    ///
    /// The initializer returns `nil` if the instance cannot be loaded.
    ///
    /// - Parameter id: The identifier to look up.
    init?(id: Int) async
}

extension GettableByID where Self: ListGettable, Self: SekaiCachable {
    /// Loads a record by identifier, using cached data before retrying a fresh fetch.
    ///
    /// The initializer returns `nil` if the requested record cannot be found.
    ///
    /// - Parameter id: The identifier to look up.
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


/// A type that can merge locale-specific records into a single value.
public protocol LocalizationsCombinable {
    /// Combines records from multiple locales.
    ///
    /// - Parameters:
    ///   - dict: The records keyed by locale.
    ///   - defaultLocale: The preferred source for fields that do not vary by locale.
    /// - Returns: The combined record, or `nil` if no source record is available.
    static func combineLocalizations(_ dict: [SekaiLocale: Self], defaultLocale: SekaiLocale) -> Self?
    
    /// Combines the non-`nil` records from multiple locales.
    ///
    /// - Parameters:
    ///   - dict: The optional records keyed by locale.
    ///   - defaultLocale: The preferred source for fields that do not vary by locale.
    /// - Returns: The combined record, or `nil` if no source record is available.
    static func combineLocalizations(_ dict: [SekaiLocale: Self?], defaultLocale: SekaiLocale) -> Self?
}

/// A type that can load a list of records for a locale and combine their localizations.
public protocol ListGettable: Identifiable, Sendable, LocalizationsCombinable {
    /// Loads the records available in a locale.
    ///
    /// - Parameter locale: The locale to request.
    /// - Returns: The records, or `nil` if loading fails.
    static func allInLocale(_ locale: SekaiLocale) async -> [Self]?
}

// MARK: - ExtendedTypeConvertible
/// A type that identifies a related model containing additional information.
public protocol ExtendedTypeConvertible {
    /// The model that loads the extended information by identifier.
    associatedtype ExtendedType: GettableByID, Sendable
}

extension Event: ExtendedTypeConvertible {
    /// The event model containing related card and song identifiers.
    public typealias ExtendedType = ExtendedEvent
}

extension Song: ExtendedTypeConvertible {
    /// The song model containing vocal versions.
    public typealias ExtendedType = ExtendedSong
}
