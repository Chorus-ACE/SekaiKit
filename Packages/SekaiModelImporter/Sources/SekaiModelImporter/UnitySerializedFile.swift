import Foundation

enum UnityValue: Sendable {
    case integer(Int64), unsigned(UInt64), number(Double), string(String), bytes(Data)
    case array([UnityValue]), object([String: UnityValue])
    subscript(_ name: String) -> UnityValue { if case .object(let v) = self { return v[name] ?? .object([:]) }; return .object([:]) }
    var int: Int { switch self { case .integer(let v): Int(exactly: v) ?? 0; case .unsigned(let v): Int(exactly: v) ?? 0; case .number(let v): v.isFinite && v >= Double(Int.min) && v < Double(Int.max) ? Int(v) : 0; default: 0 } }
    var float: Float { switch self { case .number(let v): Float(v); case .integer(let v): Float(v); case .unsigned(let v): Float(v); default: 0 } }
    var text: String { if case .string(let v) = self { v } else { "" } }
    var array: [UnityValue] { if case .array(let v) = self { v } else { [] } }
    var data: Data { if case .bytes(let v) = self { v } else { Data() } }
    var fields: [String: UnityValue] { if case .object(let v) = self { v } else { [:] } }
}

struct UnitySerializedFile {
    struct TypeNode { let type: String; let name: String; let level: Int; let size: Int; let flags: UInt32; var children: [Int] = [] }
    struct SerializedType { let classID: Int; let nodes: [TypeNode] }
    struct ObjectInfo { let pathID: Int64; let offset: Int; let size: Int; let typeIndex: Int }
    let name: String
    let data: Data
    let littleEndian: Bool
    let types: [SerializedType]
    let objects: [ObjectInfo]
    let externals: [String]

    init(name: String, data: Data) throws {
        self.name = name; self.data = data
        var r = BinaryReader(data: data)
        _ = try r.integer(UInt32.self); _ = try r.integer(UInt32.self)
        let version = try r.integer(UInt32.self)
        _ = try r.integer(UInt32.self)
        guard version == 22 else { throw ModelImportError.unsupported("serialized file version \(version)") }
        let endian = try r.integer(UInt8.self); try r.skip(3)
        _ = try r.integer(UInt32.self)
        let fileSize = try r.integer(UInt64.self), dataOffset = try r.integer(UInt64.self)
        try r.skip(8)
        guard fileSize == data.count, dataOffset <= data.count, endian <= 1 else { throw ModelImportError.malformed("serialized header") }
        r.littleEndian = endian == 0; littleEndian = r.littleEndian
        _ = try r.zeroString(); _ = try r.integer(Int32.self)
        let hasTypeTree = try r.integer(UInt8.self)
        guard hasTypeTree == 1 else { throw ModelImportError.unsupported("stripped type trees") }
        var parsedTypes: [SerializedType] = []
        for _ in 0..<(try r.count(limit: 4096)) {
            let classID = Int(try r.integer(Int32.self))
            _ = try r.integer(UInt8.self); _ = try r.integer(Int16.self)
            if classID == 114 { try r.skip(16) }
            try r.skip(16)
            let nodeCount = try r.count(limit: 65_536), stringBytes = try r.count(limit: 4 * 1024 * 1024)
            var rows: [(UInt32, UInt32, Int, Int, UInt32)] = []
            for _ in 0..<nodeCount {
                _ = try r.integer(UInt16.self)
                let level = Int(try r.integer(UInt8.self)); _ = try r.integer(UInt8.self)
                let type = try r.integer(UInt32.self), field = try r.integer(UInt32.self)
                let size = Int(try r.integer(Int32.self)); _ = try r.integer(Int32.self)
                let flags = try r.integer(UInt32.self); try r.skip(8)
                guard level <= 64 else { throw ModelImportError.budgetExceeded }
                rows.append((type, field, level, size, flags))
            }
            let strings = try r.bytes(stringBytes)
            func string(_ offset: UInt32) throws -> String {
                if offset & 0x8000_0000 != 0 {
                    guard let s = unityCommonStrings[offset & 0x7fff_ffff] else { throw ModelImportError.unsupported("common type string \(offset)") }
                    return s
                }
                guard offset < strings.count else { throw ModelImportError.malformed("type string offset") }
                var sr = BinaryReader(data: strings, position: Int(offset))
                return try sr.zeroString()
            }
            var nodes = try rows.map { TypeNode(type: try string($0.0), name: try string($0.1), level: $0.2, size: $0.3, flags: $0.4) }
            var parents: [Int] = []
            for i in nodes.indices {
                while let last = parents.last, nodes[last].level >= nodes[i].level { parents.removeLast() }
                if let p = parents.last {
                    guard nodes[i].level == nodes[p].level + 1 else { throw ModelImportError.malformed("type-tree depth") }
                    nodes[p].children.append(i)
                } else if i > 0 || nodes[i].level != 0 { throw ModelImportError.malformed("type-tree root") }
                parents.append(i)
            }
            try r.skip((try r.count(limit: 65_536)) * 4)
            parsedTypes.append(.init(classID: classID, nodes: nodes))
        }
        var parsedObjects: [ObjectInfo] = []
        var identities = Set<Int64>()
        for _ in 0..<(try r.count(limit: 100_000)) {
            try r.align()
            let id = try r.integer(Int64.self), relative = try r.integer(UInt64.self)
            let size = UInt64(try r.integer(UInt32.self)), index = Int(try r.integer(Int32.self))
            guard index >= 0, index < parsedTypes.count, relative <= UInt64(data.count) - dataOffset,
                  size <= UInt64(data.count) - dataOffset - relative, identities.insert(id).inserted else { throw ModelImportError.malformed("object table") }
            parsedObjects.append(.init(pathID: id, offset: Int(dataOffset + relative), size: Int(size), typeIndex: index))
        }
        for _ in 0..<(try r.count(limit: 100_000)) { try r.skip(4); try r.align(); try r.skip(8) }
        var externalNames: [String] = []
        for _ in 0..<(try r.count(limit: 4096)) {
            _ = try r.zeroString(); try r.skip(20)
            let path = try r.zeroString()
            externalNames.append(path.split(separator: "/").last.map(String.init) ?? path)
        }
        types = parsedTypes; objects = parsedObjects; externals = externalNames
    }

