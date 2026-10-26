import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import simd
import CTextureDecoder

/// Pure on-device conversion; no .NET, subprocess, server-converted mesh or texture.
/// The first implementation deliberately exports a rest-pose preview rather than
/// claiming parity with Haruki's animation, character controllers or spring bones.
public enum DeviceModelImporter {
    public static var thirdPartyNotices: String {
        guard let url = Bundle.module.url(forResource: "DeviceModelThirdPartyNotices", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text
    }
    public static let revision = "native-rest-pose-v1"
    public static func convert(bundles: [Data]) throws -> DeviceModelConversion {
        let start = Date()
        guard !bundles.isEmpty, bundles.count <= 32, bundles.reduce(0, { $0 + $1.count }) <= 64 * 1024 * 1024 else { throw ModelImportError.budgetExceeded }
        var files: [String: UnitySerializedFile] = [:], resources: [String: Data] = [:]
        var expanded = 0
        for bundle in bundles {
            try Task.checkCancellation()
            let archive = try UnityFSArchive(data: bundle)
            expanded += archive.expandedBytes
            guard expanded <= 128 * 1024 * 1024 else { throw ModelImportError.budgetExceeded }
            for entry in archive.entries {
                let key = entry.name.lowercased()
                if entry.name.hasSuffix(".resS") || entry.name.hasSuffix(".resource") {
                    if let old = resources[key], old != entry.data { throw ModelImportError.malformed("conflicting resource files") }
                    resources[key] = entry.data
                } else {
                    if let old = files[key], old.data != entry.data { throw ModelImportError.malformed("conflicting serialized files") }
                    files[key] = try UnitySerializedFile(name: key, data: entry.data)
                }
            }
        }
        let context = Context(files: files, resources: resources)
        return try context.convert(bundleCount: bundles.count, start: start)
    }
}

private struct ObjectKey: Hashable { let file: String; let id: Int64 }
private final class Context {
    let files: [String: UnitySerializedFile]
    let resources: [String: Data]
    var objects: [ObjectKey: UnitySerializedFile.ObjectInfo] = [:]
    var values: [ObjectKey: UnityValue] = [:]
    var worldMatrices: [ObjectKey: simd_float4x4] = [:]
    var transformsByGameObject: [ObjectKey: ObjectKey] = [:]
    var textures: [String: Data] = [:]
    var texturePaths: [ObjectKey: String] = [:]
    var materialIndices: [ObjectKey: Int] = [:]
    var materials: [DeviceModelScene.Material] = []
    var texturePixels = 0

