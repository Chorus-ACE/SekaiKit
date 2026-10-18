import Foundation
import SwiftyJSON
import XCTest
@testable import SekaiKit

final class GachaStickerTests: XCTestCase {
    private func gacha(_ localeName: String, card: Int, rate: Double) throws -> Gacha {
        try XCTUnwrap(Gacha(json: JSON([
            "id": 7, "name": localeName, "gachaType": "ceil", "assetbundleName": "ab_gacha_7",
            "startAt": 1700000000123 as Int64, "endAt": 1700100000123 as Int64,
            "isShowPeriod": true, "spinLimit": 0,
            "gachaInformation": ["summary": "Featured cards", "description": "Rules"],
            "gachaDetails": [["id": 1, "cardId": card, "weight": 400, "isWish": true, "fixedBonusWeight": 0]],
            "gachaPickups": [["cardId": card]],
            "gachaCardRarityRates": [["id": 1, "cardRarityType": "rarity_4", "lotteryType": "normal", "rate": rate]],
            "gachaBehaviors": [["id": 1, "gachaBehaviorType": "normal", "costResourceType": "jewel", "costResourceQuantity": 300, "spinCount": 1]]
        ])))
    }

    func testRegionalGachaPoolsRatesAndCostsRemainSeparate() throws {
        let jp = try gacha("日本語", card: 1, rate: 3)
        var en = try gacha("English", card: 2, rate: 6)
        en.configuration = en.configuration.map { value in
            var value = value
            value?.behaviors[0].costQuantity = 100
            return value
        }
        let merged = try XCTUnwrap(Gacha.combineLocalizations([.jp: jp, .en: en], defaultLocale: .en))
        XCTAssertEqual(merged.title.localizedData?.jp, "日本語")
        XCTAssertEqual(merged.configuration.localizedData?.jp?.pickupCardIDs, [1])
        XCTAssertEqual(merged.configuration.localizedData?.en?.pickupCardIDs, [2])
        XCTAssertEqual(merged.configuration.localizedData?.jp?.rarityRates.first?.rate, 3)
        XCTAssertEqual(merged.configuration.localizedData?.en?.rarityRates.first?.rate, 6)
        XCTAssertEqual(merged.configuration.localizedData?.en?.behaviors.first?.costQuantity, 100)
        XCTAssertEqual(jp.configuration.majorValue?.spinLimit, 0)
        XCTAssertNil(jp.configuration.majorValue?.dailySpinLimit)
        XCTAssertEqual(jp.startDate.majorValue!.timeIntervalSince1970, 1700000000.123, accuracy: 0.001)
        XCTAssertEqual(Gacha(fromCache: merged.dataForCache), merged)
        XCTAssertEqual(merged.availableLocales, [.jp, .en])
        // Banner paths are derived from the ID even when regional pool data is absent.
        XCTAssertEqual(merged.bannerImageURL(in: .kr)?.absoluteString,
                       "https://storage.sekai.best/sekai-kr-assets/home/banner/banner_gacha7/banner_gacha7.webp")
        XCTAssertTrue(merged.bannerImageURL(in: .jp)!.path.contains("banner_gacha7/banner_gacha7.webp"))
    }

    func testStickerKeepsMissingDatesAndMultipleCharacters() throws {
        let jp = try XCTUnwrap(Sticker(json: JSON(["id": 5, "name": "ミク", "stampType": "illustration", "assetbundleName": "stamp0005", "characterId1": 21, "characterId2": 21])))
        let en = try XCTUnwrap(Sticker(json: JSON(["id": 5, "name": "Miku", "stampType": "future_category", "assetbundleName": "stamp0005_en", "characterId1": 21, "characterId2": 22, "description": "A special reward", "archivePublishedAt": 1700000000000 as Int64])))
        let merged = try XCTUnwrap(Sticker.combineLocalizations([.jp: jp, .en: en], defaultLocale: .jp))
        XCTAssertEqual(merged.characterIDs.localizedData?.jp, [21])
        XCTAssertEqual(merged.characterIDs.localizedData?.en, [21, 22])
        XCTAssertNil(merged.releaseDate.localizedData?.jp)
        XCTAssertEqual(merged.type.localizedData?.en, .unknown)
        XCTAssertEqual(Sticker(fromCache: merged.dataForCache), merged)
        XCTAssertTrue(merged.imageURL(in: .en)!.path.contains("stamp0005_en/stamp0005_en.webp"))
        XCTAssertNil(merged.imageURL(in: .cn))
        XCTAssertNil(Gacha(json: JSON(["error": "not a record"])))
        XCTAssertNil(Sticker(json: JSON(["error": "not a record"])))
    }

