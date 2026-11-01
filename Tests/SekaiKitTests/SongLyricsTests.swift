import XCTest
@testable import SekaiKit

final class SongLyricsTests: XCTestCase {
    private let line: [String: Any] = [
        "id": "line-a", "order": 0, "japanese": "未来", "zh-CN": "未来译文", "en-US": "Future",
        "stanzaBreakBefore": true,
        "segments": [["text": "未来", "performerIds": [1], "ruby": [["text": "未来", "reading": "みらい"]]]],
        "trailingPerformerIds": [2]
    ]

    private func decode(_ document: [String: Any]) throws -> Song.Lyrics {
        try JSONDecoder().decode(Song.Lyrics.self, from: JSONSerialization.data(withJSONObject: document))
    }

    private func legacy(version: Int = 2) -> [String: Any] {
        ["version": version, "musicId": 788, "revision": 1, "updatedAt": "2026-10-01T00:00:00Z",
         "state": "complete", "attribution": "Example attribution", "attributions": [],
         "availableVersions": ["full", "game"], "gameProjection": ["lineIds": ["line-a"]],
         "lines": [line]]
    }

    private func attribution(_ component: Any? = nil) -> [String: Any] {
        var value: [String: Any] = [
            "provider": "sekaipedia", "title": "Example", "revisionId": 1,
            "revisionUrl": "https://www.sekaipedia.org/wiki/Example?oldid=1",
            "licenseName": "CC BY-SA 4.0", "licenseUrl": "https://creativecommons.org/licenses/by-sa/4.0/"
        ]
        if let component { value["component"] = component }
        return value
    }

    private func rendition(_ provenance: [[String: Any]], key: String = "sekai") -> [String: Any] {
        ["key": key, "kind": "sekai", "label": "SEKAI", "availableVersions": ["full"],
         "performers": [], "provenance": provenance, "sourceTabPaths": [["SEKAI"]],
         "relation": ["kind": "none"],
         "full": ["version": ["kind": "sekai", "label": "Full"], "lines": [line]]]
    }

    private func decodeRendition(_ value: [String: Any]) throws -> Song.Lyrics.Rendition {
        try JSONDecoder().decode(Song.Lyrics.Rendition.self, from: JSONSerialization.data(withJSONObject: value))
    }

    func testComponentEnumDecodesScopedAndUnscopedNamesAndPreservesUnknownValues() throws {
        typealias Component = Song.Lyrics.Attribution.Component
        let expected: [(String, Component)] = [
            ("full_text", .fullText), ("game_text", .gameText),
            ("full_performer_segmentation", .fullPerformerSegmentation),
            ("game_performer_segmentation", .gamePerformerSegmentation),
            ("full_ruby", .fullRuby), ("game_ruby", .gameRuby), ("relation", .relation), ("version", .version)
        ]
        for (name, component) in expected {
            for value in [name, "renditions/sekai/\(name)"] {
                let data = try JSONEncoder().encode(value)
                XCTAssertEqual(try JSONDecoder().decode(Component.self, from: data), component)
            }
        }
        let unknown = "renditions/sekai/future_component"
        XCTAssertEqual(try JSONDecoder().decode(Component.self, from: JSONEncoder().encode(unknown)), .unknown(unknown))
    }

    func testAttributionAcceptsComponentStringArrayAndLegacyAbsence() throws {
        func decodeAttribution(_ component: Any?) throws -> Song.Lyrics.Attribution {
            try JSONDecoder().decode(Song.Lyrics.Attribution.self, from: JSONSerialization.data(withJSONObject: attribution(component)))
        }
        XCTAssertEqual(try decodeAttribution("renditions/sekai/full_text").component, [.fullText])
        XCTAssertEqual(try decodeAttribution(["full_text", "full_ruby"]).component, [.fullText, .fullRuby])
        XCTAssertEqual(try decodeAttribution(nil).component, [])
        XCTAssertEqual(try decodeAttribution(NSNull()).component, [])
    }

