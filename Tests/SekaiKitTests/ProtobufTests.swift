import Foundation
import XCTest
import SwiftProtobuf
@testable import SekaiKit

final class ProtobufTests: XCTestCase {
    func testEventTypeFallbackFiltersAndAssetURLs() throws {
        let event = Event(protobuf: .with {
            $0.id = 999
            $0.title = "Future"
            $0.eventType = "future_type"
            $0.assetbundleName = "event_example"
        })
        XCTAssertEqual(event.eventType, .marathon)
        XCTAssertEqual(Event.EventType.filterKey.id, "eventType")
        XCTAssertFalse(event._matches(.init(["eventType": [nil]])))
        XCTAssertTrue(event._matches(.init(["eventType": [0]])))
        XCTAssertFalse(event.eventType.localizedName.hasPrefix("Event.type."))
        XCTAssertFalse(Event.EventType.filterKey.title.hasPrefix("Filter.key."))
        XCTAssertEqual(event.logoImageURL, event.logoImageURL(in: nil))
        XCTAssertTrue(event.logoImageURL.path.hasSuffix("/logo/logo.webp"))
        XCTAssertEqual(event.backgroundMusicURL.scheme, "https")
        XCTAssertEqual(event.backgroundMusicURL.host, "storage.sekai.best")
    }

    func testEventFocusMetadataAndOldArchiveCompatibility() throws {
        let wire = _Event.with {
            $0.id = 150
            $0.focusCharacterID = 19
            $0.focusCharacterIndex = 5
        }
        let event = Event(protobuf: try _Event(serializedBytes: wire.serializedData()))
        XCTAssertEqual(event.focusCharacterID, 19)
        XCTAssertEqual(event.focusCharacterIndex, 5)
        let legacy = Event(protobuf: .with { $0.id = 150 })
        XCTAssertNil(legacy.focusCharacterID)
        XCTAssertNil(legacy.focusCharacterIndex)
        let restored = try JSONDecoder().decode(Event.self, from: JSONEncoder().encode(event))
        XCTAssertEqual(restored.focusCharacterID, 19)
        XCTAssertEqual(restored.focusCharacterIndex, 5)
    }

    func testEventOutlinePreservesPresenceAndOldArchiveCompatibility() throws {
        let wire = _Event.with {
            $0.id = 150
            $0.outline = "紹介\n二行目"
        }
        let event = Event(protobuf: try _Event(serializedBytes: wire.serializedData()))
        XCTAssertEqual(event.outline.majorValue, "紹介\n二行目")
        let restored = try JSONDecoder().decode(Event.self, from: JSONEncoder().encode(event))
        XCTAssertEqual(restored.outline, event.outline)
        let empty = Event(protobuf: .with { $0.id = 150; $0.outline = "" })
        XCTAssertEqual(empty.outline.majorValue, "")
        // Field 1 only: bytes produced before outline was added to the schema.
        let legacy = Event(protobuf: try _Event(serializedBytes: [UInt8(0x08), 0x01]))
        XCTAssertEqual(legacy.id, 1)
        XCTAssertNil(legacy.outline.majorValue)
    }

    func testCardMappingPreservesPresenceAndMilliseconds() throws {
        var wire = _Card()
        wire.id = 1
        wire.characterID = 1
        wire.rarity = "rarity_4"
        wire.attribute = "cool"
        wire.releaseAt = 1700000000123
        wire.gachaPhrase = "-"
        wire.specialTrainingSkillID = 0
        wire.cardParameters = [.with { $0.type = "param1"; $0.level = 60; $0.power = 2000 }]
        wire.specialTrainingPower1BonusFixed = 100
        let card = Card(protobuf: try _Card(serializedBytes: wire.serializedData()))
        XCTAssertEqual(card.unit, .leoNeed)
        XCTAssertEqual(card.rarity, .four)
        XCTAssertEqual(card.attribute, .cool)
        XCTAssertEqual(card.releaseDate.majorValue!.timeIntervalSince1970, 1700000000.123, accuracy: 0.0001)
        XCTAssertEqual(card.specialTrainingSkillID, 0)
        XCTAssertNil(card.name.majorValue)
        XCTAssertNil(card.archivePublishedDate.majorValue)
        XCTAssertNil(card.gachaPhrase.majorValue)
        XCTAssertEqual(card.maxPower, 2100)
        XCTAssertTrue(card.canTrain)
        wire.clearSpecialTrainingSkillID()
        XCTAssertNil(Card(protobuf: wire).specialTrainingSkillID)
    }

