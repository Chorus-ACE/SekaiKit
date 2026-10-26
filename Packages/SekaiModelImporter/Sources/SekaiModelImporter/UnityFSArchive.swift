import Compression
import Foundation

/// A bounded, in-memory UnityFS reader. Entry paths are never written to disk.
public struct UnityFSArchive: Sendable {
    public struct Entry: Sendable {
        public let name: String
        public let data: Data
    }
    public let entries: [Entry]
    public let expandedBytes: Int
    public static let maximumExpandedBytes = 128 * 1024 * 1024

    /// Accepts plain UnityFS or the SEKAI transport header used by the regional CDN.
    public init(data input: Data) throws {
        guard input.count <= Self.maximumExpandedBytes else { throw ModelImportError.budgetExceeded }
        let data = try Self.normalizeTransport(input)
        var reader = BinaryReader(data: data)
        guard try reader.zeroString() == "UnityFS" else { throw ModelImportError.unsupported("archive signature") }
        let version = try reader.integer(UInt32.self)
        guard version == 6 || version == 7 || version == 8 else { throw ModelImportError.unsupported("UnityFS version \(version)") }
        _ = try reader.zeroString(); _ = try reader.zeroString()
        let fileSize = try reader.integer(UInt64.self)
        guard fileSize == data.count else { throw ModelImportError.malformed("archive length") }
        let compressedInfo = Int(try reader.integer(UInt32.self))
        let expandedInfo = Int(try reader.integer(UInt32.self))
        let flags = try reader.integer(UInt32.self)
        if version >= 7 { try reader.align(16) }
        var infoReader: BinaryReader
        if flags & 128 != 0 {
            guard compressedInfo <= data.count - reader.position else { throw ModelImportError.malformed("archive info bounds") }
            infoReader = BinaryReader(data: try Self.expand(data.suffix(compressedInfo), size: expandedInfo, flags: flags))
        } else {
            infoReader = BinaryReader(data: try Self.expand(reader.bytes(compressedInfo), size: expandedInfo, flags: flags))
        }
        try infoReader.skip(16)
        let blockCount = Int(try infoReader.integer(UInt32.self))
        guard blockCount <= 65_536 else { throw ModelImportError.budgetExceeded }
        var blocks: [(Int, Int, UInt32)] = []
        var total = 0
        for _ in 0..<blockCount {
            let expanded = Int(try infoReader.integer(UInt32.self))
            let compressed = Int(try infoReader.integer(UInt32.self))
            let blockFlags = UInt32(try infoReader.integer(UInt16.self))
            guard expanded <= Self.maximumExpandedBytes - total else { throw ModelImportError.budgetExceeded }
            total += expanded; blocks.append((expanded, compressed, blockFlags))
        }
        let nodeCount = Int(try infoReader.integer(UInt32.self))
        guard nodeCount <= 4096 else { throw ModelImportError.budgetExceeded }
        var nodes: [(Int, Int, String)] = []
        var names = Set<String>()
        for _ in 0..<nodeCount {
            let offset = try infoReader.integer(UInt64.self), size = try infoReader.integer(UInt64.self)
            _ = try infoReader.integer(UInt32.self)
            let name = try infoReader.zeroString()
            guard offset <= total, size <= UInt64(total) - offset, !name.isEmpty, !name.contains("/"), !name.contains("\\"), name != "..", names.insert(name).inserted else {
                throw ModelImportError.malformed("archive entry")
            }
            nodes.append((Int(offset), Int(size), name))
        }
        if flags & 512 != 0 { try reader.align(16) }
        var unpacked = Data(); unpacked.reserveCapacity(total)
        for (expanded, compressed, blockFlags) in blocks {
            unpacked.append(try Self.expand(reader.bytes(compressed), size: expanded, flags: blockFlags))
        }
        entries = nodes.map { .init(name: $0.2, data: unpacked.subdata(in: $0.0..<($0.0 + $0.1))) }
        expandedBytes = total
    }

    static func normalizeTransport(_ input: Data) throws -> Data {
        var data = input
        if data.starts(with: [0x10, 0, 0, 0]) {
            guard data.count >= 132 else { throw ModelImportError.malformed("truncated transport header") }
            data.removeFirst(4); data = Data(data)
            for i in stride(from: 0, to: 128, by: 8) { for j in 0..<5 { data[i + j] ^= 255 } }
        }
        return data
    }

    private static func expand(_ source: Data, size: Int, flags: UInt32) throws -> Data {
        guard size >= 0, size <= maximumExpandedBytes else { throw ModelImportError.budgetExceeded }
        if flags & 63 == 0 {
            guard source.count == size else { throw ModelImportError.malformed("uncompressed block length") }
            return source
        }
        guard flags & 63 == 2 || flags & 63 == 3 else { throw ModelImportError.unsupported("UnityFS compression \(flags & 63)") }
        if size == 0 { return Data() }
        var result = Data(count: size)
        let written = result.withUnsafeMutableBytes { out in
            source.withUnsafeBytes { input in
                compression_decode_buffer(out.bindMemory(to: UInt8.self).baseAddress!, size, input.bindMemory(to: UInt8.self).baseAddress!, source.count, nil, COMPRESSION_LZ4_RAW)
            }
        }
        guard written == size else { throw ModelImportError.malformed("LZ4 block") }
        return result
    }
}
