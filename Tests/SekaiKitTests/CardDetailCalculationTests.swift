import XCTest
import SwiftyJSON
import SwiftProtobuf
import Foundation
@testable import SekaiKit

final class CardDetailCalculationTests: XCTestCase {
    func testRegionalPowerAndTrainingCaps() throws {
        let card = Card(protobuf: _Card.with {
            $0.rarity = "rarity_4"
            $0.cardParameters = ["param1", "param2", "param3"].flatMap { type in
                [1, 50, 60].map { level in .with { $0.type = type; $0.level = Int32(level); $0.power = Int32(level * 100) } }
            }
            $0.specialTrainingPower1BonusFixed = 1000
            $0.specialTrainingPower2BonusFixed = 2000
            $0.specialTrainingPower3BonusFixed = 3000
        })
        var protobuf = _CardStatRules.with {
            $0.normalMaxLevel = 50; $0.trainedMaxLevel = 60
            $0.masterBonuses = (1...5).map { rank in .with {
                $0.rank = Int32(rank); $0.bonus = .with { $0.performance = 200; $0.stamina = 200; $0.technique = 200 }
            } }
            $0.episodeBonuses = [250, 600].enumerated().map { index, bonus in .with {
                $0.episodeID = Int32(index + 1); $0.sequence = Int32(index + 1)
                $0.bonus = .with { $0.performance = Int32(bonus); $0.stamina = Int32(bonus); $0.technique = Int32(bonus) }
            } }
        }
        let rules = try XCTUnwrap(CardStatRules(protobuf: protobuf))
        XCTAssertEqual(rules.masterRanks, [0, 1, 2, 3, 4, 5])
        XCTAssertEqual(rules.power(for: card, level: 1)?.total, 300)
        XCTAssertNil(rules.power(for: card, level: 60))
        let maximum = try XCTUnwrap(rules.power(for: card, level: 60, masterRank: 5, episodes: 2, trained: true))
        XCTAssertEqual(maximum.performance, 8850)
        XCTAssertEqual(maximum.stamina, 9850)
        XCTAssertEqual(maximum.technique, 10850)
        XCTAssertNil(rules.power(for: card, level: 2)) // Missing level is not zero power.
        XCTAssertNil(rules.power(for: card, level: 50, masterRank: 6))
        XCTAssertNil(rules.power(for: card, level: 50, episodes: 3))
        protobuf.normalMaxLevel = 40
        let regionalRules = try XCTUnwrap(CardStatRules(protobuf: protobuf))
        XCTAssertNil(regionalRules.power(for: card, level: 50))
    }

    func testEmbeddedCanvasPowerStacksWithOtherBonuses() throws {
        let card = Card(protobuf: .with {
            $0.rarity = "rarity_4"
            $0.cardParameters = ["param1", "param2", "param3"].map { type in
                .with { $0.type = type; $0.level = 1; $0.power = 100 }
            }
            $0.specialTrainingPower1BonusFixed = 1000
        })
        var protobuf = _CardStatRules.with { $0.normalMaxLevel = 1 }
        protobuf.mysekaiCanvasBonus = .with { $0.performance = 500; $0.stamina = 400; $0.technique = 0 }
        let rules = try XCTUnwrap(CardStatRules(protobuf: protobuf))
        XCTAssertEqual(rules.mySekaiCanvasBonus?.total, 900)
        XCTAssertEqual(rules.power(for: card, level: 1)?.total, 300)
        let trained = try XCTUnwrap(rules.power(for: card, level: 1, trained: true, mySekaiCanvas: true))
        XCTAssertEqual(trained.performance, 1600)
        XCTAssertEqual(trained.stamina, 500)
        XCTAssertEqual(trained.technique, 100)
        let regional = CardStatRules(protobuf: .with {
            $0.normalMaxLevel = 1
            $0.mysekaiCanvasBonus = .with { $0.performance = 10; $0.stamina = 20; $0.technique = 30 }
        })
        XCTAssertEqual(regional?.power(for: card, level: 1, mySekaiCanvas: true)?.total, 360)
        protobuf.mysekaiCanvasBonus.clearTechnique()
        XCTAssertNil(CardStatRules(protobuf: protobuf))
    }

    func testEmbeddedRulesMergeAndCacheRoundTrip() throws {
        let jp = Card(protobuf: _Card.with {
            $0.id = 1; $0.statRules = .with {
                $0.normalMaxLevel = 50
                $0.mysekaiCanvasBonus = .with { $0.performance = 500; $0.stamina = 500; $0.technique = 500 }
            }
        })
        let en = Card(protobuf: _Card.with {
            $0.id = 1; $0.statRules = .with {
                $0.normalMaxLevel = 40
                $0.mysekaiCanvasBonus = .with { $0.performance = 100; $0.stamina = 100; $0.technique = 100 }
            }
        })
        let card = try XCTUnwrap(Card.combineLocalizations([.jp: jp, .en: en], defaultLocale: .jp))
        XCTAssertEqual(card.statRules.localizedData?[.jp]?.normalMaxLevel, 50)
        XCTAssertEqual(card.statRules.localizedData?[.en]?.normalMaxLevel, 40)
        XCTAssertNil(card.statRules.localizedData?[.kr])
        XCTAssertEqual(card.statRules.localizedData?[.jp]?.mySekaiCanvasBonus?.total, 1500)
        XCTAssertEqual(card.statRules.localizedData?[.en]?.mySekaiCanvasBonus?.total, 300)
        XCTAssertEqual(Card(fromCache: card.dataForCache), card)
        XCTAssertNil(CardStatRules(protobuf: _CardStatRules()))
        XCTAssertNil(CardStatRules(protobuf: .with {
            $0.normalMaxLevel = 50
            $0.masterBonuses = [.with { $0.rank = 1; $0.bonus = .with { $0.performance = 0 } }]
        }))
    }