    func testCharacterAndEventMapping() {
        let character = Character(protobuf: .with {
            $0.id = 21; $0.givenName = "ミク"; $0.birthday = "8月31日"
            $0.height = 158; $0.unit = "piapro"; $0.school = ""
            $0.colorInfo = [.with { $0.id = 21; $0.unit = "piapro"; $0.mainColor = "#33CCBB" }]
        })
        XCTAssertEqual(character.birthday?.month, 8)
        XCTAssertEqual(character.birthday?.day, 31)
        XCTAssertNil(character.familyName.majorValue)
        XCTAssertEqual(character.school.majorValue, "")
        XCTAssertEqual(character.height.value, 158)
        XCTAssertNotNil(character.color)
        let event = Event(protobuf: .with {
            $0.id = 7; $0.eventType = "world_bloom"; $0.bgmAssetbundleName = "separate_bgm"
            $0.characters = [21, 22]; $0.attribute = "cool"; $0.attributeBonus = 0
            $0.eventRankingRewardRanges = [.with {
                $0.upperBound = 1; $0.lowerBound = 100; $0.includeLowerBound = true
                $0.eventRankingRewards = [.with { $0.resourceBoxID = 42 }]
            }]
        })
        XCTAssertEqual(event.eventType, .worldLink)
        XCTAssertEqual(event.attributeBonus, 0)
        XCTAssertNil(event.startDate.majorValue)
        XCTAssertEqual(event.bgmAssetbundleName, "separate_bgm")
        XCTAssertEqual(event.eventRankingRewardRanges[0].eventRankingRewards[0].resourceBoxId, 42)
        XCTAssertNil(event.eventRankingRewardRanges[0].eventRankingRewards[0].rewardConditionType)
    }

