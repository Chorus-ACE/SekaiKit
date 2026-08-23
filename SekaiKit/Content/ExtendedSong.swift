//
//  ExtendedSong.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/8/15.
//

import SekaiKitMacro
import Foundation

public struct ExtendedSong: Hashable, Sendable, Identifiable, SekaiCachable, GettableByID {
    public let id: Int
    public let song: Song
    public let vocals: [Song.VocalVersion]?
    
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
    @LocalizationsCombinable
    /// A version of a song in Project Sekai.
    public struct VocalVersion: Hashable, Sendable, SekaiCachable, LocalizationsCombinable, ListGettable {
        public var id: Int
        /// The ID of song the version belongs to.
        public var songID: Int
        
        /// The caption of the version.
        public var caption: LocalizableData<String>
        /// The type of the version.
        public var type: VocalType
        /// The date the version is published.
        public var publishDate: Date
        
        /// The released condition ID for the version.
        public var releaseConditionID: Int
        /// The asset bundle name for the version.
        public var assetBundleName: String
        
        /// The vocalists who sang the version.
        public var characters: [VocalCharacter]
        
        /// Type of a song's version.
        public enum VocalType: String, Hashable, Sendable, SekaiCachable {
            /// The version is sung by virtural singers (Vocaloid).
            case virtualSinger = "virtual_singer"
            /// The version is sung by characters in Project Sekai (Sekai ver.).
            case sekai
            /// The version is sung is a parallel covered by characters in Project Sekai.
            case anotherVocal = "another_vocal"
            /// The version is the original one for the covered song.
            case original = "original_song"
            /// The version is from a live concert.
            case live = "streaming_live"
            /// The version is instrumental (no vocal).
            case instrumental
            /// The version is an April Fools version.
            case aprilFools = "april_fool_2022" // Not necessary 2022
        }
        
        public static func allInLocale(_ locale: SekaiLocale = .primaryLocale) async -> [VocalVersion]? {
            let groupResult = await withTasksResult {
                await requestJSON("https://sekai-world.github.io/\(locale._databasePath)/musicVocals.json")
            } _: {
                if locale == .primaryLocale {
                    return await Song.VocalVersion.VocalCharacter.all()
                } else {
                    return nil
                }
            }
            
            guard let vocals = groupResult.0 else { return nil }
            let externalCharacters = groupResult.1
            
            let task = Task.detached(priority: .userInitiated) {
                var result: [VocalVersion] = []
                
                for (_, vocal) in vocals {
                    var characters: [VocalCharacter] = []
                    
                    for (_, c) in vocal["characters"] {
                        let characterID = c["characterId"].intValue
                        if c["characterType"] == "game_character" {
                            if let gameChar = SekaiCache.preCache.character(id: characterID) {
                                characters.append(.init(name: .localized(gameChar.fullName), characterID: characterID, isInternalCharacter: true))
                            }
                        } else if let externalChar = externalCharacters?.first(where: { $0.id == characterID }) {
                            characters.append(externalChar)
                        }
                    }
                    
                    result.append(.init(
                        id: vocal["id"].intValue,
                        songID: vocal["musicId"].intValue,
                        caption: vocal["caption"].string.localizable(),
                        type: VocalType(rawValue: vocal["musicVocalType"].stringValue) ?? .virtualSinger,
                        publishDate: vocal["archivePublishedAt"].dateValue,
                        releaseConditionID: vocal["releaseConditionId"].intValue,
                        assetBundleName: vocal["assetbundleName"].stringValue,
                        characters: characters
                    ))
                }
                return result
            }
            return await task.value
        }
    }
}

extension Song.VocalVersion {
    /// A character who sings in a song.
    @LocalizationsCombinable
    public struct VocalCharacter: Hashable, Sendable, SekaiCachable, LocalizationsCombinable, ListGettable {
        /// The name of the vocalist.
        public var name: LocalizableData<String>
        /// The id of the character.
        public var characterID: Int
        /// If the character is from Project Sekai.
        public var isInternalCharacter: Bool
        public var id: Int {
            characterID * (isInternalCharacter ? -1 : 1)
        }
        
        public static func allInLocale(_ locale: SekaiLocale) async -> [Song.VocalVersion.VocalCharacter]? {
            guard let json = await requestJSON("https://sekai-world.github.io/\(locale._databasePath)/outsideCharacters.json") else { return nil }
            
            var results: [VocalCharacter] = []
            for (_, char) in json {
                let id = char["id"].intValue
                let name = char["name"].stringValue
                
                results.append(.init(name: .unlocalized(name), characterID: id, isInternalCharacter: false))
            }
            
            return results
        }
    }
}