    func testSearchLocaleAndCharacterFiltersAndSortOrder() throws {
        let first = try gacha("First Pool", card: 1, rate: 3)
        var second = first
        second.id = 8
        second.title = .unlocalized("Second Pool")
        let jp = try XCTUnwrap(Gacha.combineLocalizations([.jp: first], defaultLocale: .jp))
        let en = try XCTUnwrap(Gacha.combineLocalizations([.en: second], defaultLocale: .en))
        XCTAssertEqual([jp, en].search(for: "FIRST pool").map(\.id), [7])
        XCTAssertEqual([jp, en].search(for: "#8").map(\.id), [8])
        let region = SekaiFilter(["locale": [SekaiLocale.jp.rawIntValue]])
        XCTAssertEqual([jp, en].filter(withSekaiFilter: region).map(\.id), [7])
        XCTAssertEqual([en, jp].sorted(withSekaiSorter: .init(keyword: .releaseDate(in: .jp), direction: .descending)).map(\.id), [7, 8])
        let text = try XCTUnwrap(Sticker(json: JSON(["id": 1, "name": "Hello", "stampType": "text"])))
        let merged = try XCTUnwrap(Sticker.combineLocalizations([.jp: text], defaultLocale: .jp))
        XCTAssertTrue(merged._matches(SekaiFilter(["character": [nil]])))
        XCTAssertFalse(merged._matches(SekaiFilter(["character": [21]])))
        XCTAssertTrue(merged._matches(SekaiFilter(forKeys: Sticker.filterKeys)))
    }

    func testAllFiveDownloadedMasterDatabasesWhenProvided() throws {
        guard let directory = ProcessInfo.processInfo.environment["SEKAI_MASTER_TEST_DATA"] else {
            throw XCTSkip("Set SEKAI_MASTER_TEST_DATA to downloaded regional JSON fixtures.")
        }
        for locale in SekaiLocale.allCases {
            for kind in ["gachas", "stamps"] {
                let data = try Data(contentsOf: URL(filePath: directory).appending(path: "\(locale.rawValue)-\(kind).json"))
                let json = try JSON(data: data)
                let records = try XCTUnwrap(json.array)
                XCTAssertFalse(records.isEmpty)
                if kind == "gachas" {
                    let parsed = records.compactMap(Gacha.init(json:))
                    XCTAssertEqual(parsed.count, records.count, "\(locale) gachas")
                    XCTAssertEqual(Set(parsed.map(\.id)).count, parsed.count)
                } else {
                    let parsed = records.compactMap(Sticker.init(json:))
                    XCTAssertEqual(parsed.count, records.count, "\(locale) stamps")
                    XCTAssertEqual(Set(parsed.map(\.id)).count, parsed.count)
                }
            }
        }
    }
    func testMergedMasterDataHasStableUniqueIdentitiesWhenProvided() throws {
        guard let directory = ProcessInfo.processInfo.environment["SEKAI_MASTER_TEST_DATA"] else {
            throw XCTSkip("Set SEKAI_MASTER_TEST_DATA to downloaded regional JSON fixtures.")
        }
        var regional: [SekaiLocale: [Gacha]] = [:]
        for locale in SekaiLocale.allCases {
            let url = URL(filePath: directory).appending(path: "\(locale.rawValue)-gachas.json")
            regional[locale] = try JSON(data: Data(contentsOf: url)).arrayValue.compactMap(Gacha.init(json:))
        }
        let merged = mergeCollections(regional, defaultLocale: .jp)
        let ids = Set(merged.map(\.id))
        XCTAssertEqual(ids.count, merged.count)
        XCTAssertEqual(ids, Set(regional.values.flatMap { $0.map(\.id) }))
        for locale in SekaiLocale.allCases {
            XCTAssertEqual(merged.filter { $0.availableLocales.contains(locale) }.count, regional[locale]?.count)
        }
        // Compare the former SwiftUI row identity with the new ID on real pools.
        let start = ContinuousClock.now
        let fullIdentities = Set(merged)
        let fullDuration = start.duration(to: .now)
        let idStart = ContinuousClock.now
        let stableIdentities = Set(merged.map(\.id))
        let idDuration = idStart.duration(to: .now)
        XCTAssertEqual(fullIdentities.count, stableIdentities.count)
        print("Gacha identity benchmark (\(merged.count) records): full object \(fullDuration), ID \(idDuration)")
    }