    func testPublicListsMergeFiveLocalesAndLoadExtendedEvent() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var cards = _CardList()
        cards.jp = [.with { $0.id = 1; $0.name = "日本語" }]
        cards.en = [.with { $0.id = 1; $0.name = "English" }]
        cards.tc = [.with { $0.id = 1; $0.name = "繁體中文" }]
        cards.cn = [.with { $0.id = 1; $0.name = "简体中文" }]
        cards.kr = [.with { $0.id = 1; $0.name = "한국어" }]
        try writeProtobufArchive(try cards.serializedData(), to: directory.appending(path: "card.aar"))
        let events = _EventList.with {
            $0.jp = [.with { $0.id = 908765; $0.title = "Event"; $0.outline = "日本語"; $0.cardIds = [1]; $0.musicIds = [12] }]
        }
        var localizedEvents = events
        localizedEvents.en = [.with { $0.id = 908765; $0.outline = "English" }]
        localizedEvents.tc = [.with { $0.id = 908765; $0.outline = "繁體中文" }]
        localizedEvents.cn = [.with { $0.id = 908765; $0.outline = "简体中文" }]
        localizedEvents.kr = [.with { $0.id = 908765; $0.outline = "한국어" }]
        try writeProtobufArchive(try localizedEvents.serializedData(), to: directory.appending(path: "event.aar"))
        await SekaiProtobuf.$baseURL.withValue(directory) {
            let merged = await Card.all()
            XCTAssertEqual(merged?.count, 1)
            XCTAssertEqual(merged?.first?.name.localizedData?.jp, "日本語")
            XCTAssertEqual(merged?.first?.name.localizedData?.en, "English")
            XCTAssertEqual(merged?.first?.name.localizedData?.tw, "繁體中文")
            XCTAssertEqual(merged?.first?.name.localizedData?.cn, "简体中文")
            XCTAssertEqual(merged?.first?.name.localizedData?.kr, "한국어")
            let event = await ExtendedEvent(id: 908765)
            XCTAssertEqual(event?.cards, [1])
            XCTAssertEqual(event?.songs, [12])
            XCTAssertEqual(event?.event.outline.localizedData?.jp, "日本語")
            XCTAssertEqual(event?.event.outline.localizedData?.en, "English")
            XCTAssertEqual(event?.event.outline.localizedData?.tw, "繁體中文")
            XCTAssertEqual(event?.event.outline.localizedData?.cn, "简体中文")
            XCTAssertEqual(event?.event.outline.localizedData?.kr, "한국어")
        }
    }

    func testMissingAndMalformedFilesReturnNil() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("not protobuf".utf8).write(to: directory.appending(path: "event.aar"))
        try Data().write(to: directory.appending(path: "card.aar"))
        await SekaiProtobuf.$baseURL.withValue(directory) {
            let characters = await Character.allInLocale(.jp)
            let events = await Event.allInLocale(.jp)
            let cards = await Card.allInLocale(.jp)
            let allCards = await Card.all()
            XCTAssertNil(characters)
            XCTAssertNil(events)
            XCTAssertNil(cards)
            XCTAssertNil(allCards)
        }
    }

    func testPreloadingUsesArchiveURLAndArchiveBytes() async throws {
        let bytes = try _CardList.with { $0.jp = [.with { $0.id = 77; $0.name = "preloaded" }] }.serializedData()
        let archive = try protobufArchiveFixture([("card.proto", bytes)])
        await SekaiCache.$_dataFromPreloaded.withValue({ url in
            XCTAssertEqual(url.lastPathComponent, "card.aar")
            return archive
        }) {
            let cards = await Card.allInLocale(.jp)
            XCTAssertEqual(cards?.first?.name.majorValue, "preloaded")
        }
    }

    func testCachedListsRespectSourceAndRealTimeRefresh() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let firstSource = root.appending(path: "first")
        let secondSource = root.appending(path: "second")
        for directory in [firstSource, secondSource] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        defer { try? FileManager.default.removeItem(at: root) }
        let first = _CardList.with { $0.jp = [.with { $0.id = 1; $0.name = "first" }] }
        let second = _CardList.with { $0.jp = [.with { $0.id = 1; $0.name = "second" }] }
        try writeProtobufArchive(try first.serializedData(), to: firstSource.appending(path: "card.aar"))
        try writeProtobufArchive(try second.serializedData(), to: secondSource.appending(path: "card.aar"))
        try await SekaiProtobuf.$baseURL.withValue(firstSource) {
            let initial = await Card.allWithCache()
            XCTAssertEqual(initial?.first?.name.localizedData?.jp, "first")
            try writeProtobufArchive(try second.serializedData(), to: firstSource.appending(path: "card.aar"))
            let refreshed = await Card.allWithCache(trait: .realTime)
            XCTAssertEqual(refreshed?.first?.name.localizedData?.jp, "second")
        }
        await SekaiProtobuf.$baseURL.withValue(secondSource) {
            let independent = await Card.allWithCache()
            XCTAssertEqual(independent?.first?.name.localizedData?.jp, "second")
        }
    }

    func testGeneratedAssetsWhenProvided() async throws {
        guard let path = ProcessInfo.processInfo.environment["SEKAI_PROTOBUF_TEST_ASSETS"] else {
            throw XCTSkip("Set SEKAI_PROTOBUF_TEST_ASSETS to JSON2Proto's output to verify live data.")
        }
        await SekaiProtobuf.$baseURL.withValue(URL(filePath: path)) {
            for locale in SekaiLocale.allCases {
                let characters = await Character.allInLocale(locale)
                let events = await Event.allInLocale(locale)
                let cards = await Card.allInLocale(locale)
                XCTAssertGreaterThan(characters?.count ?? 0, 20)
                XCTAssertGreaterThan(events?.count ?? 0, 0)
                XCTAssertGreaterThan(cards?.count ?? 0, 0)
                XCTAssertEqual(Set(characters?.map(\.id) ?? []).count, characters?.count)
                XCTAssertTrue(cards?.contains { $0.maxPower > 0 } ?? false)
            }
        }
    }
}