    func read(_ object: ObjectInfo) throws -> UnityValue {
        let nodes = types[object.typeIndex].nodes
        guard !nodes.isEmpty else { throw ModelImportError.unsupported("empty type tree") }
        var reader = BinaryReader(data: data.subdata(in: object.offset..<(object.offset + object.size)), littleEndian: littleEndian)
        var allocated = 0
        func value(_ index: Int, _ r: inout BinaryReader) throws -> UnityValue {
            let node = nodes[index]
            var needsAlignment = node.flags & 0x4000 != 0
            let result: UnityValue
            switch node.type {
            case "SInt8": result = .integer(Int64(try r.integer(Int8.self)))
            case "UInt8", "bool": result = .unsigned(UInt64(try r.integer(UInt8.self)))
            case "short", "SInt16": result = .integer(Int64(try r.integer(Int16.self)))
            case "UInt16", "unsigned short", "char": result = .unsigned(UInt64(try r.integer(UInt16.self)))
            case "int", "SInt32": result = .integer(Int64(try r.integer(Int32.self)))
            case "UInt32", "unsigned int", "Type*": result = .unsigned(UInt64(try r.integer(UInt32.self)))
            case "long long", "SInt64": result = .integer(try r.integer(Int64.self))
            case "UInt64", "unsigned long long", "FileSize": result = .unsigned(try r.integer(UInt64.self))
            case "float": result = .number(Double(Float(bitPattern: try r.integer(UInt32.self))))
            case "double": result = .number(Double(bitPattern: try r.integer(UInt64.self)))
            case "string" where node.children.first.map({ nodes[$0].type == "Array" }) == true: result = .string(try r.string())
            case "TypelessData": result = .bytes(try r.bytes(r.count(limit: UnityFSArchive.maximumExpandedBytes)))
            default:
                if let arrayIndex = node.children.first, nodes[arrayIndex].type == "Array" {
                    let array = nodes[arrayIndex]
                    guard array.children.count == 2 else { throw ModelImportError.malformed("array type") }
                    needsAlignment = needsAlignment || array.flags & 0x4000 != 0
                    let elementIndex = array.children[1], element = nodes[elementIndex]
                    let count = try r.count()
                    if element.size == 1, element.children.isEmpty, ["UInt8", "SInt8", "char"].contains(element.type) {
                        result = .bytes(try r.bytes(count))
                    } else {
                        guard count <= 2_000_000 - allocated else { throw ModelImportError.budgetExceeded }
                        allocated += count
                        var values: [UnityValue] = []; values.reserveCapacity(count)
                        for _ in 0..<count { values.append(try value(elementIndex, &r)) }
                        result = .array(values)
                    }
                } else if node.children.isEmpty, node.size == 0 { result = .object([:]) }
                else if node.children.isEmpty { throw ModelImportError.unsupported("type \(node.type)") }
                else {
                    var fields: [String: UnityValue] = [:]
                    for child in node.children { fields[nodes[child].name] = try value(child, &r) }
                    result = .object(fields)
                }
            }
            if needsAlignment { try r.align() }
            return result
        }
        let result = try value(0, &reader)
        guard reader.position == object.size else { throw ModelImportError.malformed("object byte count for class \(types[object.typeIndex].classID): \(reader.position)/\(object.size)") }
        return result
    }
}
