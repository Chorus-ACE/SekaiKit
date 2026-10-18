import XCTest
@testable import SekaiKit

final class CardSupportUnitTests: XCTestCase {
    private func card(_ id: Int, character: Int, support: String = "") -> Card {
        Card(protobuf: .with {
            $0.id = Int32(id)
            $0.characterID = Int32(character)
            $0.supportUnit = support
        })
    }

    func testSupportUnitOptionsMatchUnitOptions() throws {
        let unit = try XCTUnwrap(Card.filterKeys.first { $0.id == "unit" })
        XCTAssertEqual(Card.supportUnitFilterKey.options, unit.options)
        XCTAssertTrue(Card.filterKeys.contains { $0.id == "supportUnit" })
    }

    func testSupportUnitSeparatesVirtualSingerVariants() {
        let cards = [card(1, character: 21, support: "light_sound"), card(2, character: 21, support: "idol"), card(3, character: 21), card(4, character: 1)]
        var filter = SekaiFilter(["unit": [Unit.virtualSinger.intRawValue], "supportUnit": [Unit.leoNeed.intRawValue]])
        XCTAssertEqual(cards.filter(withSekaiFilter: filter).map(\.id), [1])
        filter["supportUnit"] = [Unit.virtualSinger.intRawValue]
        XCTAssertEqual(cards.filter(withSekaiFilter: filter).map(\.id), [3])
        filter["supportUnit"] = []
        XCTAssertEqual(cards.filter(withSekaiFilter: filter).map(\.id), [])
        // A hidden support-unit control must retain its selection, and ordinary
        // members do not acquire a support unit when a different main unit is selected.
        filter["unit"] = [Unit.leoNeed.intRawValue]
        XCTAssertEqual(cards.filter(withSekaiFilter: filter).map(\.id), [4])
    }
}