    func testMatchingSourcesMergeComponentsInFirstSeenOrderWithoutDuplicates() throws {
        let decoded = try decodeRendition(rendition([
            attribution("renditions/sekai/full_text"), attribution("renditions/sekai/full_ruby"),
            attribution(["full_text", "game_text", "game_text"])
        ]))
        XCTAssertEqual(decoded.provenance.count, 1)
        XCTAssertEqual(decoded.provenance.first?.component, [.fullText, .fullRuby, .gameText])
        XCTAssertEqual(decoded.provenance.first?.revisionID, 1)
    }

    func testDifferentSourcesRevisionsAndLicensesRemainSeparate() throws {
        let first = attribution("full_text")
        var otherPage = attribution("game_text")
        otherPage["revisionUrl"] = "https://www.sekaipedia.org/wiki/Other?oldid=1"
        var otherRevision = attribution("full_ruby")
        otherRevision["revisionId"] = 2
        var otherLicense = attribution("game_ruby")
        otherLicense["licenseName"] = "CC BY-SA 3.0"
        otherLicense["licenseUrl"] = "https://creativecommons.org/licenses/by-sa/3.0/"
        var otherProvider = attribution("version")
        otherProvider["provider"] = "future_source"
        let decoded = try decodeRendition(rendition([first, otherPage, otherRevision, otherLicense, otherProvider, first]))
        XCTAssertEqual(decoded.provenance.count, 5)
        XCTAssertEqual(decoded.provenance.map(\.component), [[.fullText], [.gameText], [.fullRuby], [.gameRuby], [.version]])
    }

    func testLegacyAttributionsAlsoMergeAndKeepUnscopedCredits() throws {
        var value = legacy()
        value["attributions"] = [attribution(), attribution("full_text"), attribution("full_ruby")]
        let lyrics = try decode(value)
        XCTAssertEqual(lyrics.attributions?.count, 1)
        XCTAssertEqual(lyrics.attributions?.first?.component, [.fullText, .fullRuby])
        XCTAssertEqual(lyrics.renditions.first?.provenance, lyrics.attributions)
    }

    func testAttributionMergingStaysWithinItsRendition() throws {
        var value = legacy()
        value["version"] = 3
        value["renditions"] = [rendition([attribution("renditions/sekai/full_text")]),
                               rendition([attribution("renditions/vocaloid/game_text")], key: "vocaloid")]
        let lyrics = try decode(value)
        XCTAssertEqual(lyrics.renditions.map(\.key), ["sekai", "vocaloid"])
        XCTAssertEqual(lyrics.renditions.map { $0.provenance.first?.component }, [[.fullText], [.gameText]])
    }

    func testLegacyPreservesStanzasTranslationsNumericPerformersAndRuby() throws {
        let lyrics = try decode(legacy())
        let rendition = try XCTUnwrap(lyrics.renditions.first)
        let line = try XCTUnwrap(lyrics.lines(for: rendition, length: .game).first)
        XCTAssertEqual(lyrics.songID, 788)
        XCTAssertEqual(line.chinese, "未来译文")
        XCTAssertEqual(line.english, "Future")
        XCTAssertEqual(line.stanzaBreakBefore, true)
        XCTAssertEqual(line.segments.first?.performerIDs.first?.value, "1")
        XCTAssertEqual(line.trailingPerformerIDs?.first?.value, "2")
        XCTAssertEqual(line.segments.first?.ruby?.first?.reading, "みらい")
    }

    func testV1MissingTranslationRemainsNilAndEmptyTranslationRemainsEmpty() throws {
        var document = legacy(version: 1)
        var source = line
        source.removeValue(forKey: "en-US")
        source["zh-CN"] = ""
        document["lines"] = [source]
        let lyrics = try decode(document)
        XCTAssertNil(lyrics.renditions.first?.full?.lines.first?.english)
        XCTAssertEqual(lyrics.renditions.first?.full?.lines.first?.chinese, "")
    }