    init(files: [String: UnitySerializedFile], resources: [String: Data]) {
        self.files = files; self.resources = resources
        for (name, file) in files { for object in file.objects { objects[.init(file: name, id: object.pathID)] = object } }
    }
    func object(_ key: ObjectKey) throws -> UnityValue {
        if let value = values[key] { return value }
        guard let file = files[key.file], let info = objects[key] else { throw ModelImportError.missingDependency(key.file) }
        let value = try file.read(info); values[key] = value; return value
    }
    func pointer(_ value: UnityValue, in file: String) throws -> ObjectKey? {
        let id = value["m_PathID"].int
        if id == 0 { return nil }
        let fileID = value["m_FileID"].int
        if fileID == 0 { return .init(file: file, id: Int64(id)) }
        guard let source = files[file], fileID > 0, fileID <= source.externals.count else { throw ModelImportError.malformed("external pointer") }
        let name = source.externals[fileID - 1].lowercased()
        guard files[name] != nil else { throw ModelImportError.missingDependency(name) }
        return .init(file: name, id: Int64(id))
    }
    func world(_ key: ObjectKey, visited: Set<ObjectKey> = []) throws -> simd_float4x4 {
        if let matrix = worldMatrices[key] { return matrix }
        guard !visited.contains(key), visited.count <= 128 else { throw ModelImportError.malformed("cyclic transform graph") }
        let v = try object(key)
        func vector(_ name: String, fallback: Float = 0) -> SIMD3<Float> {
            let f = v[name].fields
            return SIMD3(f["x"]?.float ?? fallback, f["y"]?.float ?? fallback, f["z"]?.float ?? fallback)
        }
        let p = vector("m_LocalPosition"), s = vector("m_LocalScale", fallback: 1), q = v["m_LocalRotation"]
        let rotation = simd_quatf(ix: q["x"].float, iy: q["y"].float, iz: q["z"].float, r: q["w"].float)
        guard p.x.isFinite, p.y.isFinite, p.z.isFinite, s.x.isFinite, s.y.isFinite, s.z.isFinite,
              rotation.vector.x.isFinite, rotation.vector.y.isFinite, rotation.vector.z.isFinite, rotation.vector.w.isFinite else { throw ModelImportError.malformed("transform numbers") }
        var matrix = simd_float4x4(rotation)
        matrix.columns.0 *= s.x; matrix.columns.1 *= s.y; matrix.columns.2 *= s.z
        matrix.columns.3 = SIMD4(p, 1)
        if let parent = try pointer(v["m_Father"], in: key.file) { matrix = try world(parent, visited: visited.union([key])) * matrix }
        worldMatrices[key] = matrix
        return matrix
    }
    func stream(_ value: UnityValue) throws -> Data {
        let path = value["path"].text
        guard let name = path.split(separator: "/").last.map(String.init), let data = resources[name.lowercased()] else { throw ModelImportError.missingDependency(path) }
        let offset = value["offset"].int, size = value["size"].int
        guard offset >= 0, size >= 0, offset <= data.count, size <= data.count - offset else { throw ModelImportError.malformed("streamed resource bounds") }
        return data.subdata(in: offset..<(offset + size))
    }
    func texture(_ key: ObjectKey) throws -> String {
        if let result = texturePaths[key] { return result }
        let v = try object(key)
        let width = v["m_Width"].int, height = v["m_Height"].int, format = v["m_TextureFormat"].int
        guard (1...4096).contains(width), (1...4096).contains(height), width * height <= 16_777_216 - texturePixels else { throw ModelImportError.budgetExceeded }
        texturePixels += width * height
        var encoded = v["image data"].data
        if encoded.isEmpty { encoded = try stream(v["m_StreamData"]) }
        let outputBytes = width * height * 4
        var rgba = Data(count: outputBytes)
        let valid = rgba.withUnsafeMutableBytes { dest in encoded.withUnsafeBytes { source in
            sekai_decode_texture(source.bindMemory(to: UInt8.self).baseAddress, encoded.count, Int32(width), Int32(height), Int32(format), dest.bindMemory(to: UInt8.self).baseAddress, outputBytes)
        } }
        guard valid != 0 else { throw ModelImportError.unsupported("texture format \(format) or invalid texture bytes") }
        guard let provider = CGDataProvider(data: rgba as CFData), let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { throw ModelImportError.malformed("texture image") }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil) else { throw ModelImportError.malformed("PNG encoder") }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ModelImportError.malformed("PNG encoding") }
        let png = output as Data
        let hash = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined()
        let path = "textures/\(hash).png"
        textures[path] = png; texturePaths[key] = path
        return path
    }
    func material(_ key: ObjectKey) throws -> Int {
        if let index = materialIndices[key] { return index }
        let v = try object(key), saved = v["m_SavedProperties"]
        let envs = saved["m_TexEnvs"].array
        var texturePath: String?
        for name in ["_MainTex", "_BaseMap", "_BaseColorMap"] {
            if let env = envs.first(where: { $0["first"].text == name }), let textureKey = try pointer(env["second"]["m_Texture"], in: key.file) {
                texturePath = try texture(textureKey); break
            }
        }
        var color: [Float] = [1, 1, 1, 1]
        if let entry = saved["m_Colors"].array.first(where: { $0["first"].text == "_Color" }) {
            color = ["r","g","b","a"].map { entry["second"][$0].float }
        }
        let index = materials.count
        let name = v["m_Name"].text
        // Main textures remain unlit in this structural preview. Full SEKAI
        // shader/controller semantics belong to the Haruki integration stage.
        materials.append(.init(name: name, texture: texturePath, color: color, transparent: color[3] < 0.99 || name.lowercased().contains("alpha")))
        materialIndices[key] = index; return index
    }

    func convert(bundleCount: Int, start: Date) throws -> DeviceModelConversion {
        let ordered = objects.keys.sorted { $0.file == $1.file ? $0.id < $1.id : $0.file < $1.file }
        for key in ordered where classID(key) == 4 {
            let v = try object(key)
            if let go = try pointer(v["m_GameObject"], in: key.file) { transformsByGameObject[go] = key }
        }
        var prefabRoots = Set<ObjectKey>()
        for key in ordered where classID(key) == 142 {
            for item in try object(key)["m_Container"].array {
                let path = item["first"].text.lowercased()
                if ["/body.prefab", "/face.prefab", "/optional.prefab"].contains(where: path.hasSuffix),
                   let root = try pointer(item["second"]["asset"], in: key.file), classID(root) == 1 { prefabRoots.insert(root) }
            }
        }
        guard !prefabRoots.isEmpty else { throw ModelImportError.unsupported("no recognized part prefab") }
        func isInActivePrefab(_ key: ObjectKey) throws -> Bool {
            var current: ObjectKey? = key, visited = Set<ObjectKey>()
            while let transform = current {
                guard visited.count < 128, visited.insert(transform).inserted else { throw ModelImportError.malformed("cyclic prefab hierarchy") }
                let value = try object(transform)
                if let go = try pointer(value["m_GameObject"], in: transform.file) {
                    if try object(go).fields["m_IsActive"]?.int == 0 { return false }
                    if prefabRoots.contains(go) { return true }
                }
                current = try pointer(value["m_Father"], in: transform.file)
            }
            return false
        }
        var meshes: [DeviceModelScene.Mesh] = [], vertexCount = 0
        for key in ordered where [137, 23].contains(classID(key)) {
            try Task.checkCancellation()
            let renderer = try object(key)
            if renderer.fields["m_Enabled"]?.int == 0 { continue }
            guard let go = try pointer(renderer["m_GameObject"], in: key.file), let transform = transformsByGameObject[go] else { continue }
            guard try isInActivePrefab(transform) else { continue }
            let gameObject = try object(go)
            if gameObject.fields["m_IsActive"]?.int == 0 { continue }
            var meshPointer = renderer["m_Mesh"]
            if classID(key) == 23 {
                for component in gameObject["m_Component"].array {
                    let p = component.fields["component"] ?? component["second"]
                    if let filter = try pointer(p, in: go.file), classID(filter) == 33 { meshPointer = try object(filter)["m_Mesh"]; break }
                }
            }
            guard let meshKey = try pointer(meshPointer, in: key.file) else { continue }
            let mesh = try object(meshKey)
            let geometry = try geometry(mesh)
            vertexCount += geometry.positions.count / 3
            guard vertexCount <= 500_000 else { throw ModelImportError.budgetExceeded }
            let refs = renderer["m_Materials"].array
            var groups: [DeviceModelScene.Group] = []
            for (i, group) in geometry.groups.enumerated() {
                guard i < refs.count, let ref = try pointer(refs[i], in: key.file) else { throw ModelImportError.malformed("renderer materials") }
                groups.append(.init(start: group.0, count: group.1, material: try material(ref)))
            }
            let matrix = try world(transform)
            let elements = (0..<4).flatMap { col in (0..<4).map { row in matrix[col][row] } }
            meshes.append(.init(name: mesh["m_Name"].text, positions: geometry.positions, normals: geometry.normals, uv: geometry.uv, indices: geometry.indices, groups: groups, matrix: elements))
        }
        guard !meshes.isEmpty else { throw ModelImportError.unsupported("no active mesh renderers") }
        return .init(scene: .init(meshes: meshes, materials: materials, warnings: ["Authored rest pose; animation, SEKAI shader effects and spring bones are not enabled in this prototype."]), texturePNGs: textures, bundleCount: bundleCount, objectCount: values.count, vertexCount: vertexCount, elapsedSeconds: Date().timeIntervalSince(start))
    }
    func classID(_ key: ObjectKey) -> Int {
        guard let info = objects[key], let file = files[key.file] else { return -1 }
        return file.types[info.typeIndex].classID
    }

    func geometry(_ mesh: UnityValue) throws -> (positions: [Float], normals: [Float], uv: [Float], indices: [UInt32], groups: [(Int, Int)]) {
        guard mesh["m_CompressedMesh"]["m_Vertices"]["m_NumItems"].int == 0 else { throw ModelImportError.unsupported("packed mesh vertices") }
        let vertex = mesh["m_VertexData"], count = vertex["m_VertexCount"].int
        guard count > 0, count <= 500_000 else { throw ModelImportError.budgetExceeded }
        var data = vertex["m_DataSize"].data
        if data.isEmpty { data = try stream(mesh["m_StreamData"]) }
        let channels = vertex["m_Channels"].array
        guard channels.count <= 16 else { throw ModelImportError.budgetExceeded }
        let sizes = [4,2,1,1,2,2,1,1,2,2,4,4]
        var strides = [Int](repeating: 0, count: 16)
        for channel in channels {
            let dim = channel["dimension"].int & 15, stream = channel["stream"].int, format = channel["format"].int, offset = channel["offset"].int
            guard dim <= 4, (0..<16).contains(stream), sizes.indices.contains(format), offset >= 0, offset <= 256 else { throw ModelImportError.unsupported("vertex channel") }
            if dim > 0 { strides[stream] = max(strides[stream], offset + dim * sizes[format]) }
        }
        var offsets = [Int](repeating: 0, count: 16), end = 0
        for i in strides.indices { offsets[i] = end; end += count * strides[i]; end = (end + 15) & ~15 }
        func channel(_ index: Int, components: Int) throws -> [Float] {
            guard index < channels.count else { return [] }
            let ch = channels[index], dimension = ch["dimension"].int & 15
            if dimension == 0 { return [] }
            guard dimension >= components else { throw ModelImportError.malformed("vertex dimensions") }
            let stream = ch["stream"].int, format = ch["format"].int, stride = strides[stream]
            let base = offsets[stream] + ch["offset"].int
            guard base >= 0, base <= data.count, (count - 1) * stride + components * sizes[format] <= data.count - base else { throw ModelImportError.malformed("vertex buffer") }
            var values: [Float] = []; values.reserveCapacity(count * components)
            for v in 0..<count {
                var r = BinaryReader(data: data, position: base + v * stride, littleEndian: true)
                for _ in 0..<components {
                    let f: Float
                    switch format {
                    case 0: f = Float(bitPattern: try r.integer(UInt32.self))
                    case 1: f = Float(Float16(bitPattern: try r.integer(UInt16.self)))
                    case 2: f = Float(try r.integer(UInt8.self)) / 255
                    case 3: f = max(-1, Float(try r.integer(Int8.self)) / 127)
                    case 4: f = Float(try r.integer(UInt16.self)) / 65535
                    case 5: f = max(-1, Float(try r.integer(Int16.self)) / 32767)
                    case 6: f = Float(try r.integer(UInt8.self))
                    case 7: f = Float(try r.integer(Int8.self))
                    case 8: f = Float(try r.integer(UInt16.self))
                    case 9: f = Float(try r.integer(Int16.self))
                    case 10: f = Float(try r.integer(UInt32.self))
                    case 11: f = Float(try r.integer(Int32.self))
                    default: throw ModelImportError.unsupported("vertex component format")
                    }
                    guard f.isFinite else { throw ModelImportError.malformed("non-finite vertex") }
                    values.append(f)
                }
            }
            return values
        }
        let positions = try channel(0, components: 3), normals = try channel(1, components: 3), uv = try channel(4, components: 2)
        guard positions.count == count * 3 else { throw ModelImportError.malformed("missing positions") }
        let indexData = mesh["m_IndexBuffer"].data
        let indexSize = mesh["m_IndexFormat"].int == 0 ? 2 : 4
        var indices: [UInt32] = [], groups: [(Int, Int)] = []
        for submesh in mesh["m_SubMeshes"].array {
            guard submesh["topology"].int == 0 else { throw ModelImportError.unsupported("non-triangle mesh") }
            let offset = submesh["firstByte"].int, length = submesh["indexCount"].int, base = submesh["baseVertex"].int
            guard offset >= 0, offset <= indexData.count, length >= 0, length <= 3_000_000, length % 3 == 0, length * indexSize <= indexData.count - offset else { throw ModelImportError.malformed("mesh indices") }
            groups.append((indices.count, length))
            var r = BinaryReader(data: indexData, position: offset, littleEndian: true)
            for _ in 0..<length {
                let value = indexSize == 2 ? Int(try r.integer(UInt16.self)) : Int(try r.integer(UInt32.self))
                guard base >= 0, base < count, value < count - base else { throw ModelImportError.malformed("vertex index") }
                indices.append(UInt32(value + base))
            }
        }
        return (positions, normals, uv, indices, groups)
    }
}