    func testGachaFiltersUseOneRegionalEditionAndRespectDateBoundaries() throws {
        var jp = try gacha("JP", card: 1, rate: 3)
        var en = try gacha("EN", card: 1, rate: 3)
        let start = Date(timeIntervalSince1970: 100)
        let end = Date(timeIntervalSince1970: 200)
        jp.startDate = .unlocalized(start)
        jp.endDate = .unlocalized(end)
        en.startDate = .unlocalized(Date(timeIntervalSince1970: 300))
        en.endDate = .unlocalized(Date(timeIntervalSince1970: 400))
        en.type = .normal
        en.configuration = en.configuration.map { value in
            var value = value!
            value.behaviors[0].costResourceType = "gacha_ticket"
            return value
        }
        let merged = try XCTUnwrap(Gacha.combineLocalizations([.jp: jp, .en: en], defaultLocale: .jp))
        let jpOnly: Set<Int?> = [SekaiLocale.jp.rawIntValue]
        XCTAssertTrue(merged.matches(.init(["locale": jpOnly, "gachaStatus": [0]]), at: start.addingTimeInterval(-1)))
        XCTAssertTrue(merged.matches(.init(["locale": jpOnly, "gachaStatus": [1]]), at: start))
        XCTAssertFalse(merged.matches(.init(["locale": jpOnly, "gachaStatus": [1]]), at: end))
        XCTAssertTrue(merged.matches(.init(["locale": jpOnly, "gachaStatus": [2]]), at: end))
        // Type is shared and comes from the default edition; costs and dates remain regional.
        XCTAssertEqual(merged.type, .ceil)
        XCTAssertTrue(merged.matches(.init(["gachaType": [Gacha.GachaType.ceil.filterValue], "gachaCost": [3]]), at: start))
        XCTAssertFalse(merged.matches(.init(["gachaType": [Gacha.GachaType.normal.filterValue], "gachaCost": [3]]), at: start))
        XCTAssertFalse(merged.matches(.init(["locale": jpOnly, "gachaCost": [3]]), at: start))
        XCTAssertFalse(merged.matches(.init(["gachaStatus": [1], "gachaCost": [3]]), at: start))
        XCTAssertTrue(merged.matches(.init(["gachaStatus": [0], "gachaCost": [3]]), at: start))
        XCTAssertTrue(merged.matches(.init(forKeys: Gacha.filterKeys), at: start))
        XCTAssertFalse(merged.matches(.init(["gachaType": []]), at: start))
    }

    func testStickerTypeAndMultipleCharacterMatching() throws {
        let sticker = try XCTUnwrap(Sticker(json: JSON(["id": 10, "name": "Duo", "stampType": "illustration", "characterId1": 21, "characterId2": 22])))
        XCTAssertTrue(sticker._matches(.init(["stickerType": [0], "character": [21, 22], "characterMatchingStrategy": [1]])))
        XCTAssertFalse(sticker._matches(.init(["character": [21, 23], "characterMatchingStrategy": [1]])))
        XCTAssertTrue(sticker._matches(.init(["character": [21, 23], "characterMatchingStrategy": [0]])))
        XCTAssertFalse(sticker._matches(.init(["stickerType": [1]])))
        XCTAssertFalse(sticker._matches(.init(["character": [], "characterMatchingStrategy": [1]])))
        let unknown = try XCTUnwrap(Sticker(json: JSON(["id": 11, "name": "Future", "stampType": "future_type"])))
        XCTAssertTrue(unknown._matches(.init(forKeys: Sticker.filterKeys)))
        XCTAssertTrue(unknown._matches(.init(["stickerType": [nil], "character": [nil], "characterMatchingStrategy": [1]])))
    }

