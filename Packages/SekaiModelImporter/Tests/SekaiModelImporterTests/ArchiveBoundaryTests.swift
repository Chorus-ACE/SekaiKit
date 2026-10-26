import XCTest
@testable import SekaiModelImporter
final class ArchiveBoundaryTests: XCTestCase {
    private func archive(name: String = "CAB-sample", expanded: UInt32 = 256) -> Data {
        var info = Data(repeating: 0, count: 16)
        func be<T: FixedWidthInteger>(_ value: T) -> Data { var v = value.bigEndian; return withUnsafeBytes(of: &v) { Data($0) } }
        info += be(UInt32(1)) + be(expanded) + be(UInt32(256)) + be(UInt16(0))
        info += be(UInt32(1)) + be(UInt64(0)) + be(UInt64(256)) + be(UInt32(0)) + Data((name + "\0").utf8)
        var result = Data("UnityFS\0".utf8) + be(UInt32(7)) + Data("5.x.x\0".utf8) + Data("0.0.0\0".utf8)
        let lengthPosition = result.count
        result += Data(repeating: 0, count: 8) + be(UInt32(info.count)) + be(UInt32(info.count)) + be(UInt32(0x240))
        while result.count % 16 != 0 { result.append(0) }
        result += info
        while result.count % 16 != 0 { result.append(0) }
        result += Data(repeating: 42, count: 256)
        result.replaceSubrange(lengthPosition..<(lengthPosition + 8), with: be(UInt64(result.count)))
        return result
    }
    func testUncompressedAndTransportWrappedArchivesHaveIdenticalPayload() throws {
        let input = archive(), plain = try UnityFSArchive(data: input)
        XCTAssertEqual(plain.entries.count, 1); XCTAssertEqual(plain.expandedBytes, 256)
        XCTAssertEqual(plain.entries[0].data, Data(repeating: 42, count: 256))
        var wrapped = input
        for i in stride(from: 0, to: 128, by: 8) { for j in 0..<5 { wrapped[i + j] ^= 255 } }
        wrapped = Data([0x10, 0, 0, 0]) + wrapped
        XCTAssertEqual(try UnityFSArchive(data: wrapped).entries[0].data, plain.entries[0].data)
    }
    func testEntryTraversalLengthMismatchAndExpansionBombFail() {
        XCTAssertThrowsError(try UnityFSArchive(data: archive(name: "../outside")))
        XCTAssertThrowsError(try UnityFSArchive(data: archive(expanded: 128)))
        XCTAssertThrowsError(try UnityFSArchive(data: archive(expanded: UInt32.max)))
        var truncated = archive(); truncated.removeLast()
        XCTAssertThrowsError(try UnityFSArchive(data: truncated))
    }
}
