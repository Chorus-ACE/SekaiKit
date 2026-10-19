import Foundation
import SwiftyJSON
import XCTest
@testable import SekaiKit

final class AdditionalContentTests: XCTestCase {
    func testComicExcludesTextTipsAndPreservesRegionalAssets() throws {
        XCTAssertNil(Comic(json: JSON(["id": 1, "title": "Tip", "description": "Help"])))
        let jp = try XCTUnwrap(Comic(json: JSON(["id": 1001, "title": "JP", "assetbundleName": "comic_0001"])))
        let en = try XCTUnwrap(Comic(json: JSON(["id": 1001, "title": "EN", "assetbundleName": "comic_0001_en"])))
        let comic = try XCTUnwrap(Comic.combineLocalizations([.jp: jp, .en: en], defaultLocale: .jp))
        XCTAssertEqual(comic.availableLocales, [.jp, .en])
        XCTAssertNil(comic.imageURL(in: .kr))
        XCTAssertTrue(comic.imageURL(in: .en)!.path.hasSuffix("comic_0001_en.webp"))
        XCTAssertTrue(comic._matches(SekaiFilter(["locale": [SekaiLocale.en.rawIntValue]])))
        XCTAssertFalse(comic._matches(SekaiFilter(["locale": [SekaiLocale.kr.rawIntValue]])))
        XCTAssertEqual(Comic(fromCache: comic.dataForCache), comic)
    }
    func testFixtureCategoryFilterUsesSameRegionalRecordAndSurfacePath() throws {
        let json = JSON(["id": 1, "name": "Wall", "mysekaiFixtureType": "surface_appearance", "mysekaiSettableSiteType": "room", "mysekaiSettableLayoutType": "wall_appearance", "assetbundleName": "wall_01"])
        let fixture = try XCTUnwrap(MySekaiFixture(json: json))
        XCTAssertEqual(fixture.type.majorValue, .surfaceAppearance)
        XCTAssertNil(fixture.size.majorValue)
        XCTAssertTrue(fixture.imageURL(in: .jp)!.path.hasSuffix("surface_appearance/wall_01/tex_wall_01_wall_appearance_1.png"))
        XCTAssertTrue(fixture._matches(SekaiFilter(forKeys: MySekaiFixture.filterKeys)))
        XCTAssertFalse(fixture._matches(SekaiFilter(["fixtureSite": [MySekaiFixture.Site.home.filterValue]])))
        XCTAssertEqual(MySekaiFixture.applicableSortingTypes.last, .id)
        XCTAssertEqual(MySekaiFixture(fromCache: fixture.dataForCache), fixture)
    }
    func testFixtureDisplayOrderUsesSelectedRegionAndPreservesMissingValues() throws {
        func fixture(_ id: Int, _ seq: Int?) throws -> MySekaiFixture {
            var json = JSON(["id": id, "name": "Fixture"])
            if let seq { json["seq"] = JSON(seq) }
            return try XCTUnwrap(MySekaiFixture(json: json))
        }
        let regional = try XCTUnwrap(MySekaiFixture.combineLocalizations([
            .jp: try fixture(1, 30), .cn: try fixture(1, 0)
        ], defaultLocale: .jp))
        let other = try XCTUnwrap(MySekaiFixture.combineLocalizations([
            .jp: try fixture(2, 20), .cn: try fixture(2, 20)
        ], defaultLocale: .jp))
        let missing = try fixture(3, nil)
        let tied = try fixture(4, 20)
        let items = [missing, regional, tied, other]
        XCTAssertEqual(items.sorted(withSekaiSorter: .init(keyword: .displayOrder(in: .jp), direction: .ascending)).map(\.id), [2, 4, 1, 3])
        XCTAssertEqual(items.sorted(withSekaiSorter: .init(keyword: .displayOrder(in: .jp), direction: .descending)).map(\.id), [1, 4, 2, 3])
        XCTAssertEqual([other, regional].sorted(withSekaiSorter: .init(keyword: .displayOrder(in: .cn), direction: .ascending)).map(\.id), [1, 2])
        XCTAssertNil(regional.displayOrder.value(in: .en))
        XCTAssertEqual(MySekaiFixture(fromCache: regional.dataForCache), regional)
        var legacy = try XCTUnwrap(PropertyListSerialization.propertyList(from: regional.dataForCache, format: nil) as? [String: Any])
        legacy.removeValue(forKey: "displayOrder")
        legacy.removeValue(forKey: "blueprints")
        let legacyData = try PropertyListSerialization.data(fromPropertyList: legacy, format: .binary, options: 0)
        let decoded = try XCTUnwrap(MySekaiFixture(fromCache: legacyData))
        XCTAssertNil(decoded.displayOrder.majorValue)
        XCTAssertNil(decoded.blueprints.majorValue)
        XCTAssertEqual(decoded.title, regional.title)
        for locale in SekaiLocale.allCases {
            let sorter = SekaiSorter(keyword: .displayOrder(in: locale))
            XCTAssertEqual(try PropertyListDecoder().decode(SekaiSorter.self, from: PropertyListEncoder().encode(sorter)), sorter)
            XCTAssertTrue(MySekaiFixture.applicableSortingTypes.contains(sorter.keyword))
        }
    }

