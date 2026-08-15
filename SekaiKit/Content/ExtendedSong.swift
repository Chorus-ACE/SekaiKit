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
            await SekaiCache.withDirectCache(id: "AllSongVocals") {
                await Song.VocalVersion.all()
            }
        }
        
        guard let song = groupResult.0 else { return nil }
        let vocals = groupResult.1
        
        self.id = id
        self.song = song
        self.vocals = vocals?.filter({ $0.musicID == id }) ?? []
    }
}

extension Song {
    @LocalizationsCombinable
    public struct VocalVersion: Hashable, Sendable, SekaiCachable, LocalizationsCombinable, ListGettable {
        public var id: Int
        public var musicID: Int
        
        public var caption: LocalizableData<String>
        public var type: String
        public var publishDate: Date
        
        public var releaseCondition: Int
        public var assetbundleName: String
        
        public var characters: [VocalCharacter]
        
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
            guard let externalCharacters = groupResult.1 else { return nil }
            
            let task = Task.detached(priority: .userInitiated) {
                var result: [VocalVersion] = []
                
                for (_, vocal) in vocals {
                    var characters: [VocalCharacter] = []
                    
                    for (_, c) in vocal["characters"] {
                        let characterID = c["characterId"].intValue
                        if c["characterType"] == "game_character" {
                            if let gameChar = SekaiCache.preCache.character(id: characterID) {
                                characters.append(.init(name: .localized(gameChar.fullName), id: characterID, isInternalCharacter: true))
                            }
                        } else {
                            // FIXME: Debug Only
                            if c["characterType"] != "outside_character" {
                                fatalError()
                            }
                            
                            if let externalChar = externalCharacters.first(where: { $0.id == characterID }) {
                                characters.append(externalChar)
                            }
                        }
                    }
                    
                    result.append(.init(
                        id: vocal["id"].intValue,
                        musicID: vocal["musicId"].intValue,
                        caption: vocal["caption"].string.localizable(),
                        type: vocal["publishDate"].stringValue,
                        publishDate: vocal["publishDate"].dateValue,
                        releaseCondition: vocal["releaseCondition"].intValue,
                        assetbundleName: vocal["assetbundleName"].stringValue,
                        characters: characters
                    ))
                }
                
                print(Set(result.map(\.type)))
                
                return result
            }
            return await task.value
        }
    }
}

extension Song.VocalVersion {
    @LocalizationsCombinable
    public struct VocalCharacter: Hashable, Sendable, SekaiCachable, LocalizationsCombinable, ListGettable {
        public var name: LocalizableData<String>
        public var id: Int
        public var isInternalCharacter: Bool
        
        public static func allInLocale(_ locale: SekaiLocale) async -> [Song.VocalVersion.VocalCharacter]? {
            guard let json = await requestJSON("https://sekai-world.github.io/\(locale._databasePath)/outsideCharacters.json") else { return nil }
            
            var results: [VocalCharacter] = []
            for (_, char) in json {
                let id = char["id"].intValue
                let name = char["name"].stringValue
                
                results.append(.init(name: .unlocalized(name), id: id, isInternalCharacter: false))
            }
            
            return results
        }
    }
}
