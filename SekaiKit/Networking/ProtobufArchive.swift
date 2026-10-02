import Foundation
internal import AppleArchive

internal enum ProtobufArchive {
    enum Failure: Error {
        case invalidArchive
        case unexpectedEntry
        case invalidSize
    }

    /// Reads one named regular file without extracting archive paths to disk.
    static func decode(_ data: Data, expectedFile: String) throws -> Data {
        guard !data.isEmpty else { throw Failure.invalidArchive }
        return try ArchiveByteStream.withTemporaryFileStream { input in
            let written = try data.withUnsafeBytes { try input.write(from: $0) }
            guard written == data.count else { throw Failure.invalidArchive }
            _ = try input.seek(toOffset: 0, relativeTo: .start)
            return try ArchiveByteStream.withDecompressionStream(readingFrom: input, threadCount: 1) { decompressed in
                try ArchiveStream.withDecodeStream(readingFrom: decompressed, threadCount: 1) { archive in
                    var result: Data?
                    while let header = try archive.readHeader() {
                        if header.entryType == .metadata { continue }
                        guard header.entryType == .regularFile,
                              case .string(_, let path) = header.field(forKey: .init("PAT")),
                              path == expectedFile, result == nil else {
                            throw Failure.unexpectedEntry
                        }
                        guard case .blob(_, let size, _) = header.field(forKey: .init("DAT")),
                              size > 0, size <= 256 * 1024 * 1024 else {
                            throw Failure.invalidSize
                        }
                        var bytes = Data(count: Int(size))
                        try bytes.withUnsafeMutableBytes { try archive.readBlob(key: .init("DAT"), into: $0) }
                        result = bytes
                    }
                    guard let result else { throw Failure.invalidArchive }
                    return result
                }
            }
        }
    }
}
