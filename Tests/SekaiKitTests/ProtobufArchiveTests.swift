import Foundation
import AppleArchive
import XCTest
@testable import SekaiKit

// Generate portable fixtures with the same LZFSE container as the aa command.
func protobufArchiveFixture(_ entries: [(String, Data)]) throws -> Data {
    try ArchiveByteStream.withTemporaryFileStream { output in
        try ArchiveByteStream.withCompressionStream(using: .lzfse, writingTo: output) { compressed in
            try ArchiveStream.withEncodeStream(writingTo: compressed) { archive in
                for (name, data) in entries {
                    let header = ArchiveHeader()
                    header.append(.uint(key: .init("TYP"), value: UInt64(ArchiveHeader.EntryType.regularFile.rawValue)))
                    header.append(.string(key: .init("PAT"), value: name))
                    header.append(.blob(key: .init("DAT"), size: UInt64(data.count)))
                    try archive.writeHeader(header)
                    try data.withUnsafeBytes { try archive.writeBlob(key: .init("DAT"), from: $0) }
                }
            }
        }
        let size = try output.seek(toOffset: 0, relativeTo: .end)
        _ = try output.seek(toOffset: 0, relativeTo: .start)
        var data = Data(count: Int(size))
        let count = try data.withUnsafeMutableBytes { try output.read(into: $0) }
        XCTAssertEqual(count, Int(size))
        return data
    }
}

func writeProtobufArchive(_ bytes: Data, to url: URL) throws {
    let name = url.deletingPathExtension().lastPathComponent + ".proto"
    try protobufArchiveFixture([(name, bytes)]).write(to: url)
}

final class ProtobufArchiveTests: XCTestCase {
    func testExtractsNamedProtobufFromCompressedArchive() throws {
        let bytes = Data(repeating: 42, count: 8192)
        let archive = try protobufArchiveFixture([("card.proto", bytes)])
        XCTAssertLessThan(archive.count, bytes.count)
        XCTAssertEqual(try ProtobufArchive.decode(archive, expectedFile: "card.proto"), bytes)
    }

    func testRejectsWrongPathsExtraEntriesAndDuplicates() throws {
        for entries in [
            [("other.proto", Data([1]))],
            [("../card.proto", Data([1]))],
            [("card.proto", Data([1])), ("other.proto", Data([2]))],
            [("card.proto", Data([1])), ("card.proto", Data([2]))],
        ] {
            let archive = try protobufArchiveFixture(entries)
            XCTAssertThrowsError(try ProtobufArchive.decode(archive, expectedFile: "card.proto"))
        }
    }

    func testRejectsEmptyCorruptAndTruncatedArchives() throws {
        XCTAssertThrowsError(try ProtobufArchive.decode(Data(), expectedFile: "card.proto"))
        XCTAssertThrowsError(try ProtobufArchive.decode(Data("invalid".utf8), expectedFile: "card.proto"))
        let archive = try protobufArchiveFixture([("card.proto", Data(repeating: 1, count: 4096))])
        XCTAssertThrowsError(try ProtobufArchive.decode(archive.prefix(archive.count / 2), expectedFile: "card.proto"))
    }

    func testReaderDoesNotFallBackToRawProtobuf() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        // A valid _CardList with one JP card, but no .aar is present.
        try Data([0x0a, 0x02, 0x08, 0x01]).write(to: directory.appending(path: "card.proto"))
        await SekaiProtobuf.$baseURL.withValue(directory) {
            let cards = await Card.allInLocale(.jp)
            XCTAssertNil(cards)
        }
    }
}