    func testFixtureUnknownCategoriesRemainAbsentWithoutOtherOptions() throws {
        let fixture = try XCTUnwrap(MySekaiFixture(json: JSON([
            "id": 2, "name": "Future fixture", "mysekaiFixtureType": "future_type",
            "mysekaiSettableSiteType": "future_site", "mysekaiSettableLayoutType": "future_layout"
        ])))
        XCTAssertNil(fixture.type.majorValue)
        XCTAssertNil(fixture.site.majorValue)
        XCTAssertNil(fixture.layout.majorValue)
        for key in [MySekaiFixture.FixtureType.filterKey, MySekaiFixture.Site.filterKey, MySekaiFixture.Layout.filterKey] {
            XCTAssertFalse(key.allOptionsID.contains(nil))
        }
    }

    func testSongLevelMatchesAnyChartAndClearsToDefaults() {
        var song = Song(
            id: 1, title: .unlocalized("Song"), isNewlyWrittenMusic: false,
            creatorArtist: .unlocalized(nil), composer: .unlocalized(nil),
            arranger: .unlocalized(nil), lyricist: .unlocalized(nil),
            publishDate: .unlocalized(nil), _releaseDate: .unlocalized(nil),
            categories: [.virtualSinger], availableMedia: [.image],
            difficultyLevel: [.easy: 7, .expert: 25, .append: 32], noteCounts: [:],
            liveStageID: 0, dancerCount: 0, selfDancerPosition: 0, releaseConditionID: 0,
            assetbundleName: "", liveTalkBackgroundAssetBundleName: "",
            isFullLength: false, fillerSec: 0, secForMusicScoreMaker: nil,
            isAvailableForMusicScoreMaker: nil
        )
        var filter = SekaiFilter(forKeys: Song.filterKeys)
        XCTAssertFalse(filter.isFiltering(referencing: Song.filterKeys))
        XCTAssertTrue(song._matches(filter))
        for level in [7, 25, 32] {
            filter[Song.levelFilterKey.id] = [level]
            XCTAssertTrue(filter.isFiltering(referencing: Song.filterKeys))
            XCTAssertEqual([song].filter(withSekaiFilter: filter).count, 1)
        }
        filter[Song.levelFilterKey.id] = [31]
        XCTAssertTrue([song].filter(withSekaiFilter: filter).isEmpty)
        filter[Song.levelFilterKey.id] = []
        XCTAssertFalse(filter.isFiltering(referencing: Song.filterKeys))
        XCTAssertTrue(song._matches(filter))
        filter[Song.levelFilterKey.id] = [32]
        filter["song-has-append"] = [0]
        XCTAssertFalse(song._matches(filter))

        // A partial level filter must not silently require a unit selection.
        XCTAssertTrue(song._matches(SekaiFilter(["song-level": [25]])))
        filter = SekaiFilter(forKeys: Song.filterKeys)
        filter["song-level"] = [25]
        song.categories = [.all]
        XCTAssertTrue(song._matches(filter))
        filter[Unit.filterKey.id] = [nil]
        XCTAssertTrue(song._matches(filter))
        filter[Unit.filterKey.id] = []
        XCTAssertFalse(song._matches(filter))
        filter[Unit.filterKey.id] = [Unit.virtualSinger.filterValue]
        XCTAssertFalse(song._matches(filter))
        song.categories = [.all, .virtualSinger]
        XCTAssertTrue(song._matches(filter))
        filter[Unit.filterKey.id] = [nil]
        XCTAssertFalse(song._matches(filter))
        song.categories = [.other]
        XCTAssertTrue(song._matches(filter))
        song.availableMedia = []
        XCTAssertTrue(song._matches(filter))
        filter[Song.MediaType.filterKey.id] = [Song.MediaType.image.filterValue]
        XCTAssertFalse(song._matches(filter))
    }

