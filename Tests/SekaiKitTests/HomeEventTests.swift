import Foundation
import XCTest
@testable import SekaiKit

final class HomeEventTests: XCTestCase {
    private func event(_ id: Int, start: Double, end: Double, locale: SekaiLocale = .jp) -> Event {
        var event = Event(protobuf: .with { $0.id = Int32(id) })
        event.startDate = .localized(.init(repeating: Date(timeIntervalSince1970: start), forLocale: [locale]))
        event.aggregateDate = .localized(.init(repeating: Date(timeIntervalSince1970: end), forLocale: [locale]))
        return event
    }

    func testOngoingThenUpcomingThenMostRecentWithRegionalIsolation() {
        let old = event(1, start: 100, end: 200)
        let current = event(2, start: 200, end: 300)
        let future = event(3, start: 400, end: 500)
        let english = event(4, start: 200, end: 300, locale: .en)
        let events = [future, english, old, current]
        XCTAssertEqual(Event.featuredEvent(in: events, locale: .jp, at: .init(timeIntervalSince1970: 250))?.id, 2)
        XCTAssertEqual(Event.featuredEvent(in: events, locale: .en, at: .init(timeIntervalSince1970: 250))?.id, 4)
        XCTAssertEqual(Event.featuredEvent(in: events, locale: .jp, at: .init(timeIntervalSince1970: 300))?.id, 3)
        XCTAssertEqual(Event.featuredEvent(in: events, locale: .jp, at: .init(timeIntervalSince1970: 600))?.id, 3)
        XCTAssertNil(Event.featuredEvent(in: events, locale: .kr))
        XCTAssertNil(Event.featuredEvent(in: [], locale: .jp))
    }
}
