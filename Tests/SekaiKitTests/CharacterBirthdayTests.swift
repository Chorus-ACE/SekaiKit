import Foundation
import XCTest
import SwiftProtobuf
@testable import SekaiKit

final class CharacterBirthdayTests: XCTestCase {
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private func character(_ id: Int, month: Int? = nil, day: Int? = nil) -> SekaiKit.Character {
        var result = SekaiKit.Character(protobuf: .with { $0.id = Int32(id) })
        result.birthday = DateComponents(month: month, day: day)
        return result
    }

    private func date(_ month: Int, _ day: Int, year: Int = 2026, hour: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyo
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func ids(_ characters: [SekaiKit.Character], on date: Date, in timeZone: TimeZone? = nil) -> [Int] {
        SekaiKit.Character.recentBirthdayCharacters(
            in: characters, aroundDate: date, timeZone: timeZone ?? tokyo
        ).map(\.id)
    }

    func testExactBirthdayReturnsEveryoneOnThatDayInIDOrder() {
        let characters = [character(3, month: 10, day: 2), character(1, month: 10, day: 2), character(2, month: 10, day: 3)]
        XCTAssertEqual(ids(characters, on: date(10, 2, hour: 23)), [1, 3])
    }

    func testAdjacentGroupsKeepUpcomingBeforePreviousAndPreserveRecords() {
        let characters = [character(4, month: 10, day: 5), character(2, month: 9, day: 30), character(3, month: 10, day: 5), character(1, month: 9, day: 30), character(5, month: 11, day: 1)]
        let result = SekaiKit.Character.recentBirthdayCharacters(in: characters, aroundDate: date(10, 2), timeZone: tokyo)
        XCTAssertEqual(result.map(\.id), [3, 4, 1, 2])
        XCTAssertEqual(result, [characters[2], characters[0], characters[3], characters[1]])
    }

    func testYearBoundaryRetainsAllMembersOfBothGroups() {
        let characters = [character(4, month: 12, day: 30), character(2, month: 1, day: 2), character(3, month: 12, day: 30), character(1, month: 1, day: 2)]
        XCTAssertEqual(ids(characters, on: date(12, 31)), [1, 2, 3, 4])
        XCTAssertEqual(ids(characters, on: date(1, 1)), [1, 2, 3, 4])
    }

    func testTimeZoneDeterminesTheComparisonDay() {
        let characters = [character(1, month: 10, day: 1), character(2, month: 10, day: 2)]
        let instant = date(10, 2, hour: 1)
        XCTAssertEqual(ids(characters, on: instant), [2])
        XCTAssertEqual(ids(characters, on: instant, in: TimeZone(secondsFromGMT: 0)!), [1])
    }

    func testLeapDayIsPreservedAndYearIsIgnored() {
        var leap = character(2, month: 2, day: 29)
        leap.birthday?.year = 2001
        leap.birthday?.hour = 23
        let characters = [character(1, month: 2, day: 28), leap, character(3, month: 3, day: 2)]
        XCTAssertEqual(ids(characters, on: date(2, 29, year: 2024)), [2])
        XCTAssertEqual(ids(characters, on: date(3, 1)), [3, 2])
    }

    func testEmptyAndInvalidBirthdaysAreIgnored() {
        var missing = character(1)
        missing.birthday = nil
        let invalid = [missing, character(2, month: 1), character(3, day: 1), character(4, month: 0, day: 1), character(5, month: 13, day: 1), character(6, month: 4, day: 31), character(7, month: 2, day: 30), character(8, month: 1, day: 0)]
        XCTAssertEqual(ids([], on: date(10, 2)), [])
        XCTAssertEqual(ids(invalid, on: date(10, 2)), [])
        XCTAssertEqual(ids(invalid + [character(9, month: 1, day: 1)], on: date(10, 2)), [9])
    }

    func testSingleBirthdayGroupIsNotRepeated() {
        let characters = [character(2, month: 5, day: 1), character(1, month: 5, day: 1)]
        XCTAssertEqual(ids(characters, on: date(10, 2)), [1, 2])
        XCTAssertEqual(ids(characters, on: date(1, 1)), [1, 2])
    }

    func testPublicFunctionLoadsCharactersAndDistinguishesNoBirthdaysFromFailure() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let list = _CharacterList.with {
            $0.jp = [.with { $0.id = 1; $0.birthday = "10月2日" }, .with { $0.id = 2; $0.birthday = "10月3日" }]
        }
        try writeProtobufArchive(try list.serializedData(), to: directory.appending(path: "character.aar"))
        await SekaiProtobuf.$baseURL.withValue(directory) {
            let result = await SekaiKit.Character.recentBirthdayCharacters(aroundDate: date(10, 2), timeZone: tokyo)
            XCTAssertEqual(result?.map(\.id), [1])
        }
        let empty = directory.appending(path: "empty")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        let noBirthdays = _CharacterList.with { $0.jp = [.with { $0.id = 3 }] }
        try writeProtobufArchive(try noBirthdays.serializedData(), to: empty.appending(path: "character.aar"))
        await SekaiProtobuf.$baseURL.withValue(empty) {
            let result = await SekaiKit.Character.recentBirthdayCharacters()
            XCTAssertEqual(result, [])
        }
        await SekaiProtobuf.$baseURL.withValue(directory.appending(path: "missing")) {
            let result = await SekaiKit.Character.recentBirthdayCharacters()
            XCTAssertNil(result)
        }
    }
}
