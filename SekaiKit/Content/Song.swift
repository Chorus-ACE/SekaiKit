//
//  Song.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/8/9.
//

import Foundation
import SekaiKitMacro
import SwiftUI
internal import SwiftyJSON

/// A song that can be played in Project Sekai.
@LocalizationsCombinable
public struct Song: Hashable, Codable, Sendable, Identifiable, SekaiCachable, LocalizationsCombinable {
    /// The unique identifier of the song.
    public var id: Int
    
    /// The title of the song.
    public var title: LocalizableData<String>
    // public var pronunciation: String
    
    /// A Boolean value indicating whether the song was commissioned for Project Sekai.
    public var isNewlyWrittenMusic: Bool
    
    /// The localized creator credit for the song.
    public var creatorArtist: LocalizableData<String>
    /// The composer of the song.
    public var composer: LocalizableData<String>
    /// The arranger of the song.
    public var arranger: LocalizableData<String>
    /// The lyricist of the song.
    public var lyricist: LocalizableData<String>
    
    /// The time the song becomes available.
    public var publishDate: LocalizableData<Date>
    /// The localized `releasedAt` timestamp from the source data.
    ///
    /// Use ``publishDate`` for the date the song becomes available in the game.
    public var _releaseDate: LocalizableData<Date>
    
    /// The song’s categories, including unit affiliations.
    public var categories: [Song.Category]
    /// The background media available for the song, including music videos and a static image.
    public var availableMedia: [Song.MediaType]
    
    /// The chart level for each available difficulty.
    public var difficultyLevel: [Song.Difficulty: Int]
    /// The note count for each available difficulty.
    public var noteCounts: [Song.Difficulty: Int]
    
    /// The identifier of the live stage associated with the song.
    public var liveStageID: Int
    /// The number of dancers appearing in the 3D music video.
    public var dancerCount: Int
    /// The player’s dancer position value from the source data.
    public var selfDancerPosition: Int
    
    /// ID of the release condition.
    public var releaseConditionID: Int
    
    /// Bundle name used to get related assets.
    public var assetbundleName: String
    /// Bundle name used to get live talk background.
    public var liveTalkBackgroundAssetBundleName: String
    
    /// A Boolean value indicating whether the song is a full-length recording.
    public var isFullLength: Bool
    
    /// The silence before the song begins, in seconds.
    public var fillerSec: Double
    /// The duration available to the score maker, in seconds, if provided.
    public var secForMusicScoreMaker: Int?
    /// Whether the song is available to the score maker, or `nil` if unspecified.
    public var isAvailableForMusicScoreMaker: Bool?
    
    /// The type of media that is used for background.
    public enum MediaType: String, Hashable, Sendable, Codable, CaseIterable, SekaiCachable {
        /// The media case stored with the `mv` source value.
        case _3DMV = "mv"
        /// The media case stored with the `mv_2d` source value.
        case _2DMV = "mv_2d"
        /// A static cover image.
        case image = "image"
        /// The original music video.
        case originalMV = "original"
        
        /// The display name localized for the app’s current language.
        public var localizedName: String {
            NSLocalizedString("Song.media.\(self.rawValue)", bundle: #bundle, comment: "")
        }
    }
    
    /// A category used to group songs by unit or recording affiliation.
    public enum Category: String, Hashable, Sendable, Codable, CaseIterable, SekaiCachable {
        /// The all-songs category, also used to represent mixed-unit songs.
        case all = "all"
        /// Virtual Singers.
        case virtualSinger = "vocaloid"
        /// Leo/need.
        case leoNeed = "light_music_club"
        /// MORE MORE JUMP!.
        case moreMoreJump = "idol"
        /// Vivid BAD SQUAD.
        case vividBadSquad = "street"
        /// Wonderlands×Showtime.
        case wonderlandsShowtime = "theme_park"
        /// Nightcord at 25:00.
        case nightcordAt25 = "school_refusal"
        /// A category for songs without a matching unit affiliation.
        case other = "other"
        
        /// The unit represented by the category, or `nil` if the category has no specific unit.
        public var correspondingUnit: Unit? {
            switch self {
            case .virtualSinger: .virtualSinger
            case .leoNeed: .leoNeed
            case .moreMoreJump: .moreMoreJump
            case .vividBadSquad: .vividBadSquad
            case .wonderlandsShowtime: .wonderlandsShowtime
            case .nightcordAt25: .nightcordAt25
            default: nil
            }
        }
        
        /// The display name localized for the app’s current language.
        public var localizedName: String {
            self.localizedName()
        }

        /// Returns a localized category label.
        ///
        /// - Parameter mixed: Whether the all-songs category should be labeled as mixed-unit music.
        /// - Returns: The localized label for the category.
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
    
    /// A chart difficulty, ordered from Easy through Append.
    public enum Difficulty: String, Hashable, Sendable, Codable, CaseIterable, SekaiCachable, Comparable {
        /// The Easy difficulty.
        case easy
        /// The Normal difficulty.
        case normal
        /// The Hard difficulty.
        case hard
        /// The Expert difficulty.
        case expert
        /// The Master difficulty.
        case master
        /// The Append difficulty.
        case append
        
