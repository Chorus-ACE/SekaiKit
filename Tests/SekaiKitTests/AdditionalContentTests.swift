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
        let song = Song(
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