    func testAllRegionalEmbeddedRulesWhenFixturesAreProvided() throws {
        guard let folder = ProcessInfo.processInfo.environment["SEKAI_CARD_RULE_FIXTURES"] else { throw XCTSkip("Full upstream fixtures are optional") }
        let list = try _CardList(serializedBytes: Data(contentsOf: URL(filePath: folder).appending(path: "generated/card.proto")))
        for rows in [list.jp, list.en, list.tc, list.cn, list.kr] {
            for row in rows {
                let card = Card(protobuf: row)
                XCTAssertNotNil(card.statRules.majorValue, "Card \(card.id)")
                XCTAssertNotNil(card.statRules.majorValue?.mySekaiCanvasBonus, "Canvas bonus for card \(card.id)")
            }
        }
    }

    func testSkillUsesEffectIDsAndPreservesLegacyAbsence() {
        let skill = Skill(protobuf: _Skill.with {
            $0.description_p = "{{8;d}}s / {{5;v}}% / {{5;d}}s"
            $0.shortDescription = "{{5;v}}%"
            $0.skillEffects = [.with {
                $0.id = 5; $0.skillEffectType = "score_up"
                $0.skillEffectDetails = [.with { $0.level = 4; $0.activateEffectDuration = 5; $0.activateEffectValue = 30 }]
            }, .with {
                $0.id = 8; $0.skillEffectType = "judgment_up"
                $0.skillEffectDetails = [.with { $0.level = 4; $0.activateEffectDuration = 6; $0.activateEffectValue = 0 }]
            }]
        })
        XCTAssertEqual(skill.description(atLevel: 4), "6s / 30% / 5s")
        XCTAssertEqual(skill.description(atLevel: 4, short: true), "30%")
        XCTAssertEqual(skill.description(atLevel: 1), "—s / —% / —s")
        let legacy = Skill(protobuf: _Skill.with { $0.skillEffects = [.with { $0.skillEffectType = "score_up" }] })
        XCTAssertNil(legacy.effects.first?.id)
    }

    func testEnhancementAndPlayerDependentSkillTemplates() throws {
        var options = JSONDecodingOptions()
        options.ignoreUnknownFields = true
        let json = #"{"id":15,"shortDescription":"{{44;v}} + {{44;e}}, max {{44;m}}","description":"{{0;c}}: {{44;d}}s, {{44;m}}%","skillEffects":[{"id":44,"skillEffectType":"score_up","skillEffectDetails":[{"level":4,"activateEffectDuration":5,"activateEffectValue":100,"activateEffectValueType":"rate"}],"skillEnhance":{"skillEnhanceType":"sub_unit_score_up","activateEffectValueType":"rate","activateEffectValue":10,"skillEnhanceCondition":{"unit":"light_sound"}}}]}"#
        let skill = Skill(protobuf: try _Skill(jsonString: json, options: options))
        XCTAssertEqual(skill.effects.first?.enhancement, .leoNeed)
        XCTAssertEqual(skill.effects.first?.enhancementValue, 10)
        XCTAssertEqual(skill.description(atLevel: 4, short: true), "100 + 10, max 150")
        XCTAssertEqual(skill.description(atLevel: 4, characterName: "Ichika"), "Ichika: 5s, 150%")
        XCTAssertFalse(skill.description(atLevel: 4).contains("{{"))
    }

    func testDownloadedSkillTemplatesWhenProvided() throws {
        guard let path = ProcessInfo.processInfo.environment["SEKAI_SKILL_TEST_DATA"] else {
            throw XCTSkip("Set SEKAI_SKILL_TEST_DATA to a downloaded skills.json.")
        }
        let rows = try JSON(data: Data(contentsOf: URL(filePath: path))).arrayValue
        var options = JSONDecodingOptions()
        options.ignoreUnknownFields = true
        for row in rows {
            let skill = Skill(protobuf: try _Skill(jsonUTF8Data: row.rawData(), options: options))
            for level in 1...4 {
                XCTAssertFalse(skill.description(atLevel: level, characterName: "Miku").contains("{{"), "Skill \(skill.id)")
                XCTAssertFalse(skill.description(atLevel: level, short: true).contains("{{"))
            }
        }
    }

    func testIndependentDrawEstimatesAndNumericLimits() throws {
        XCTAssertEqual(GachaDrawEstimate.probability(perDraw: 0, draws: 10), 0)
        XCTAssertEqual(GachaDrawEstimate.probability(perDraw: 1, draws: 0), 0)
        XCTAssertEqual(GachaDrawEstimate.probability(perDraw: 1, draws: 1), 1)
        XCTAssertEqual(GachaDrawEstimate.draws(perDraw: 0, target: 0), 0)
        XCTAssertNil(GachaDrawEstimate.draws(perDraw: 0, target: 0.5))
        XCTAssertEqual(GachaDrawEstimate.draws(perDraw: 1, target: 0.99), 1)
        XCTAssertNil(GachaDrawEstimate.draws(perDraw: 0.03, target: 1))
        XCTAssertNil(GachaDrawEstimate.draws(perDraw: 1e-30, target: 0.99))
        XCTAssertNil(GachaDrawEstimate.probability(perDraw: .nan, draws: 10))
        XCTAssertNil(GachaDrawEstimate.probability(perDraw: 0.1, draws: -1))
        let draws = try XCTUnwrap(GachaDrawEstimate.draws(perDraw: 0.004, target: 0.99))
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(GachaDrawEstimate.probability(perDraw: 0.004, draws: draws)), 0.99)
        XCTAssertLessThan(try XCTUnwrap(GachaDrawEstimate.probability(perDraw: 0.004, draws: draws - 1)), 0.99)
    }
}