    func testTranscriptUsesSnippetOrderAndIgnoresBrokenReferences() throws {
        let json = JSON(["Snippets": [["Action": 1, "ReferenceIndex": 1], ["Action": 1, "ReferenceIndex": -1], ["Action": 1, "ReferenceIndex": 0], ["Action": 1, "ReferenceIndex": 5]], "TalkData": [["Body": "First", "WindowDisplayName": "A"], ["Body": "Second", "WindowDisplayName": "B"]]])
        let transcript = try XCTUnwrap(StoryTranscript(json: json))
        XCTAssertEqual(transcript.lines.map(\.text), ["Second", "First"])
        XCTAssertEqual(transcript.lines.map(\.speaker), ["B", "A"])
        XCTAssertNil(StoryTranscript(json: JSON(["error": "unavailable"])))
    }
    func testTranscriptResolvesAvatarsAndRegionalFullVoiceWithoutInventingPartVoice() throws {
        let data: [String: Any] = [
            "ScenarioId": "event_167_01",
            "Snippets": [["Action": 1, "ReferenceIndex": 0], ["Action": 1, "ReferenceIndex": 1]],
            "TalkData": [
                ["Body": "Full", "WindowDisplayName": "Saki", "TalkCharacters": [["Character2dId": 2], ["Character2dId": 999]], "Voices": [["VoiceId": "voice_full"]]],
                ["Body": "Part", "WindowDisplayName": "Saki", "Voices": [["VoiceId": "partvoice_01"]]]
            ]
        ]
        var episode = Episode(episodeID: 1, parentID: 167, number: 1, title: "Test", chapterTitle: "",
                              scenarioID: "event_167_01", scenarioPath: "test.asset", locale: .en, kind: .event)
        let transcript = try XCTUnwrap(StoryTranscript(json: JSON(data), episode: episode, characterMapping: [2: 2]))
        XCTAssertEqual(transcript.lines[0].characterIDs, [2])
        XCTAssertEqual(transcript.lines[0].voiceURL?.absoluteString,
                       "https://storage.sekai.best/sekai-en-assets/sound/scenario/voice/event_168_01/voice_full.mp3")
        XCTAssertNil(transcript.lines[1].voiceURL)
        episode.kind = .card
        var card = data
        card["ScenarioId"] = "★4冬弥・泉_前半"
        let cardTranscript = try XCTUnwrap(StoryTranscript(json: JSON(card), episode: episode))
        XCTAssertEqual(cardTranscript.lines[0].voiceURL?.path, "/sekai-en-assets/sound/card_scenario/voice/012043_touya01/voice_full.mp3")
        XCTAssertEqual(StoryTranscript(fromCache: transcript.dataForCache), transcript)
    }

    func testDownloadedContent() throws {
        guard let directory = ProcessInfo.processInfo.environment["SEKAI_ADDITIONAL_TEST_DATA"] else { throw XCTSkip("Set SEKAI_ADDITIONAL_TEST_DATA for real master data validation") }
        func load(_ name: String) throws -> JSON { try JSON(data: Data(contentsOf: URL(filePath: directory).appendingPathComponent(name + ".json"))) }
        let tips = try load("tips").arrayValue
        XCTAssertEqual(tips.compactMap(Comic.init(json:)).count, tips.filter { $0["assetbundleName"].stringValue.hasPrefix("comic_") }.count)
        let fixtures = try load("mysekaiFixtures").arrayValue
        XCTAssertEqual(fixtures.compactMap(MySekaiFixture.init(json:)).count, fixtures.count)
        let events = try load("eventStories").arrayValue
        let episodes = Episode.parse(events, in: .jp, kind: .event)
        XCTAssertEqual(episodes.count, events.reduce(0) { $0 + $1["eventStoryEpisodes"].arrayValue.count })
        XCTAssertEqual(episodes.first?.scenarioPath, "event_story/event_stella_2020/scenario/event_01_01.asset")
        let units = try load("unitStories").arrayValue
        let unitEpisodes = Episode.parse(units, in: .jp, kind: .unit)
        XCTAssertEqual(unitEpisodes.count, units.reduce(0) { $0 + $1["chapters"].arrayValue.reduce(0) { $0 + $1["episodes"].arrayValue.count } })
        XCTAssertEqual(unitEpisodes.first?.imagePath, "story/episode_image/idol-story-chapter/story_ts_01_00.webp")
        let cards = try load("cardEpisodes").arrayValue
        XCTAssertEqual(Episode.parse(cards, in: .jp, kind: .card).count, cards.count)
        XCTAssertEqual(Episode.parse(cards, in: .en, kind: .card).first?.scenarioPath,
                       "character/member_scenario/res001_no001/001001_ichika01.asset")
        let transcript = try XCTUnwrap(StoryTranscript(json: load("scenario")))
        XCTAssertEqual(transcript.lines.filter { !$0.speaker.isEmpty }.count, 63)
        let metas = try load("music_metas").arrayValue
        XCTAssertEqual(metas.compactMap(MusicMeta.init(json:)).count, metas.count)
    }
}
