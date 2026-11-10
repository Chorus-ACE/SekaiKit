import XCTest
import SwiftyJSON
@testable import SekaiKit

final class EpisodeHeadingTests: XCTestCase {
    private func episode(_ number: Int, characterID: Int? = nil, locale: SekaiLocale = .jp) -> Episode {
        var value = Episode(episodeID: number, parentID: 112, number: number, title: "Story", chapterTitle: "", scenarioID: "wl_\(number)", scenarioPath: "", locale: locale, kind: .event)
        value.characterID = characterID
        return value
    }
    func testWorldLinkUsesCharacterPartsAndOpeningEndingWithoutChangingOrder() {
        let rows = [episode(1), episode(2, characterID: 17), episode(3, characterID: 17), episode(4)]
        let result = Episode.applyingHeadings(to: rows, characterNames: [17: "宵崎奏"])
        XCTAssertEqual(result.map(\.numberLabel), ["オープニング", "宵崎奏 前編", "宵崎奏 後編", "エンディング"])
        XCTAssertEqual(result.map(\.number), [1, 2, 3, 4])
        let single = Episode.applyingHeadings(to: [episode(1), episode(2, characterID: 17), episode(3)], characterNames: [17: "宵崎奏"])
        XCTAssertEqual(single[1].numberLabel, "宵崎奏")
        XCTAssertNil(Episode.applyingHeadings(to: [episode(1), episode(2)], characterNames: [:])[0].numberLabel)
    }
    func testSourceLabelTakesPriorityAndMainStoryOpeningIsNotEpisodeOne() throws {
        let rows = Episode.parse(try JSON(data: Data(#"[{"chapters":[{"id":1,"title":"Main","assetbundleName":"unit","episodes":[{"id":1,"episodeNo":1,"episodeNoLabel":"序章","title":"序章","scenarioId":"unit_00"},{"id":2,"episodeNo":21,"episodeNoLabel":"第20话","title":"Final","scenarioId":"unit_20"}]}]}]"#.utf8)).arrayValue, in: .cn, kind: .unit)
        XCTAssertEqual(rows.map(\.numberLabel), ["序章", "第20话"])
        var first = episode(1)
        first.numberLabel = "Official opening"
        XCTAssertEqual(Episode.applyingHeadings(to: [first, episode(2, characterID: 17), episode(3)], characterNames: [:])[0].numberLabel, "Official opening")
    }
    func testOlderArchivesAndMissingVersusEmptyLabels() throws {
        let legacy = _Episode.with { $0.id = 1; $0.kind = "unit" }
        let decoded = Episode(protobuf: try _Episode(serializedBytes: legacy.serializedData()), locale: .en, kind: .unit)
        XCTAssertNil(decoded.numberLabel)
        XCTAssertNil(decoded.characterID)
        let modern = _Episode.with { $0.id = 1; $0.numberLabel = ""; $0.gameCharacterID = 0 }
        let value = Episode(protobuf: try _Episode(serializedBytes: modern.serializedData()), locale: .en, kind: .unit)
        XCTAssertEqual(value.numberLabel, "")
        XCTAssertEqual(value.characterID, 0)
    }
}