        /// The uppercase name of the difficulty.
        public var name: String {
            return self.rawValue.uppercased()
        }
        
        /// The display color associated with the difficulty.
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
        
        /// Returns whether one difficulty precedes another in the game’s difficulty order.
        ///
        /// - Parameters:
        ///   - lhs: The first difficulty.
        ///   - rhs: The second difficulty.
        /// - Returns: `true` if `lhs` precedes `rhs`.
        public static func < (lhs: borrowing Song.Difficulty, rhs: borrowing Song.Difficulty) -> Bool {
            Difficulty.allCases.firstIndex(of: lhs)! < Difficulty.allCases.firstIndex(of: rhs)!
        }
        
        /// The gradient color of Append difficulty.
        public static let appendGradient = Gradient(colors: [
            Color(red: 180/255, green: 146/255, blue: 254/255),
            Color(red: 254/255, green: 123/255, blue: 227/255)
        ])
    }
    
    /// The representative unit category, or a mixed or other category when appropriate.
    ///
    /// A single non-Virtual Singer unit takes precedence. Multiple such units produce
    /// `all`; a lone Virtual Singer category is preserved; other combinations produce `other`.
    public var majorCategory: Category {
        let filteredCategories = self.categories.filter({ $0.correspondingUnit != nil })
        let majorUnits = filteredCategories.filter({ $0 != .virtualSinger })
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

extension Song: ListGettable, GettableByID {
    /// Loads the records available in a locale.
    ///
    /// - Parameter locale: The locale whose records are requested.
    /// - Returns: The records for the locale, or `nil` if the required data cannot be loaded.
    public static func allInLocale(_ locale: SekaiLocale = .primaryLocale) async -> [Song]? {
        guard let list = await requestProtobuf("song.aar", as: _SongList.self) else { return nil }
        return list.items(in: locale).map { Song(protobuf: $0) }
    }
}

extension Song {
    /// The cover image URL using the title’s locale, with the primary locale as a fallback.
    public var coverImageURL: URL {
        self.coverImageURL()
    }
    
    /// Returns the cover image URL for a locale.
    ///
    /// - Parameter locale: The asset locale, or `nil` to use the title’s locale and then the primary locale.
    /// - Returns: The URL of the song’s cover image.
    public func coverImageURL(in locale: SekaiLocale? = nil) -> URL {
        .init(string: "https://storage.sekai.best/\((locale ?? self.title.majorLocale ?? .primaryLocale )._assetsPath)/music/jacket/\(self.assetbundleName)/\(self.assetbundleName).webp")!
    }
}

extension Song {
    /// Returns the Japanese chart image URL for this song.
    ///
    /// - Parameters:
    ///   - difficulty: The chart difficulty.
    ///   - preferSVG: Whether to request SVG instead of PNG.
    /// - Returns: The chart image URL; this method does not check asset availability.
    public func chartImageURL(for difficulty: Song.Difficulty, preferSVG: Bool = true) -> URL {
        Self.chartImageURL(id: self.id, in: self.title.majorLocale ?? .jp, difficulty: difficulty, preferSVG: preferSVG)
    }
    
    /// Returns a Japanese chart image URL for a song identifier.
    ///
    /// - Parameters:
    ///   - id: The song identifier.
    ///   - in: The server region.
    ///   - difficulty: The chart difficulty.
    ///   - preferSVG: Whether to request SVG instead of PNG.
    /// - Returns: The chart image URL; this method does not check asset availability.
    public static func chartImageURL(id: Int, in locale: SekaiLocale = .jp, difficulty: Song.Difficulty, preferSVG: Bool = true) -> URL {
        let stringID = "\(id < 1000 ? "0" : "")\(id < 100 ? "0" : "")\(id < 10 ? "0" : "")\(id)"
        return URL(string: "https://storage.sekai.best/sekai-music-charts/\(locale.rawValue)/\(stringID)/\(difficulty.rawValue).\(preferSVG ? "svg" : "png")")!
    }
}

extension Song {
    /// A file extension used when constructing a song audio URL.
    public enum FileType: String, Hashable, Codable, Sendable, SekaiCachable {
        /// The MP3 file extension.
        case mp3
        /// The literal `flav` file extension.
        case flav
        /// The WAV file extension.
        case wav
    }
    
    /// Returns a Japanese audio asset URL for a vocal version.
    ///
    /// - Parameters:
    ///   - vocalAssetBundleName: The asset bundle name of the vocal version.
    ///   - preview: Whether to request the short preview instead of the full recording.
    ///   - fileType: The audio file extension to request.
    /// - Returns: The audio URL; this method does not check asset availability.
    public func musicURL(vocalAssetBundleName: String, preview: Bool = false, fileType: FileType = .mp3) -> URL {
        let length = preview ? "short" : "long"
        return URL(string: "https://storage.sekai.best/sekai-jp-assets/music/\(length)/\(vocalAssetBundleName)/\(vocalAssetBundleName)\(preview ? "_short" : "").\(fileType.rawValue)")!
    }
}
