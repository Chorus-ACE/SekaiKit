//===---*- Greatdori! -*---------------------------------------------------===//
//
// Searching.swift
//
// This source file is part of the Greatdori! open source project
//
// Copyright (c) 2025 the Greatdori! project authors
// Licensed under Apache License v2.0
//
// See https://greatdori.com/LICENSE.txt for license information
// See https://greatdori.com/CONTRIBUTORS.txt for the list of Greatdori! project authors
//
//===----------------------------------------------------------------------===//

import SwiftUI
import Foundation

/// A type that can be searched when in a collection.
public protocol SekaiSearchable: Identifiable {
    var _searchStrings: [String] { get }
    var _searchLocalizedStrings: [LocalizableData<String>] { get }
}

extension SekaiSearchable {
    public var _searchStrings: [String] { [] }
    public var _searchLocalizedStrings: [LocalizableData<String>] { [] }
}

extension Array where Element: SekaiSearchable {
    /// Returns a new array which is filtered by given keyword.
    ///
    /// - Parameters:
    ///   - keyword: Keyword for searching.
    /// - Returns: A new array which is filtered by given keyword.
    ///
    /// This function performs a "smart search" like the one on Bestdori! website.
    public func search(for keyword: String) -> Self {
        let tokens = keyword.split(separator: " ").map { $0.lowercased() }
        guard !tokens.isEmpty else { return self }
        
        
        var result = self
        var removes = IndexSet()
        let keyPattern = keyword.replacing(" ", with: "")
        itemLoop: for (index, item) in result.enumerated() {
            tokenLoop: for token in tokens {
                // We always do early exit for performance
                for string in item._searchStrings {
                    if string.lowercased().contains(token) {
                        continue tokenLoop
                    }
                }
                for localizableString in item._searchLocalizedStrings {
                    switch localizableString {
                    case .localized(let localizedString):
                        for locale in SekaiLocale.allCases {
                            if localizedString.forLocale(locale)?.lowercased().contains(token) == true {
                                continue tokenLoop
                            }
                        }
                    case .unlocalized(let string):
                        if string?.lowercased().contains(token) == true {
                            continue tokenLoop
                        }
                    }
                }
                if token.hasPrefix("#"), let intToken = Int(String(token.dropFirst())) {
                    if (item.id as? Int) == intToken {
                        continue tokenLoop
                    }
                }
                removes.insert(index)
            }
        }
        result.remove(atOffsets: removes)
        
        return result
    }
}

extension Card: SekaiSearchable {
    public var _searchLocalizedStrings: [LocalizableData<String>] {
        [self.title]
    }
}

extension Event: SekaiSearchable {
    public var _searchLocalizedStrings: [LocalizableData<String>] {
        [self.title]
    }
}

extension Song: SekaiSearchable {
    public var _searchLocalizedStrings: [LocalizableData<String>] {
        [self.title, self.creatorArtist, self.lyricist, self.composer, self.arranger]
    }
}





//extension DoriAPI.Comics.Comic: DoriFrontend.Searchable {
//    public var _searchLocalizedStrings: [DoriAPI.LocalizedData<String>] {
//        [self.title, self.subTitle]
//    }
//    public var _searchLocales: [DoriAPI.Locale] {
//        var result = [DoriAPI.Locale]()
//        for locale in DoriAPI.Locale.allCases {
//            if self.title.availableInLocale(locale) {
//                result.append(locale)
//            }
//        }
//        return result
//    }
//    public var _searchBands: [DoriAPI.Bands.Band] {
//        PreCache.current.mainBands.filter {
//            _characters.compactMap { $0.bandID }.contains($0.id)
//        }
//    }
//    
//    private var _characters: [DoriAPI.Characters.PreviewCharacter] {
//        PreCache.current.characters.filter {
//            self.characterIDs.contains($0.id)
//        }
//    }
//}
//extension DoriAPI.Costumes.PreviewCostume: DoriFrontend.Searchable {
//    public var _searchLocalizedStrings: [DoriAPI.LocalizedData<String>] {
//        [
//            self.description,
//            _character?.characterName,
//            _character?.nickname.isEmpty == false ? _character?.nickname : nil
//        ].compactMap { $0 }
//    }
//    public var _searchLocales: [DoriAPI.Locale] {
//        var result = [DoriAPI.Locale]()
//        for locale in DoriAPI.Locale.allCases {
//            if self.publishedAt.availableInLocale(locale) {
//                result.append(locale)
//            }
//        }
//        return result
//    }
//    public var _searchBands: [DoriAPI.Bands.Band] {
//        if let bandID = _character?.bandID {
//            PreCache.current.mainBands.filter {
//                bandID == $0.id
//            }
//        } else {
//            []
//        }
//    }
//    
//    public var _character: DoriAPI.Characters.PreviewCharacter? {
//        PreCache.current.characters.first {
//            $0.id == self.characterID
//        }
//    }
//}

//extension DoriAPI.Gachas.PreviewGacha: DoriFrontend.Searchable {
//    public var _searchStrings: [String] {
//        [self.type.localizedString]
//    }
//    public var _searchLocalizedStrings: [DoriAPI.LocalizedData<String>] {
//        [self.gachaName]
//    }
//    public var _searchLocales: [DoriAPI.Locale] {
//        var result = [DoriAPI.Locale]()
//        for locale in DoriAPI.Locale.allCases {
//            if self.publishedAt.availableInLocale(locale) {
//                result.append(locale)
//            }
//        }
//        return result
//    }
//}
//extension DoriAPI.LoginCampaigns.PreviewCampaign: DoriFrontend.Searchable {
//    public var _searchStrings: [String] {
//        [self.loginBonusType.localizedString]
//    }
//    public var _searchLocalizedStrings: [DoriAPI.LocalizedData<String>] {
//        [self.caption]
//    }
//    public var _searchLocales: [DoriAPI.Locale] {
//        var result = [DoriAPI.Locale]()
//        for locale in DoriAPI.Locale.allCases {
//            if self.publishedAt.availableInLocale(locale) {
//                result.append(locale)
//            }
//        }
//        return result
//    }
//}
//extension DoriAPI.Songs.PreviewSong: DoriFrontend.Searchable {
//    public var _searchStrings: [String] {
//        [self.tag.localizedString]
//    }
//    public var _searchLocalizedStrings: [DoriAPI.LocalizedData<String>] {
//        [self.musicTitle]
//    }
//    public var _searchLocales: [DoriAPI.Locale] {
//        var result = [DoriAPI.Locale]()
//        for locale in DoriAPI.Locale.allCases {
//            if self.publishedAt.availableInLocale(locale) {
//                result.append(locale)
//            }
//        }
//        return result
//    }
//}
