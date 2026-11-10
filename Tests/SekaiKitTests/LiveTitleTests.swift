import Foundation
import XCTest
import SwiftProtobuf
@testable import SekaiKit

final class LiveTitleTests: XCTestCase {
    func testTitleRegionalLevelsPresenceAndCache() throws {
        let jp = try Honor(protobuf: _HonorRecord(jsonString: #"{"id":1,"name":"JP","assetbundleName":"jp","honorRarity":"future","levels":[{"level":1,"bonus":0,"description":""}]}"#))
        let en = try Honor(protobuf: _HonorRecord(jsonString: #"{"id":1,"name":"EN","assetbundleName":"en","levels":[]}"#))
        let item = try XCTUnwrap(Honor.combineLocalizations([.jp: jp, .en: en], defaultLocale: .jp))
        XCTAssertEqual(item.record.localizedData?[.jp]?.levels?.first?.bonus, 0)
        XCTAssertEqual(item.record.localizedData?[.jp]?.levels?.first?.description, "")
        XCTAssertEqual(item.record.localizedData?[.en]?.levels, [])
        XCTAssertNil(item.record.localizedData?[.kr])
        XCTAssertNil(item.startDate.majorValue)
        XCTAssertEqual(item.record.localizedData?[.en]?.assetBundleName, "en")
        XCTAssertEqual(Honor(fromCache: item.dataForCache), item)
        XCTAssertTrue(item._matches(SekaiFilter(["locale": [SekaiLocale.en.rawIntValue]])))
        XCTAssertFalse(item._matches(SekaiFilter(["locale": [SekaiLocale.kr.rawIntValue]])))
    }
    func testVirtualLivePreservesAbsentDatesAndUnknownCategory() throws {
        let item = try VirtualLive(protobuf: _VirtualLiveRecord(jsonString: #"{"id":1,"name":"Live","virtualLiveType":"future","startAt":0,"virtualLiveSchedules":[{"id":2,"startAt":0,"isAfterEvent":false}],"virtualLiveSetlists":[{"musicId":5}]}"#))
        XCTAssertEqual(item.startDate.majorValue, Date(timeIntervalSince1970: 0))
        XCTAssertNil(item.record.majorValue?.endAt)
        XCTAssertEqual(item.record.majorValue?.virtualLiveType, "future")
        XCTAssertEqual(item.record.majorValue?.virtualLiveSchedules?.first?.isAfterEvent, false)
        XCTAssertEqual(item.record.majorValue?.virtualLiveSetlists?.first?.musicID, 5)
        XCTAssertEqual(VirtualLive(fromCache: item.dataForCache), item)
        XCTAssertEqual(VirtualLive.applicableSortingTypes.first, .releaseDate(in: .jp))
        XCTAssertEqual(VirtualLive.applicableSortingTypes.last, .id)
    }
    func testArtworkUsesTheRequestedRegionalBundle() throws {
        let jp = try VirtualLive(protobuf: _VirtualLiveRecord(jsonString: #"{"id":1,"name":"JP","assetbundleName":"jp_live"}"#))
        let en = try VirtualLive(protobuf: _VirtualLiveRecord(jsonString: #"{"id":1,"name":"EN","assetbundleName":"en_live"}"#))
        let live = try XCTUnwrap(VirtualLive.combineLocalizations([.jp: jp, .en: en], defaultLocale: .jp))
        XCTAssertTrue(try XCTUnwrap(live.bannerImageURL(in: .en)).path.hasSuffix("en_live/en_live.webp"))
        XCTAssertTrue(live.previewImageURLs(in: .en).allSatisfy { $0.path.contains("sekai-en-assets") })
        XCTAssertTrue(live.previewImageURLs(in: .kr).isEmpty)
        XCTAssertNil(live.endDate.majorValue)
        let title = try Honor(protobuf: _HonorRecord(jsonString: #"{"id":1,"name":"JP","assetbundleName":"base","levels":[{"level":2,"assetbundleName":"level_two"}]}"#))
        XCTAssertTrue(try XCTUnwrap(title.imageURL(level: 2)).path.hasSuffix("level_two/degree_main.webp"))
    }

    func testTitleArtworkUsesGroupLayersAndLevelOnlyAssets() throws {
        let ranked = try Honor(protobuf: _HonorRecord(jsonString: #"{"id":1870,"name":"Master","assetbundleName":"common/tier_25","honorRarity":"highest","group":{"id":217,"honorType":"rank_match","backgroundAssetbundleName":"season_2022_summer"}}"#))
        let rank = try XCTUnwrap(ranked.artwork(in: .en))
        XCTAssertTrue(rank.backgroundURLs[0].path.hasSuffix("rank_live/honor/season_2022_summer/degree_main.webp"))
        XCTAssertTrue(rank.overlayURLs[0].path.hasSuffix("rank_live/honor/common/tier_25/main.webp"))
        XCTAssertTrue(rank.backgroundURLs.allSatisfy { $0.path.contains("sekai-en-assets") })
        let achievement = try Honor(protobuf: _HonorRecord(jsonString: #"{"id":3009,"name":"Easy","honorMissionType":"easy_full_combo","levels":[{"level":1,"assetbundleName":"honor_3009_100","honorRarity":"low"},{"level":11,"assetbundleName":"honor_3009_200","honorRarity":"middle"}]}"#))
        XCTAssertTrue(try XCTUnwrap(achievement.imageURL()).path.hasSuffix("honor_3009_100/degree_main.webp"))
        XCTAssertTrue(try XCTUnwrap(achievement.imageURL(level: 11)).path.hasSuffix("honor_3009_200/degree_main.webp"))
        XCTAssertEqual(achievement.artwork(level: 11)?.rarity, .middle)
        XCTAssertTrue(try XCTUnwrap(achievement.artwork()?.overlayURLs.first).path.hasSuffix("scroll.webp"))
        let event = try Honor(protobuf: _HonorRecord(jsonString: #"{"id":1,"name":"TOP100","assetbundleName":"ranking_cp1","group":{"honorType":"event","backgroundAssetbundleName":"event_background"}}"#))
        XCTAssertEqual(event.artwork()?.overlayRect.width, 1)
        XCTAssertTrue(try XCTUnwrap(event.imageURL()).path.hasSuffix("event_background/degree_main.webp"))
        let en = try Honor(protobuf: _HonorRecord(jsonString: #"{"id":1,"name":"EN","assetbundleName":"en"}"#))
        let combined = try XCTUnwrap(Honor.combineLocalizations([.en: en], defaultLocale: .en))
        XCTAssertNil(combined.artwork(in: .kr))
    }

    func testFullRegionalGeneratedArchivesWhenProvided() throws {
        guard let folder = ProcessInfo.processInfo.environment["SEKAI_LIVE_TITLE_FIXTURES"] else { throw XCTSkip("Full upstream fixtures are optional") }
        let directory = URL(filePath: folder).appending(path: "generated")
        let titles = try _HonorList(serializedBytes: Data(contentsOf: directory.appending(path: "honor.proto")))
        let lives = try _VirtualLiveList(serializedBytes: Data(contentsOf: directory.appending(path: "virtual_live.proto")))
        for locale in SekaiLocale.allCases {
            let titleModels = try titles.items(in: locale).map { try Honor(protobuf: $0) }
            let liveModels = try lives.items(in: locale).map { try VirtualLive(protobuf: $0) }
            XCTAssertFalse(titleModels.isEmpty)
            XCTAssertFalse(liveModels.isEmpty)
        }
    }
}
