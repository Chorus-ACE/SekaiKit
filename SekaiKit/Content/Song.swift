//
//  Song.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/8/9.
//

import Foundation
import SekaiKitMacro
import SwiftUI
import SwiftyJSON


@LocalizationsCombinable
public struct Song: Hashable, Codable, Sendable, Identifiable, SekaiCachable, LocalizationsCombinable {
    public var id: Int
    public var title: LocalizableData<String>
    //    public var pronunciation: String
    
    public var isNewlyWrittenMusic: Bool
    
    public var creatorArtist: LocalizableData<String>
    public var composer: LocalizableData<String>
    public var arranger: LocalizableData<String>
    public var lyricist: LocalizableData<String>
    
    public var publishDate: LocalizableData<Date>
    public var _releaseDate: LocalizableData<Date>
    
    public var categories: [Song.Category]
    public var availableMedia: [Song.MediaType]
    
    public var difficultyLevel: [Song.Difficulty: Int]
    public var noteCounts: [Song.Difficulty: Int]
    
    public var liveStageID: Int
    public var dancerCount: Int
    public var selfDancerPosition: Int
    
    public var releaseConditionID: Int
    
    public var assetbundleName: String
    public var liveTalkBackgroundAssetBundleName: String
    
    public var isFullLength: Bool
    public var fillerSec: Double
    public var secForMusicScoreMaker: Int?
    public var isAvailableForMusicScoreMaker: Bool?
    
    public enum MediaType: String, Hashable, Sendable, Codable, CaseIterable, SekaiCachable {
        case _2DMV = "mv"
        case _3DMV = "mv_2d"
        case image = "image"
        case originalMV = "original"
        
        public var localizedName: String {
            NSLocalizedString("Song.media.\(self.rawValue)", bundle: #bundle, comment: "")
        }
    }
    
    public enum Category: String, Hashable, Sendable, Codable, CaseIterable, SekaiCachable {
        case all = "all"
        case virturalSinger = "vocaloid"
        case leoNeed = "light_music_club"
        case moreMoreJump = "idol"
        case vividBadSquad = "street"
        case wonderlandsShowtime = "theme_park"
        case nightcordAt25 = "school_refusal"
        case other = "other"
        
        public var correspondingUnit: Unit? {
            switch self {
            case .virturalSinger: .virturalSinger
            case .leoNeed: .leoNeed
            case .moreMoreJump: .moreMoreJump
            case .vividBadSquad: .vividBadSquad
            case .wonderlandsShowtime: .wonderlandsShowtime
            case .nightcordAt25: .nightcordAt25
            default: nil
            }
        }
        
        public var localizedName: String {
            self.localizedName()
        }
        
