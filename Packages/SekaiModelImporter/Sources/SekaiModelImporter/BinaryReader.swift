import Foundation

public enum ModelImportError: Error, LocalizedError, Sendable {
    case malformed(String), unsupported(String), budgetExceeded, missingDependency(String)
    public var errorDescription: String? {
        switch self {
        case .malformed(let detail): "Invalid Unity data: \(detail)"
        case .unsupported(let detail): "Unsupported Unity data: \(detail)"
        case .budgetExceeded: "The model exceeds the local processing budget."
        case .missingDependency(let name): "Missing model dependency: \(name)"
        }
    }
}

struct BinaryReader {
    let data: Data
    var position = 0
    var littleEndian = false
    mutating func bytes(_ count: Int) throws -> Data {
        guard count >= 0, position >= 0, count <= data.count - position else { throw ModelImportError.malformed("truncated buffer") }
        defer { position += count }
        return data.subdata(in: position..<(position + count))
    }
    mutating func skip(_ count: Int) throws {
        guard count >= 0, position >= 0, count <= data.count - position else { throw ModelImportError.malformed("truncated buffer") }
        position += count
    }
    mutating func integer<T: FixedWidthInteger>(_ type: T.Type = T.self) throws -> T {
        let count = MemoryLayout<T>.size
        guard position >= 0, count <= data.count - position else { throw ModelImportError.malformed("truncated integer") }
        let raw = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: position, as: T.self) }
        position += count
        return littleEndian ? T(littleEndian: raw) : T(bigEndian: raw)
    }
    mutating func count(limit: Int = 2_000_000) throws -> Int {
        let n = Int(try integer(Int32.self))
        guard n >= 0, n <= limit else { throw ModelImportError.budgetExceeded }
        return n
    }
    mutating func align(_ alignment: Int = 4) throws {
        let padding = (alignment - position % alignment) % alignment
        try skip(padding)
    }
    mutating func zeroString(limit: Int = 4096) throws -> String {
        let start = position
        while position < data.count, position - start <= limit {
            if data[position] == 0 {
                let text = String(data: data.subdata(in: start..<position), encoding: .utf8)
                position += 1
                guard let text else { throw ModelImportError.malformed("invalid UTF-8") }
                return text
            }
            position += 1
        }
        throw ModelImportError.malformed("unterminated string")
    }
    mutating func string() throws -> String {
        let size = try count(limit: 4 * 1024 * 1024)
        let data = try bytes(size)
        try align()
        guard let value = String(data: data, encoding: .utf8) else { throw ModelImportError.malformed("invalid UTF-8") }
        return value
    }
}
