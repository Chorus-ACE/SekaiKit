//
//  ExtendedSong.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/8/15.
//

import SekaiKitMacro
import Foundation

/// A song together with its available vocal versions.
public struct ExtendedSong: Hashable, Sendable, Identifiable, SekaiCachable, GettableByID {
    /// The unique identifier of the song.
    public let id: Int
    /// The base song information.
    public let song: Song
    /// The song’s vocal versions, or `nil` if the vocal list cannot be loaded.
    public let vocals: [Song.VocalVersion]?
    
    /// Loads a song and its vocal versions.
    ///
    /// The initializer fails if the base song cannot be loaded. The vocal list is
    /// read through the cache, with a direct fetch if that lookup fails.
    ///
    /// - Parameter id: The song identifier.
    public init?(id: Int) async {
        let groupResult = await withTasksResult {
            await Song(id: id)
        } _: {
            await Song.VocalVersion.allWithCache()
        }
        
        guard let song = groupResult.0 else { return nil }
        var vocals = groupResult.1
        
        var matchingVocals = vocals?.filter({ $0.songID == id })
        if matchingVocals == nil {
            vocals = await Song.VocalVersion.all()
            matchingVocals = vocals?.filter({ $0.songID == id })
        }
        
        self.id = id
        self.song = song
        self.vocals = matchingVocals
    }
}

extension Song {
    /// A vocal or instrumental version of a song in Project Sekai.
    @LocalizationsCombinable
    public struct VocalVersion: Hashable, Sendable, SekaiCachable, LocalizationsCombinable, ListGettable {
        /// The unique identifier of the vocal version.
        public var id: Int
        /// The identifier of the song to which this version belongs.
        public var songID: Int
        
        /// The caption of the version.
        public var caption: LocalizableData<String>
        /// The type of the version.
        public var type: VocalType
        /// The date this version is published in the archive.
        public var publishDate: Date
        
        /// The identifier of the condition required to unlock this version.
        public var releaseConditionID: Int
        /// The asset bundle name for the version.
        public var assetBundleName: String
        
        /// The vocalists who sang the version.
        public var characters: [VocalCharacter]
        
        /// The category of a song version.
        public enum VocalType: String, Hashable, Sendable, SekaiCachable {
            /// A version sung by Virtual Singers.
            case virtualSinger = "virtual_singer"
            case unknown
            /// The version is sung by characters in Project Sekai (Sekai ver.).
            case sekai
            /// An alternate cover sung by Project Sekai characters.
            case anotherVocal = "another_vocal"
            /// The original recording of a covered song.
            case original = "original_song"
            /// The version is from a live concert.
            case live = "streaming_live"
            /// An instrumental version without vocals.
            case instrumental
            /// The version is an April Fools version.
            case aprilFools = "april_fool_2022" // Not necessary 2022
        }
        
        /// Loads the records available in a locale.
        ///
        /// - Parameter locale: The locale whose records are requested.
        /// - Returns: The records for the locale, or `nil` if the required data cannot be loaded.
        public static func allInLocale(_ locale: SekaiLocale = .primaryLocale) async -> [VocalVersion]? {
            guard let list = await requestProtobuf("song.aar", as: _SongList.self) else { return nil }
            return list.items(in: locale).flatMap(\.vocals).map { VocalVersion(protobuf: $0) }
        }

        /// Loads vocal versions in the primary region's source order, appending
        /// versions unique to other regions in their source order.
        public static func all() async -> [VocalVersion]? {
            await loadAll(defaultLocale: .primaryLocale)
        }

        /// Caches vocal versions without changing their source order.
        ///
        /// The cache is specific to the archive source and preferred region.
        public static func allWithCache(trait: SekaiCache.CacheTrait = .invocationElidable) async -> [VocalVersion]? {
            let baseURL = SekaiProtobuf.baseURL
            let locale = SekaiLocale.primaryLocale
            // Use a new key so older, unordered cached lists are not reused.
            let cacheID = "AllSongVocalVersions_sourceOrder_v1_\(SekaiProtobuf.cacheKey)_\(locale.rawValue)"
            return await SekaiCache.withDirectCache(id: cacheID, trait: trait) {
                await SekaiProtobuf.$baseURL.withValue(baseURL) {
                    await SekaiCache.$preferCachedNetworkSource.withValue(trait != .realTime) {
                        await loadAll(defaultLocale: locale)
                    }
                }
            }
        }

        private static func loadAll(defaultLocale: SekaiLocale) async -> [VocalVersion]? {
            guard let list = await requestProtobuf("song.aar", as: _SongList.self) else { return nil }
            let regionalVocals = Dictionary(uniqueKeysWithValues: SekaiLocale.allCases.map { locale in
                (locale, list.items(in: locale).flatMap(\.vocals).map { VocalVersion(protobuf: $0) })
            })
            return mergeCollections(regionalVocals, defaultLocale: defaultLocale)
        }
    }
}

extension Song.VocalVersion {
    /// A character who sings in a song.
    @LocalizationsCombinable
    public struct VocalCharacter: Hashable, Sendable, SekaiCachable, LocalizationsCombinable, ListGettable {
        /// The name of the vocalist.
        public var name: LocalizableData<String>
        /// The identifier of the vocalist in the internal or external character list.
        public var characterID: Int
        /// A Boolean value indicating whether the vocalist is a Project Sekai character.
        public var isInternalCharacter: Bool
        /// The identifier of this vocal record.
        ///
        /// For a vocalist, internal character identifiers are negated to distinguish
        /// them from external vocalist identifiers.
        public var id: Int {
            characterID * (isInternalCharacter ? -1 : 1)
        }
        
        /// Loads the records available in a locale.
        ///
        /// - Parameter locale: The locale whose records are requested.
        /// - Returns: The records for the locale, or `nil` if the required data cannot be loaded.
        public static func allInLocale(_ locale: SekaiLocale) async -> [Song.VocalVersion.VocalCharacter]? {
        guard let list = await requestProtobuf("song.aar", as: _SongList.self) else { return nil }
        return list.outsideCharacters.items(in: locale).map { VocalCharacter(protobuf: $0) }
    }
    }
}