    func testStartDateSortKeepsMissingDatesLast() throws {
        var first = try gacha("alpha", card: 1, rate: 3)
        var second = first
        second.id = 8
        second.title = .unlocalized("Beta")
        second.startDate = .unlocalized(Date(timeIntervalSince1970: 1800000000))
        var missing = first
        missing.id = 9
        missing.startDate = nil
        first = try XCTUnwrap(Gacha.combineLocalizations([.jp: first], defaultLocale: .jp))
        second = try XCTUnwrap(Gacha.combineLocalizations([.jp: second], defaultLocale: .jp))
        let items = [missing, second, first]
        XCTAssertEqual(items.sorted(withSekaiSorter: .init(keyword: .releaseDate(in: .jp), direction: .ascending)).map(\.id), [7, 8, 9])
        XCTAssertEqual(items.sorted(withSekaiSorter: .init(keyword: .releaseDate(in: .jp), direction: .descending)).map(\.id), [8, 7, 9])
    }

    func testNormalAndGuaranteedRatesAndIncompletePools() throws {
        var configuration = try XCTUnwrap(gacha("Pool", card: 1, rate: 3).configuration.majorValue)
        configuration.rarityRates = [
            .init(id: 1, rarityType: "rarity_2", lotteryType: "normal", rate: 88.5),
            .init(id: 2, rarityType: "rarity_3", lotteryType: "normal", rate: 8.5),
            .init(id: 3, rarityType: "rarity_4", lotteryType: "normal", rate: 3)
        ]
        configuration.cards = [
            .init(id: 1, cardID: 1, weight: 1, isWish: false),
            .init(id: 2, cardID: 2, weight: 3, isWish: false),
            .init(id: 3, cardID: 3, weight: 1, isWish: false)
        ]
        let rarities: [Int: Card.Rarity] = [1: .four, 2: .four, 3: .three]
        XCTAssertEqual(try XCTUnwrap(configuration.probability(of: configuration.cards[0], cardRarities: rarities)), 0.0075, accuracy: 0.000001)
        XCTAssertEqual(configuration.rates(guaranteeing: .three)?.map(\.rate), [0, 97, 3])
        XCTAssertEqual(configuration.rates(guaranteeing: .four)?.map(\.rate), [0, 0, 100])
        XCTAssertEqual(try XCTUnwrap(configuration.probability(of: configuration.cards[0], cardRarities: rarities, guaranteeing: .four)), 0.25, accuracy: 0.000001)
        XCTAssertNil(configuration.probability(of: configuration.cards[0], cardRarities: [1: .four]))
        configuration.cards[0].weight = 0
        configuration.cards[1].weight = 0
        XCTAssertNil(configuration.probability(of: configuration.cards[0], cardRarities: rarities))
        configuration.cards[0].weight = 1
        configuration.selectsCharacter = true
        XCTAssertNil(configuration.probability(of: configuration.cards[0], cardRarities: rarities))
        configuration.selectsCharacter = false
        configuration.wishSelectCount = 10
        XCTAssertNil(configuration.probability(of: configuration.cards[0], cardRarities: rarities))
        configuration.rarityRates[2].lotteryType = "categorized_wish"
        XCTAssertNil(configuration.rates(guaranteeing: .four))
        XCTAssertEqual(configuration.rates()?.last?.lotteryType, "categorized_wish")
    }

