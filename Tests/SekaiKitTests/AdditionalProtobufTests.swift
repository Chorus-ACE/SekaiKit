import Foundation
import XCTest
import SwiftyJSON
import SwiftProtobuf
@testable import SekaiKit

final class AdditionalProtobufTests: XCTestCase {
    func testFixtureMissingBlueprintAndFreeRecipeRemainDistinct() throws {
        var p = _Fixture.with { $0.id = 1; $0.name = "Fixture"; $0.seq = 0 }
        let missing = MySekaiFixture(protobuf: p)
        XCTAssertNil(missing.materials.majorValue)
        XCTAssertEqual(missing.blueprints.majorValue, [])
        XCTAssertEqual(missing.displayOrder.majorValue, 0)
        p.blueprints = [.with { $0.id = 2; $0.craftCountLimit = 0 }, .with { $0.id = 3; $0.materials = [.with { $0.id = 9; $0.quantity = 3 }] }]
        let fixture = MySekaiFixture(protobuf: p)
        XCTAssertEqual(fixture.materials.majorValue, [])
        XCTAssertEqual(fixture.blueprints.majorValue?.count, 2)
        XCTAssertEqual(fixture.blueprints.majorValue?.first?.craftCountLimit, 0)
        XCTAssertEqual(fixture.blueprints.majorValue?.last?.materials.first?.id, 9)
        XCTAssertNil(fixture.blueprints.majorValue?.last?.materials.first?.name)
        XCTAssertEqual(MySekaiFixture(fromCache: fixture.dataForCache), fixture)
    }

