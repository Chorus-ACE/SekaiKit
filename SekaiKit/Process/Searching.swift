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
    /// The unlocalized strings searched for this record.
    var _searchStrings: [String] { get }
    /// The localized strings searched across all available locales for this record.
    var _searchLocalizedStrings: [LocalizableData<String>] { get }
}

extension SekaiSearchable {
    /// The unlocalized strings searched for this record.
    public var _searchStrings: [String] { [] }
    /// The localized strings searched across all available locales for this record.
    public var _searchLocalizedStrings: [LocalizableData<String>] { [] }
}

extension Array where Element: SekaiSearchable {
    /// Returns elements matching every whitespace-separated search token.
    ///
    /// Matching is case-insensitive and uses substring comparisons across localized
    /// and unlocalized search fields. A token such as `#42` also matches an integer
    /// record identifier. Empty or whitespace-only input returns the original array.
    ///
    /// - Parameter keyword: The text containing the search tokens.
    /// - Returns: The matching elements in their original order.
    public func search(for keyword: String) -> Self {
        let tokens = keyword.split(whereSeparator: { $0.isWhitespace }).map { $0.lowercased() }
        guard !tokens.isEmpty else { return self }

        return filter { item in
            var searchableStrings = item._searchStrings.map { $0.lowercased() }
            for localizableString in item._searchLocalizedStrings {
                switch localizableString {
                case .localized(let localizedString):
                    searchableStrings.append(contentsOf: localizedString.allAvailableLocales.compactMap {
                        localizedString.forLocale($0)?.lowercased()
                    })
                case .unlocalized(let string):
                    if let string {
                        searchableStrings.append(string.lowercased())
                    }
                }
            }

            return tokens.allSatisfy { token in
                if token.hasPrefix("#"),
                   let intToken = Int(token.dropFirst()),
                   (item.id as? Int) == intToken {
                    return true
                }
                return searchableStrings.contains { $0.contains(token) }
            }
        }
    }
}

extension Card: SekaiSearchable {
    /// The localized strings searched across all available locales for this record.
    public var _searchLocalizedStrings: [LocalizableData<String>] {
        [self.title]
    }
}

extension Event: SekaiSearchable {
    public var _searchStrings: [String] {
        SekaiLocale.allCases.compactMap({ self.focusCharacterLabel(in: $0) })
    }
    
    /// The localized strings searched across all available locales for this record.
    public var _searchLocalizedStrings: [LocalizableData<String>] {
        [self.title]
    }
}

extension Song: SekaiSearchable {
    /// The localized strings searched across all available locales for this record.
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