    func testPreviewFallsBackWithinEditionBeforeOtherAvailableEditions() throws {
        let jp = try gacha("JP", card: 1, rate: 3)
        let en = try gacha("EN", card: 1, rate: 3)
        let merged = try XCTUnwrap(Gacha.combineLocalizations([.jp: jp, .en: en], defaultLocale: .jp))
        XCTAssertEqual(merged.previewImageURLs(in: .en), [merged.bannerImageURL(in: .en), merged.logoImageURL(in: .en), merged.bannerImageURL(in: .jp), merged.logoImageURL(in: .jp)].compactMap { $0 })
        XCTAssertTrue(merged.previewImageURLs().allSatisfy { !$0.path.contains("sekai-kr-assets") })
    }

    func testStickerNormalizesUnavailableDescriptionAndPlaceholderDates() throws {
        for description in ["", " \n\t "] {
            let sticker = try XCTUnwrap(Sticker(json: JSON(["id": 1, "name": "Test", "description": description])))
            XCTAssertTrue(sticker.description.isEmpty)
        }
        for timestamp: Int64 in [1230768000000, 1233295200000, 1262303999999] {
            let sticker = try XCTUnwrap(Sticker(json: JSON(["id": 1, "name": "Test", "archivePublishedAt": timestamp])))
            XCTAssertTrue(sticker.releaseDate.isEmpty)
            XCTAssertTrue(try XCTUnwrap(Sticker(fromCache: sticker.dataForCache)).releaseDate.isEmpty)
        }
        for timestamp: Int64 in [1230767999999, 1262304000000, 1700000000000] {
            let sticker = try XCTUnwrap(Sticker(json: JSON(["id": 1, "name": "Test", "archivePublishedAt": timestamp, "description": "  Reward  "])))
            XCTAssertNotNil(sticker.releaseDate.majorValue)
            XCTAssertEqual(sticker.description.majorValue, "Reward")
        }
    }

    func testTypedCategoriesProvideNamesAndRegionalFilters() throws {
        for type in Sticker.StickerType.allCases {
            let sticker = try XCTUnwrap(Sticker(json: JSON(["id": 1, "name": "Test", "stampType": type.rawValue])))
            XCTAssertEqual(sticker.type.majorValue, type)
            XCTAssertEqual(Sticker(fromCache: sticker.dataForCache), sticker)
            XCTAssertFalse(type.localizedName.hasPrefix("Sticker.type."))
            XCTAssertTrue(sticker._matches(.init(["stickerType": [type.filterValue]])))
        }
        for type in Gacha.GachaType.allCases {
            let gacha = try XCTUnwrap(Gacha(json: JSON(["id": 1, "name": "Test", "gachaType": type.rawValue])))
            XCTAssertEqual(gacha.type, type)
            XCTAssertEqual(Gacha(fromCache: gacha.dataForCache), gacha)
            XCTAssertFalse(type.localizedName.hasPrefix("Gacha.type."))
            XCTAssertTrue(gacha._matches(.init(["gachaType": [type.filterValue]])))
        }
    }

    func testSortMenusAlwaysEndWithID() {
        XCTAssertEqual(SekaiSorter.Keyword.allCases.last, .id)
        for options in [Gacha.applicableSortingTypes, Sticker.applicableSortingTypes, Song.applicableSortingTypes, Event.applicableSortingTypes, Card.applicableSortingTypes] {
            XCTAssertEqual(options.last, .id)
            XCTAssertEqual(Set(options).sorted().last, .id)
        }
    }

    func testLegacyStickerCacheIsReloadedForDateNormalization() throws {
        let sticker = try XCTUnwrap(Sticker(json: JSON(["id": 1, "name": "Test", "archivePublishedAt": 1700000000000 as Int64])))
        var legacy = try XCTUnwrap(PropertyListSerialization.propertyList(from: sticker.dataForCache, format: nil) as? [String: Any])
        legacy["archivePublishedDate"] = legacy.removeValue(forKey: "releaseDate")
        let data = try PropertyListSerialization.data(fromPropertyList: legacy, format: .binary, options: 0)
        XCTAssertNil(Sticker(fromCache: data))
    }

}