    func testV4ChineseEditionsProjectByFullLineIDWithoutInventingEnglish() throws {
        var first = line
        first.removeValue(forKey: "zh-CN")
        first.removeValue(forKey: "en-US")
        var second = first
        second["id"] = "line-b"
        second["order"] = 1
        let rendition: [String: Any] = [
            "key": "sekai", "kind": "sekai", "label": "SEKAI", "availableVersions": ["full", "game"],
            "performers": [], "provenance": [], "sourceTabPaths": [["SEKAI"]],
            "relation": ["kind": "exact_projection", "fullRenditionKey": "sekai", "lineIds": ["line-b", "line-a"]],
            "full": ["version": ["kind": "sekai", "label": "Full"], "lines": [first, second]],
            "game": ["version": ["kind": "sekai", "label": "Game"], "lines": [second, first]]
        ]
        let edition: [String: Any] = ["key": "community", "label": "Community", "renditions": [
            ["renditionKey": "sekai", "translationCredits": ["translation": "Translator"],
             "full": ["translations": ["第一行", "第二行"]]]]]
        let document: [String: Any] = ["version": 4, "musicId": 788, "revision": 2, "updatedAt": "2026-10-01T00:00:00Z",
                                      "state": "complete", "defaultTranslationEditionKey": "community",
                                      "renditions": [rendition], "translationEditions": [edition]]
        let lyrics = try decode(document)
        let decoded = try XCTUnwrap(lyrics.renditions.first)
        XCTAssertEqual(lyrics.lines(for: decoded, length: .game).map(\.chinese), ["第二行", "第一行"])
        XCTAssertTrue(lyrics.lines(for: decoded, length: .full).allSatisfy { $0.english == nil })
        XCTAssertEqual(lyrics.credits(for: decoded)?.translation, "Translator")
        XCTAssertEqual(lyrics.lines(for: decoded, length: .game, editionKey: "removed-edition").map(\.chinese), ["第二行", "第一行"])
    }

    func testUnknownRenditionKindPreservesValue() throws {
        let kind = try JSONDecoder().decode(Song.Lyrics.Kind.self, from: Data("\"future-category\"".utf8))
        XCTAssertEqual(kind, .unknown("future-category"))
    }

    func testUnsupportedSchemaIsRejected() {
        var document = legacy()
        document["version"] = 99
        XCTAssertThrowsError(try decode(document))
    }

    func testInvalidLegacyProjectionAndDuplicateLinesAreRejected() {
        var document = legacy()
        document["gameProjection"] = ["lineIds": ["missing"]]
        XCTAssertThrowsError(try decode(document))
        document = legacy()
        document["lines"] = [line, line]
        XCTAssertThrowsError(try decode(document))
    }

    func testLocalRepositoryDistinguishesMissingLyricsAndMismatchedSongID() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = try JSONSerialization.data(withJSONObject: legacy())
        try data.write(to: directory.appending(path: "music_788.json"))
        try data.write(to: directory.appending(path: "music_789.json"))
        try await SekaiLyrics.$baseURL.withValue(directory) {
            let found = try await SekaiLyrics.lyrics(forSongID: 788)
            XCTAssertEqual(found?.songID, 788)
            let missing = try await SekaiLyrics.lyrics(forSongID: 790)
            XCTAssertNil(missing)
            do {
                _ = try await SekaiLyrics.lyrics(forSongID: 789)
                XCTFail("A different song's lyrics must not be displayed")
            } catch {
                XCTAssertEqual(error as? SekaiLyrics.Failure, .mismatchedSongID)
            }
        }
    }

    func testPublishedRepositoryDocumentsDecode() throws {
        guard let directory = ProcessInfo.processInfo.environment["SEKAI_LYRICS_FIXTURES"] else {
            throw XCTSkip("Set SEKAI_LYRICS_FIXTURES to the mirrored lyrics directory for corpus validation")
        }
        let files = try FileManager.default.contentsOfDirectory(at: URL(filePath: directory), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("music_") }
        XCTAssertFalse(files.isEmpty)
        for file in files {
            let lyrics = try JSONDecoder().decode(Song.Lyrics.self, from: Data(contentsOf: file))
            XCTAssertEqual(file.lastPathComponent, "music_\(lyrics.songID).json")
            XCTAssertFalse(lyrics.renditions.isEmpty)
            for rendition in lyrics.renditions {
                for length in rendition.lengths {
                    let lines = lyrics.lines(for: rendition, length: length)
                    XCTAssertFalse(lines.isEmpty, file.lastPathComponent)
                    for line in lines {
                        XCTAssertEqual(line.segments.map(\.text).joined(), line.japanese, file.lastPathComponent)
                    }
                }
            }
        }
    }
}
