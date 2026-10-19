import Foundation
import XCTest
import SwiftProtobuf
@testable import SekaiKit

final class SongVocalOrderTests: XCTestCase {
    private func vocal(_ id: Int32, caption: String) -> _SongVocal {
        .with {
            $0.id = id
            $0.musicID = 1
            $0.caption = caption
            $0.musicVocalType = "sekai"
            $0.assetbundleName = "vocal_\(id)"
        }
    }

    func testRegionalMergePreservesSourceOrderAndLocalizedCaptions() {
        let jp = [40, 2, 9].map { Song.VocalVersion(protobuf: vocal(Int32($0), caption: "jp_\($0)")) }
        let en = [9, 40, 7, 6].map { Song.VocalVersion(protobuf: vocal(Int32($0), caption: "en_\($0)")) }
        let tw = [13].map { Song.VocalVersion(protobuf: vocal(Int32($0), caption: "tw_\($0)")) }
        let regions: [SekaiLocale: [Song.VocalVersion]] = [.tw: tw, .en: en, .jp: jp]

        let japanese = mergeCollections(regions, defaultLocale: .jp)
        XCTAssertEqual(japanese.map(\.id), [40, 2, 9, 7, 6, 13])
        XCTAssertEqual(japanese[0].caption.localizedData?.jp, "jp_40")
        XCTAssertEqual(japanese[0].caption.localizedData?.en, "en_40")
        XCTAssertEqual(mergeCollections(regions, defaultLocale: .en).map(\.id), [9, 40, 7, 6, 2, 13])
        XCTAssertEqual(mergeCollections(regions, defaultLocale: .cn).map(\.id), [40, 2, 9, 7, 6, 13])
        XCTAssertEqual(mergeCollections([.jp: [], .en: en], defaultLocale: .jp).map(\.id), [9, 40, 7, 6])
    }

    @MainActor
    func testVocalLoadersAndCachePreserveOrderAcrossPreferredRegions() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let originalLocale = SekaiLocale.primaryLocale
        defer {
            SekaiLocale.primaryLocale = originalLocale
            try? FileManager.default.removeItem(at: directory)
        }
        let list = _SongList.with {
            $0.jp = [.with { $0.id = 1; $0.vocals = [vocal(40, caption: "jp_40"), vocal(2, caption: "jp_2")] }]
            $0.en = [.with { $0.id = 1; $0.vocals = [vocal(2, caption: "en_2"), vocal(40, caption: "en_40"), vocal(7, caption: "en_7")] }]
        }
        try writeProtobufArchive(try list.serializedData(), to: directory.appending(path: "song.aar"))

        try await SekaiProtobuf.$baseURL.withValue(directory) {
            SekaiLocale.primaryLocale = .en
            let direct = await Song.VocalVersion.all()
            XCTAssertEqual(direct?.map(\.id), [2, 40, 7])
            let fresh = await Song.VocalVersion.allWithCache(trait: .realTime)
            XCTAssertEqual(fresh?.map(\.id), [2, 40, 7])
            let cached = await Song.VocalVersion.allWithCache()
            XCTAssertEqual(cached?.map(\.id), [2, 40, 7])
            let decoded = [Song.VocalVersion](fromCache: try XCTUnwrap(cached).dataForCache)
            XCTAssertEqual(decoded?.map(\.id), [2, 40, 7])

            SekaiLocale.primaryLocale = .jp
            let japanese = await Song.VocalVersion.allWithCache()
            XCTAssertEqual(japanese?.map(\.id), [40, 2, 7])
            SekaiLocale.primaryLocale = .en
            let english = await Song.VocalVersion.allWithCache()
            XCTAssertEqual(english?.map(\.id), [2, 40, 7])
        }
    }

    @MainActor
    func testVocalCacheRespectsArchiveSource() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for (name, ids) in [("first", [40, 2]), ("second", [2, 40])] {
            let directory = root.appending(path: name)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let song = _Song.with {
                $0.id = 1
                $0.vocals = ids.map { vocal(Int32($0), caption: name) }
            }
            let list = _SongList.with { $0.jp = [song]; $0.en = [song]; $0.tc = [song]; $0.cn = [song]; $0.kr = [song] }
            try writeProtobufArchive(try list.serializedData(), to: directory.appending(path: "song.aar"))
            await SekaiProtobuf.$baseURL.withValue(directory) {
                let versions = await Song.VocalVersion.allWithCache()
                XCTAssertEqual(versions?.map(\.id), ids)
                XCTAssertEqual(versions?.first?.caption.majorValue, name)
            }
        }
    }
}
