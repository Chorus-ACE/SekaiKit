import Foundation
import AppleArchive
import Testing
import MCP
import SekaiKit
@testable import SekaiKitMCP

struct SekaiMCPTests {
    private func adapter() -> SekaiMCPServer {
        SekaiMCPServer { collection, locale in
            #expect(collection == .songs)
            if locale == .en { return [] }
            return [
                .init(id: 3, name: "Hello SEKAI", data: .object(["id": 3, "title": "Hello SEKAI"])),
                .init(id: 1, name: "SEKAI", data: .object(["id": 1])),
                .init(id: 2, name: nil, data: .object(["id": 2]))
            ]
        }
    }

    private func json(_ result: CallTool.Result) throws -> Value {
        #expect(result.isError != true)
        guard case .text(let text, _, _) = result.content.first else { throw TestFailure.invalidContent }
        return try JSONDecoder().decode(Value.self, from: Data(text.utf8))
    }

    @Test func searchPaginationAndRegionIsolation() async throws {
        let server = adapter()
        let first = try json(await server.callTool(name: "sekai_search", arguments: ["collection": "songs", "locale": "jp", "limit": 1]))
        #expect(first["total"] == 3)
        #expect(first["nextOffset"] == 1)
        #expect(first["records"] == .array([.object(["id": 1, "name": "SEKAI"])]))
        let last = try json(await server.callTool(name: "sekai_search", arguments: ["collection": "songs", "locale": "jp", "offset": 2]))
        #expect(last["nextOffset"] == .null)
        let english = try json(await server.callTool(name: "sekai_search", arguments: ["collection": "songs", "locale": "en"]))
        #expect(english["total"] == 0)
    }

    @Test func nameAndIDSearch() async throws {
        let server = adapter()
        let matches = try json(await server.callTool(name: "sekai_search", arguments: ["collection": "songs", "locale": "jp", "query": "hello"]))
        #expect(matches["total"] == 1)
        let id = try json(await server.callTool(name: "sekai_search", arguments: ["collection": "songs", "locale": "jp", "query": "2"]))
        #expect(id["records"] == .array([.object(["id": 2, "name": .null])]))
    }

    @Test func detailsAndMissingRecord() async throws {
        let server = adapter()
        let found = try json(await server.callTool(name: "sekai_get", arguments: ["collection": "songs", "locale": "jp", "id": 3]))
        #expect(found["record"] == .object(["id": 3, "title": "Hello SEKAI"]))
        let missing = try await server.callTool(name: "sekai_get", arguments: ["collection": "songs", "locale": "en", "id": 3])
        #expect(missing.isError == true)
    }

    @Test func invalidArgumentsDoNotLoadData() async {
        let server = SekaiMCPServer { _, _ in
            Issue.record("Invalid arguments must be rejected before loading")
            return []
        }
        let invalid: [[String: Value]] = [
            ["collection": "songs"],
            ["collection": "songs", "locale": "tc"],
            ["collection": "songs", "locale": "jp", "limit": 101],
            ["collection": "songs", "locale": "jp", "offset": -1],
            ["collection": "songs", "locale": "jp", "limit": "20"],
            ["collection": "songs", "locale": "jp", "query": false],
            ["collection": "songs", "locale": "jp", "extra": true]
        ]
        for arguments in invalid {
            await #expect(throws: MCPError.self) { try await server.callTool(name: "sekai_search", arguments: arguments) }
        }
        await #expect(throws: MCPError.self) { try await server.callTool(name: "unknown", arguments: [:]) }
        await #expect(throws: MCPError.self) { try await server.callTool(name: "sekai_get", arguments: ["collection": "songs", "locale": "jp", "id": 0]) }
    }

    @Test func loadFailureIsToolError() async throws {
        let server = SekaiMCPServer { _, _ in throw TestFailure.unavailable }
        let response = try await server.callTool(name: "sekai_search", arguments: ["collection": "songs", "locale": "jp"])
        #expect(response.isError == true)
    }

    @Test func regionDiscoveryDoesNotLoadData() async throws {
        let server = SekaiMCPServer { _, _ in
            Issue.record("Region discovery does not need archives")
            return []
        }
        let response = try json(await server.callTool(name: "sekai_list_regions", arguments: [:]))
        #expect(response["regions"] == .array(["jp", "en", "tw", "cn", "kr"]))
        #expect(SekaiMCPServer.tools.count == 3)
    }

    @Test func realDataSourceReadsOnlyRequestedRegion() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        // _CardList: JP card 1 named JP, EN card 1 named EN; no other regions.
        let protobuf = Data([0x0a, 0x06, 0x08, 0x01, 0x12, 0x02, 0x4a, 0x50,
                             0x12, 0x06, 0x08, 0x01, 0x12, 0x02, 0x45, 0x4e])
        let archive = try ArchiveByteStream.withTemporaryFileStream { output in
            try ArchiveByteStream.withCompressionStream(using: .lzfse, writingTo: output) { compressed in
                try ArchiveStream.withEncodeStream(writingTo: compressed) { stream in
                    let header = ArchiveHeader()
                    header.append(.uint(key: .init("TYP"), value: UInt64(ArchiveHeader.EntryType.regularFile.rawValue)))
                    header.append(.string(key: .init("PAT"), value: "card.proto"))
                    header.append(.blob(key: .init("DAT"), size: UInt64(protobuf.count)))
                    try stream.writeHeader(header)
                    try protobuf.withUnsafeBytes { try stream.writeBlob(key: .init("DAT"), from: $0) }
                }
            }
            let size = try output.seek(toOffset: 0, relativeTo: .end)
            _ = try output.seek(toOffset: 0, relativeTo: .start)
            var data = Data(count: Int(size))
            let read = try data.withUnsafeMutableBytes { try output.read(into: $0) }
            #expect(read == Int(size))
            return data
        }
        try archive.write(to: directory.appending(path: "card.aar"))
        try await SekaiProtobuf.$baseURL.withValue(directory) {
            let japanese = try await SekaiMCPDataSource.load(.cards, locale: .jp)
            let english = try await SekaiMCPDataSource.load(.cards, locale: .en)
            let korean = try await SekaiMCPDataSource.load(.cards, locale: .kr)
            #expect(japanese.first?.name == "JP")
            #expect(english.first?.name == "EN")
            #expect(korean.isEmpty)
            #expect(japanese.first?.data["id"] == 1)
        }
    }

    enum TestFailure: Error { case invalidContent, unavailable }
}

private extension Value {
    subscript(key: String) -> Value? {
        guard case .object(let object) = self else { return nil }
        return object[key]
    }
}