        public func localizedName(caseAllConveysMixed mixed: Bool = false) -> String {
            if let unit = self.correspondingUnit {
                return unit.localizedName
            } else if self == .all {
                return NSLocalizedString(mixed ? "Song.category.mixed" : "Song.category.all", bundle: #bundle, comment: "")
            } else if self == .other {
                return NSLocalizedString("Song.category.other", bundle: #bundle, comment: "")
            }
            return ""
        }
    }
    
    public enum Difficulty: String, Hashable, Sendable, Codable, CaseIterable, SekaiCachable, Comparable {
        case easy
        case normal
        case hard
        case expert
        case master
        case append
        
        public var name: String {
            return self.rawValue.uppercased()
        }
        
        public var color: Color {
            switch self {
            case .easy: Color(red: 17/255, green: 221/255, blue: 119/255)
            case .normal: Color(red: 51/255, green: 204/255, blue: 255/255)
            case .hard: Color(red: 255/255, green: 204/255, blue: 0/255)
            case .expert: Color(red: 255/255, green: 68/255, blue: 119/255)
            case .master: Color(red: 204/255, green: 51/255, blue: 255/255)
            case .append: Color(red: 255/255, green: 125/255, blue: 200/255)
            }
        }
        
        public static func < (lhs: borrowing Song.Difficulty, rhs: borrowing Song.Difficulty) -> Bool {
            Difficulty.allCases.firstIndex(of: lhs)! < Difficulty.allCases.firstIndex(of: rhs)!
        }
    }
    
    public var majorCategory: Category {
        let filteredCategories = self.categories.filter({ $0.correspondingUnit != nil })
        let majorUnits = filteredCategories.filter({ $0 != .virturalSinger })
        if majorUnits.count == 1 {
            return majorUnits.first! // Commissioned
        } else if majorUnits.count > 1 {
            return .all // Mixed
        } else if filteredCategories.count == 1 {
            return filteredCategories.first! // Vocaloid
        } else {
            return .other
        }
    }
}

extension Song: ListGettable {
    public static func allInLocale(_ locale: SekaiLocale = .primaryLocale) async -> [Song]? {
        let groupResult = await withTasksResult {
            await requestJSON("https://sekai-world.github.io/\(locale._databasePath)/musics.json")
        } _: {
            await requestJSON("https://sekai-world.github.io/\(locale._databasePath)/musicTags.json")
        } _: {
            await requestJSON("https://sekai-world.github.io/\(locale._databasePath)/musicDifficulties.json")
        } _: {
            if [SekaiLocale.jp, .en].contains(locale) {
                return await requestJSON("https://sekai-world.github.io/\(locale._databasePath)/musicArtists.json")
            } else {
                return nil
            }
        }
        
        guard let musics = groupResult.0 else { return nil }
        guard let tags = groupResult.1 else { return nil }
        guard let difficulties = groupResult.2 else { return nil }
        let artists = groupResult.3
        
        let task = Task.detached(priority: .userInitiated) {
            var result: [Song] = []
        
            var unitCatagories: [Int: [Song.Category]] = [:]
            for (_, value) in tags {
                let id = value["musicId"].intValue
                let category = value["musicTag"].stringValue
                if let castedCatagory = Song.Category(rawValue: category) {
                    unitCatagories[id] = (unitCatagories[id] ?? []) + [castedCatagory]
                }
            }
            
            var difficultyLevel: [Int: [Difficulty: Int]] = [:]
            var noteCounts: [Int: [Difficulty: Int]] = [:]
            for (_, value) in difficulties {
                let id = value["musicId"].intValue
                let difficulty = value["musicDifficulty"].stringValue
                let level = value["playLevel"].intValue
                let notes = value["totalNoteCount"].intValue
                if let difficulty = Difficulty(rawValue: difficulty) {
                    difficultyLevel[modifying: id][accessing: difficulty] = level
                    noteCounts[modifying: id][accessing: difficulty] = notes
                }
            }
            
            var artistDict: [Int: String] = [:]
            if let artists {
                for (_, value) in artists {
                    let id = value["id"].intValue
                    let name = value["name"].stringValue
                    artistDict.updateValue(name, forKey: id)
                }
            }
            
            for (_, value) in musics {
                var categories: [String] = []
                for (_, v) in value["categories"] {
                    if let stringV = v.string {
                        categories.append(stringV)
                    } else if let objectV = v["musicCategoryName"].string {
                        categories.append(objectV)
                    }
                }
                let parsedCategories: [Song.MediaType] = categories.compactMap({ Song.MediaType(rawValue: $0) })
                
                let texts: (String, String, String, String, String) = {
                    if let v = value["infos"].arrayValue.first {
                        return (v["title"].stringValue,
                                v["creator"].stringValue,
                                v["lyricist"].stringValue,
                                v["composer"].stringValue,
                                v["arranger"].stringValue)
                    } else {
                        return (value["title"].stringValue,
                                artistDict[value["creatorArtistId"].intValue] ?? "",
                                value["lyricist"].stringValue,
                                value["composer"].stringValue,
                                value["arranger"].stringValue)
                    }
                }()
                
                let id = value["id"].intValue
                
                result.append(Song(
                    id: id,
                    title: .unlocalized(texts.0),
                    isNewlyWrittenMusic: value["isNewlyWrittenMusic"].boolValue,
                    creatorArtist: .unlocalized(texts.1),
                    composer: .unlocalized(texts.2),
                    arranger: .unlocalized(texts.3),
                    lyricist: .unlocalized(texts.4),
                    publishDate: value["publishedAt"].date.localizable(),
                    _releaseDate: value["releasedAt"].date.localizable(),
                    categories: unitCatagories[id] ?? [],
                    availableMedia: parsedCategories,
                    difficultyLevel: difficultyLevel[id] ?? [:],
                    noteCounts: noteCounts[id] ?? [:],
                    liveStageID: value["liveStageID"].intValue,
                    dancerCount: value["dancerCount"].intValue,
                    selfDancerPosition: value["selfDancerPosition"].intValue,
                    releaseConditionID: value["releaseConditionID"].intValue,
                    assetbundleName: value["assetbundleName"].stringValue,
                    liveTalkBackgroundAssetBundleName: value["liveTalkBackgroundAssetbundleName"].stringValue,
                    isFullLength: value["isFullLength"].boolValue,
                    fillerSec: value["fillerSec"].doubleValue,
                    secForMusicScoreMaker: value["secForMusicScoreMaker"].int,
                    isAvailableForMusicScoreMaker: value["isAvailableForMusicScoreMaker"].bool
                ))
            }
            return result
        }
        return await task.value
    }
}

extension Song: GettableByID {
    public init?(id: Int) async {
        let allItems = await SekaiCache.withDirectCache(id: "AllSongs") { await Song.all() }
        guard let item = allItems?.first(where: { $0.id == id }) else {
            return nil
        }
        self = item
    }
}
extension Song {
    public var coverImageURL: URL {
        self.coverImageURL()
    }
    
    public func coverImageURL(in locale: SekaiLocale? = nil) -> URL {
        .init(string: "https://storage.sekai.best/\((locale ?? self.title.majorLocale ?? .primaryLocale )._assetsPath)/music/jacket/\(self.assetbundleName)/\(self.assetbundleName).webp")!
    }
}

extension Song {
    public func chartImageURL(for difficulty: Song.Difficulty, preferSVG: Bool = true) -> URL {
        Self.chartImageURL(id: self.id, difficulty: difficulty, preferSVG: preferSVG)
    }
    
    public static func chartImageURL(id: Int, difficulty: Song.Difficulty, preferSVG: Bool = true) -> URL {
        let stringID = "\(id < 1000 ? "0" : "")\(id < 100 ? "0" : "")\(id < 10 ? "0" : "")\(id)"
        return URL(string: "https://storage.sekai.best/sekai-music-charts/jp/\(stringID)/\(difficulty.rawValue).\(preferSVG ? "svg" : "png")")!
    }
}