    func testGachaLegacyEnumsAndNewPrecisionAndPresence() throws {
        var p = _Gacha.with {
            $0.id = 1; $0.name = "Gacha"; $0.gachaType = .specialBeginner
            $0.gachaCardRarityRates = [.with { $0.id = 1; $0.cardRarityType = .rarity4; $0.lotteryType = .normal; $0.rate = 3 }]
        }
        let legacy = Gacha(protobuf: p)
        XCTAssertEqual(legacy.type, .specialBeginner)
        XCTAssertEqual(legacy.configuration.majorValue?.rarityRates.first?.rarityType, "rarity_4")
        XCTAssertNil(legacy.startDate.majorValue)
        p.gachaTypeName = "future"
        p.spinLimit = 0; p.startAt = 0
        p.gachaCardRarityRates[0].preciseRate = 0.123456789
        p.gachaCardRarityRates[0].clearID()
        let current = Gacha(protobuf: p)
        XCTAssertEqual(current.type, .unknown)
        XCTAssertEqual(current.configuration.majorValue?.spinLimit, 0)
        XCTAssertEqual(current.startDate.majorValue, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(current.configuration.majorValue?.rarityRates.first?.rate, 0.123456789)
        XCTAssertEqual(current.configuration.majorValue?.rarityRates.first?.id, -1)
    }

    func testSongCreditsAndSkillFractions() {
        let song = Song(protobuf: .with { $0.composer = "Composer"; $0.arranger = "Arranger"; $0.lyricist = "Lyricist" })
        XCTAssertEqual(song.composer.majorValue, "Composer")
        XCTAssertEqual(song.arranger.majorValue, "Arranger")
        XCTAssertEqual(song.lyricist.majorValue, "Lyricist")
        let skill = Skill(protobuf: .with {
            $0.skillEffects = [.with { $0.skillEffectType = "future"; $0.skillEffectDetails = [.with { $0.activateEffectDuration = 4.5; $0.activateEffectValueType = "future" }] }]
        })
        XCTAssertEqual(skill.effects.first?.type, .unknown)
        XCTAssertEqual(skill.effects.first?.details.first?.duration, 4.5)
        XCTAssertEqual(skill.effects.first?.details.first?.valueType, .unknown)
    }

    func testGeneratedArchivesAcrossAllRegions() async throws {
        guard let directory = ProcessInfo.processInfo.environment["SEKAI_ADDITIONAL_PROTOBUF_ASSETS"],
              let sources = ProcessInfo.processInfo.environment["SEKAI_PROTOBUF_MASTER_DATA"] else {
            throw XCTSkip("Set SEKAI_ADDITIONAL_PROTOBUF_ASSETS and SEKAI_PROTOBUF_MASTER_DATA for conversion-to-client validation")
        }
        func rows(_ table: String, _ locale: SekaiLocale) throws -> [JSON] {
            let region = locale == .tw ? "tc" : locale.rawValue
            return try JSON(data: Data(contentsOf: URL(filePath: sources).appending(path: region).appending(path: "\(table).json"))).arrayValue
        }
        try await SekaiProtobuf.$baseURL.withValue(URL(filePath: directory)) {
            for locale in SekaiLocale.allCases {
                let gachasResult = await Gacha.allInLocale(locale)
                let gachas = try XCTUnwrap(gachasResult)
                let rawGachas = try rows("gachas", locale).compactMap(Gacha.init(json:))
                XCTAssertEqual(gachas.map(\.id), rawGachas.map(\.id))
                if let pair = zip(gachas, rawGachas).first(where: { $0 != $1 }) {
                    func difference(_ a: Any, _ b: Any, path: String = "") -> String? {
                        if let a = a as? [String: Any], let b = b as? [String: Any] {
                            for key in Set(a.keys).union(b.keys).sorted() {
                                guard let av = a[key], let bv = b[key] else { return path + "." + key + " presence differs" }
                                if let d = difference(av, bv, path: path + "." + key) { return d }
                            }
                            return nil
                        }
                        if let a = a as? [Any], let b = b as? [Any] {
                            guard a.count == b.count else { return path + " counts \(a.count) / \(b.count)" }
                            for i in a.indices { if let d = difference(a[i], b[i], path: path + "[\(i)]") { return d } }
                            return nil
                        }
                        return (a as? NSObject)?.isEqual(b) == true ? nil : path + " \(a) / \(b)"
                    }
                    let a = try PropertyListSerialization.propertyList(from: pair.0.dataForCache, format: nil)
                    let b = try PropertyListSerialization.propertyList(from: pair.1.dataForCache, format: nil)
                    XCTFail("Gacha \(locale) ID \(pair.0.id): \(difference(a, b) ?? "unknown difference")")
                }
                let stickersResult = await Sticker.allInLocale(locale)
                let stickers = try XCTUnwrap(stickersResult)
                XCTAssertEqual(stickers, try rows("stamps", locale).compactMap(Sticker.init(json:)), "Sticker parity \(locale)")
                let comicsResult = await Comic.allInLocale(locale)
                let comics = try XCTUnwrap(comicsResult)
                XCTAssertEqual(comics, try rows("tips", locale).compactMap(Comic.init(json:)))
                let fixturesResult = await MySekaiFixture.allInLocale(locale)
                let fixtures = try XCTUnwrap(fixturesResult)
                XCTAssertEqual(fixtures.count, try rows("mysekaiFixtures", locale).count)
                XCTAssertTrue(fixtures.allSatisfy { $0.displayOrder.majorValue != nil })
                let songsResult = await Song.allInLocale(locale)
                let songs = try XCTUnwrap(songsResult)
                XCTAssertEqual(songs.count, try rows("musics", locale).count)
                let vocalsResult = await Song.VocalVersion.allInLocale(locale)
                let vocals = try XCTUnwrap(vocalsResult)
                XCTAssertEqual(vocals.count, try rows("musicVocals", locale).count)
                let outsideResult = await Song.VocalVersion.VocalCharacter.allInLocale(locale)
                let outside = try XCTUnwrap(outsideResult)
                XCTAssertEqual(outside.count, try rows("outsideCharacters", locale).count)
                let conditionsResult = await ReleaseCondition.allInLocale(locale)
                let conditions = try XCTUnwrap(conditionsResult)
                XCTAssertEqual(conditions.count, try rows("releaseConditions", locale).count)
                let skillsResult = await Skill.all(forLocale: locale)
                let skills = try XCTUnwrap(skillsResult)
                XCTAssertEqual(skills.count, try rows("skills", locale).count)
                for kind in Episode.Kind.allCases {
                    let table = switch kind { case .event: "eventStories"; case .unit: "unitStories"; case .card: "cardEpisodes" }
                    let episodesResult = await Episode.all(in: locale, kind: kind)
                    let episodes = try XCTUnwrap(episodesResult)
                    XCTAssertEqual(episodes, Episode.parse(try rows(table, locale), in: locale, kind: kind))
                }
            }
            let metasResult = await MusicMeta.all()
            let metas = try XCTUnwrap(metasResult)
            let rawMeta = try JSON(data: Data(contentsOf: URL(filePath: sources).appending(path: "shared/music_metas.json"))).arrayValue
            let expectedMeta = rawMeta.compactMap(MusicMeta.init(json:))
            XCTAssertFalse(metas.isEmpty)
            XCTAssertEqual(metas.count, rawMeta.count)
            if let (actual, expected) = zip(metas, expectedMeta).first(where: { $0 != $1 }) {
                XCTFail("Statistics differ: \(actual) / \(expected)")
            }
        }
    }
}
