import XCTest
import SwiftyJSON
@testable import SekaiKit

final class SongVideoTests: XCTestCase {
    func testGeneratedRegionalMediaAndFurnitureDialogues() async throws {
        guard let directory = ProcessInfo.processInfo.environment["SEKAI_ADDITIONAL_PROTOBUF_ASSETS"],
              let sources = ProcessInfo.processInfo.environment["SEKAI_PROTOBUF_MASTER_DATA"] else {
            throw XCTSkip("Set archive and master-data directories for regional conversion validation")
        }
        func rows(_ table: String, locale: SekaiLocale) throws -> [JSON] {
            let region = locale == .tw ? "tc" : locale.rawValue
            return try JSON(data: Data(contentsOf: URL(filePath: sources).appending(path: region + "/" + table + ".json"))).arrayValue
        }
        try await SekaiProtobuf.$baseURL.withValue(URL(filePath: directory)) {
            let songsResult = await requestProtobuf("song.aar", as: _SongList.self)
            let fixturesResult = await requestProtobuf("fixture.aar", as: _FixtureList.self)
            let songs = try XCTUnwrap(songsResult)
            let fixtures = try XCTUnwrap(fixturesResult)
            for locale in SekaiLocale.allCases {
                let originals = try rows("musicOriginals", locale: locale)
                let regionalSongs = songs.items(in: locale)
                XCTAssertEqual(regionalSongs.flatMap(\.originalVideoLinks).count, originals.count)
                for song in regionalSongs {
                    XCTAssertEqual(song.originalVideoLinks, originals.filter { $0["musicId"].intValue == Int(song.id) }.map { $0["videoLink"].stringValue })
                }
                let song = try XCTUnwrap(regionalSongs.first { $0.media.contains("mv_2d") })
                let content = Song.videoContent(protobuf: song, locale: locale)
                XCTAssertFalse(content.videos.isEmpty)
                XCTAssertTrue(content.videos.allSatisfy { $0.locale == locale })
                let tweets = Dictionary(uniqueKeysWithValues: try rows("mysekaiCharacterTalkTweets", locale: locale).map { ($0["id"].intValue, $0["text"].stringValue) })
                let regionalFixtures = fixtures.items(in: locale)
                let fixture = try XCTUnwrap(regionalFixtures.first { !$0.dialogues.isEmpty })
                for fixture in regionalFixtures {
                    let dialogues = fixture.dialogues.map(MySekaiFixture.Dialogue.init(protobuf:))
                    XCTAssertEqual(Set(dialogues.map(\.id)).count, dialogues.count)
                    for dialogue in dialogues {
                        XCTAssertEqual(dialogue.text, tweets[dialogue.tweetID])
                        XCTAssertNotNil(dialogue.characterID)
                    }
                }
                let fixtureModel = MySekaiFixture(protobuf: fixture)
                let dialogues = await fixtureModel.dialogues(in: locale)
                XCTAssertEqual(dialogues?.count, fixture.dialogues.count)
            }
        }
    }

    func testMediaNamesMatchTheirActualSourceValues() {
        XCTAssertEqual(Song.MediaType(rawValue: "mv"), ._3DMV)
        XCTAssertEqual(Song.MediaType(rawValue: "mv_2d"), ._2DMV)
    }

    func testRegionalVariantsAndExternalLinksRemainIndependent() {
        let record = _Song.with {
            $0.id = 8; $0.media = ["mv_2d", "original"]
            $0.vocals = [.with { $0.id = 9; $0.caption = "Alternate" }]
            $0.assetVariants = [
                .with { $0.id = 1; $0.musicVocalID = 9; $0.musicAssetType = "mv"; $0.assetbundleName = "8005" },
                .with { $0.id = 2; $0.musicVocalID = 9; $0.musicAssetType = "mv"; $0.assetbundleName = "8005" },
                .with { $0.id = 3; $0.musicVocalID = 9; $0.musicAssetType = "jacket"; $0.assetbundleName = "jacket" }
            ]
            $0.originalVideoLinks = ["https://youtu.be/example", "https://youtu.be/example", "javascript:alert(1)"]
        }
        let jp = Song.videoContent(protobuf: record, locale: .jp)
        XCTAssertEqual(jp.videos.map(\.assetBundleName), ["8005", "0008"])
        XCTAssertEqual(jp.videos.first?.caption, "Alternate")
        XCTAssertEqual(jp.externalURLs.map(\.absoluteString), ["https://youtu.be/example"])
        let en = Song.videoContent(protobuf: .with { $0.id = 8; $0.media = ["mv"] }, locale: .en)
        XCTAssertTrue(en.videos.isEmpty)
        XCTAssertTrue(en.externalURLs.isEmpty)
    }

    func testPartialVideoOverridesPreserveTheDefaultVersion() {
        let content = Song.videoContent(protobuf: .with {
            $0.id = 138; $0.media = ["mv_2d"]
            $0.vocals = [.with { $0.id = 287 }, .with { $0.id = 1560 }]
            $0.assetVariants = [.with {
                $0.id = 1; $0.musicVocalID = 1560; $0.musicAssetType = "mv"; $0.assetbundleName = "8007"
            }]
        }, locale: .jp)
        XCTAssertEqual(content.videos.map(\.assetBundleName), ["0138", "8007"])
    }

    func testOldArchiveWithoutNewFieldsStillDecodes() throws {
        let record = _Song.with { $0.id = 6; $0.media = ["mv_2d"] }
        let decoded = try _Song(serializedBytes: record.serializedData())
        let result = Song.videoContent(protobuf: decoded, locale: .tw)
        XCTAssertEqual(result.videos.first?.assetBundleName, "0006")
        XCTAssertEqual(result.videos.first?.locale, .tw)
        XCTAssertTrue(result.externalURLs.isEmpty)
        let fixture = try _Fixture(serializedBytes: _Fixture.with { $0.id = 1 }.serializedData())
        XCTAssertTrue(fixture.dialogues.isEmpty)
        XCTAssertFalse(fixture.hasDialoguesIncluded)
    }
}
