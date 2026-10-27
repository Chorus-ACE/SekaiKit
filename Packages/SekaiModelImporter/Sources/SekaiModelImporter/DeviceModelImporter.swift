import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import simd
import CTextureDecoder

/// Pure on-device conversion; no .NET, subprocess, server-converted mesh or texture.
/// Preserves Unity geometry, rigs, controller data and animation for the local renderer.
public enum DeviceModelImporter {
    static func skinBonePalette(_ bones: [Int?], indices: [Float], weights: [Float], fallback: Int?) throws -> [Int] {
        guard indices.count == weights.count, indices.count % 4 == 0 else { throw ModelImportError.malformed("skin influence channels") }
        var weightedSlots = Set<Int>()
        for (index, weight) in zip(indices, weights) {
            guard weight.isFinite, weight >= 0 else { throw ModelImportError.malformed("skin influence weight") }
            if weight > 0 {
                guard index.isFinite, index >= 0, index < Float(bones.count), index.rounded(.towardZero) == index else { throw ModelImportError.malformed("skin influence index") }
                weightedSlots.insert(Int(index))
            }
        }
        return try bones.enumerated().map { slot, bone in
            if let bone { return bone }
            // Null slots are legal only when no vertex references them. Retain
            // their index: removing one would shift all subsequent influences.
            guard !weightedSlots.contains(slot), !weights.isEmpty, let fallback else {
                throw ModelImportError.malformed("missing weighted skin bone \(slot)")
            }
            return fallback
        }
    }
    public static var thirdPartyNotices: String {
        guard let url = Bundle.module.url(forResource: "DeviceModelThirdPartyNotices", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text
    }
    public static let revision = "native-character-v2"
    public static func convert(bundles: [Data], variationBundleIndices: Set<Int> = []) throws -> DeviceModelConversion {
        let start = Date()
        guard !bundles.isEmpty, bundles.count <= 32, bundles.reduce(0, { $0 + $1.count }) <= 64 * 1024 * 1024 else { throw ModelImportError.budgetExceeded }
        var files: [String: UnitySerializedFile] = [:], resources: [String: Data] = [:]
        var expanded = 0, variationFiles = Set<String>()
        for (bundleIndex, bundle) in bundles.enumerated() {
            try Task.checkCancellation()
            let archive = try UnityFSArchive(data: bundle)
            expanded += archive.expandedBytes
            guard expanded <= 128 * 1024 * 1024 else { throw ModelImportError.budgetExceeded }
            for entry in archive.entries {
                let key = entry.name.lowercased()
                if variationBundleIndices.contains(bundleIndex) { variationFiles.insert(key) }
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
        context.variationFiles = variationFiles
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
    var variationFiles = Set<String>()
    var identifiers: [ObjectKey: Int] = [:]

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
        var allTextures: [String: String] = [:], transforms: [String: [Float]] = [:]
        for entry in envs {
            let name = entry["first"].text, env = entry["second"]
            if let key = try pointer(env["m_Texture"], in: key.file) {
                allTextures[name] = try texture(key)
                transforms[name] = [env["m_Scale"]["x"].float, env["m_Scale"]["y"].float, env["m_Offset"]["x"].float, env["m_Offset"]["y"].float]
            }
        }
        var floats: [String: Float] = [:], colors: [String: [Float]] = [:]
        for entry in saved["m_Floats"].array + saved["m_Ints"].array { floats[entry["first"].text] = entry["second"].float }
        for entry in saved["m_Colors"].array { colors[entry["first"].text] = ["r","g","b","a"].map { entry["second"][$0].float } }
        if !variationFiles.isEmpty {
            let lower = name.lowercased()
            if !(lower.contains("face") || lower.contains("eye")) {
                let markers: [(String, [String])] = [("_MainTex",["_c","main","diffuse"]),("_ShadowTex",["_s","shadow"]),("_ValueTex",["_h","_v","value"]),("_FaceShadowTex",["faceshadow","face_shadow"])]
                for (property, hints) in markers {
                    let candidates = objects.keys.filter { variationFiles.contains($0.file) && classID($0) == 28 }.sorted { $0.id < $1.id }
                    if let key = try candidates.first(where: { key in let n = try object(key)["m_Name"].text.lowercased(); return hints.contains(where: { n.contains($0) }) }) {
                        allTextures[property] = try texture(key)
                        if property == "_MainTex" { texturePath = allTextures[property] }
                    }
                }
            }
        }
        var output = DeviceModelScene.Material(name: name, texture: texturePath, color: color, transparent: color[3] < 0.99 || name.lowercased().contains("alpha"))
        output.validKeywords = v["m_ValidKeywords"].array.map(\.text) + v["m_ShaderKeywords"].text.split(separator: " ").map(String.init)
        output.invalidKeywords = v["m_InvalidKeywords"].array.map(\.text)
        output.textures = allTextures; output.textureTransforms = transforms; output.floats = floats; output.colors = colors
        materials.append(output)
        materialIndices[key] = index; return index
    }

    func convert(bundleCount: Int, start: Date) throws -> DeviceModelConversion {
        let ordered = objects.keys.sorted { $0.file == $1.file ? $0.id < $1.id : $0.file < $1.file }
        identifiers = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($0.element, $0.offset + 1) })
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
        guard !prefabRoots.isEmpty || ordered.contains(where: { classID($0) == 74 }) else { throw ModelImportError.unsupported("no recognized part prefab") }
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
            var output = DeviceModelScene.Mesh(name: mesh["m_Name"].text, positions: geometry.positions, normals: geometry.normals, uv: geometry.uv, indices: geometry.indices, groups: groups, matrix: elements)
            output.transformID = identifiers[transform]
            output.rootBoneID = try pointer(renderer["m_RootBone"], in: key.file).flatMap { identifiers[$0] }
            let rendererBones: [Int?] = try renderer["m_Bones"].array.map { ref in
                guard let bone = try pointer(ref, in: key.file) else { return nil }
                guard let id = identifiers[bone], classID(bone) == 4 else { throw ModelImportError.malformed("missing skin bone in \(output.name)") }
                return id
            }
            output.boneIDs = classID(key) == 137 ? try DeviceModelImporter.skinBonePalette(rendererBones, indices: geometry.extra[13] ?? [], weights: geometry.extra[12] ?? [], fallback: output.rootBoneID ?? output.transformID) : []
            output.boneNameHashes = mesh["m_BoneNameHashes"].array.map { UInt32(truncatingIfNeeded: $0.int) }
            output.inverseBindMatrices = mesh["m_BindPose"].array.flatMap { matrix in (0..<4).flatMap { col in (0..<4).map { row in matrix["e\(row)\(col)"].float } } }
            output.skinIndices = geometry.extra[13]; output.skinWeights = geometry.extra[12]
            output.tangents = geometry.extra[2]
            output.uv1 = geometry.extra[5]; output.uv2 = geometry.extra[6]; output.colors = geometry.extra[3]
            let shapes = mesh["m_Shapes"], vertices = shapes["vertices"].array, frames = shapes["shapes"].array
            output.morphTargets = try shapes["channels"].array.compactMap { channel in
                let frameIndex = channel["frameIndex"].int, frameCount = channel["frameCount"].int
                guard frameCount > 0, frames.indices.contains(frameIndex) else { return nil }
                let frame = frames[frameIndex], first = frame["firstVertex"].int, count = frame["vertexCount"].int
                guard first >= 0, count >= 0, first <= vertices.count, count <= vertices.count - first else { throw ModelImportError.malformed("morph vertices") }
                let slice = vertices[first..<(first+count)]
                return .object(["name": .string(channel["name"].text),
                    "indices": .array(slice.map { .number(Double($0["index"].int)) }),
                    "hasPositionDeltas": .bool(true), "hasNormalDeltas": .bool(frame["hasNormals"].int != 0),
                    "positionDeltas": .array(slice.flatMap { value in ["x","y","z"].map { .number(Double(value["vertex"][$0].float)) } }),
                    "normalDeltas": .array(slice.flatMap { value in ["x","y","z"].map { .number(Double(value["normal"][$0].float)) } })])
            }
            meshes.append(output)
        }
        guard !meshes.isEmpty || ordered.contains(where: { classID($0) == 74 }) else { throw ModelImportError.unsupported("no active mesh renderers") }
        var scene = DeviceModelScene(meshes: meshes, materials: materials, warnings: [])
        func path(_ key: ObjectKey, depth: Int = 0) throws -> String {
            guard depth < 128 else { throw ModelImportError.malformed("transform path depth") }
            let v = try object(key)
            let name = try pointer(v["m_GameObject"], in: key.file).map { try object($0)["m_Name"].text } ?? ""
            if let parent = try pointer(v["m_Father"], in: key.file) { return try path(parent, depth: depth + 1) + "/" + name }
            return name
        }
        scene.nodes = try ordered.filter { classID($0) == 4 }.map { key in
            let v = try object(key)
            return .init(id: identifiers[key]!, name: try path(key).split(separator: "/").last.map(String.init) ?? "", path: try path(key),
                parentID: try pointer(v["m_Father"], in: key.file).flatMap { identifiers[$0] },
                position: ["x","y","z"].map { v["m_LocalPosition"][$0].float },
                rotation: ["x","y","z","w"].map { v["m_LocalRotation"][$0].float },
                scale: ["x","y","z"].map { v["m_LocalScale"][$0].float })
        }
        scene.behaviours = try ordered.filter { classID($0) == 114 }.map { key in
            let v = try object(key)
            let script = try pointer(v["m_Script"], in: key.file).map { try object($0)["m_ClassName"].text } ?? ""
            let go = try pointer(v["m_GameObject"], in: key.file)
            return .init(id: identifiers[key]!, nodeID: go.flatMap { transformsByGameObject[$0] }.flatMap { identifiers[$0] }, script: script, data: try json(v, file: key.file))
        }
        scene.animationClips = try ordered.filter { classID($0) == 74 }.map { try json(object($0), file: $0.file) }
        return .init(scene: scene, texturePNGs: textures, bundleCount: bundleCount, objectCount: values.count, vertexCount: vertexCount, elapsedSeconds: Date().timeIntervalSince(start))

    }
    func json(_ value: UnityValue, file: String) throws -> ModelJSON {
        switch value {
        case .integer(let n): return .number(Double(n))
        case .unsigned(let n): return .number(Double(n))
        case .number(let n): return n.isFinite ? .number(n) : .null
        case .string(let s): return .string(s)
        case .bytes(let data): return .object(["base64": .string(data.base64EncodedString())])
        case .array(let a): return .array(try a.map { try json($0, file: file) })
        case .object(let o):
            if o["m_PathID"] != nil && o["m_FileID"] != nil {
                return .object(["m_PathID": .number(Double(try pointer(value, in: file).flatMap { identifiers[$0] } ?? 0)), "m_FileID": .number(0)])
            }
            return .object(try o.mapValues { try json($0, file: file) })
        }
    }
    func classID(_ key: ObjectKey) -> Int {
        guard let info = objects[key], let file = files[key.file] else { return -1 }
        return file.types[info.typeIndex].classID
    }

    func geometry(_ mesh: UnityValue) throws -> (positions: [Float], normals: [Float], uv: [Float], indices: [UInt32], groups: [(Int, Int)], extra: [Int: [Float]]) {
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
            guard dimension >= components || [3,12,13].contains(index) else { throw ModelImportError.malformed("vertex dimensions") }
            let stream = ch["stream"].int, format = ch["format"].int, stride = strides[stream]
            let base = offsets[stream] + ch["offset"].int
            guard base >= 0, base <= data.count, (count - 1) * stride + min(components, dimension) * sizes[format] <= data.count - base else { throw ModelImportError.malformed("vertex buffer") }
            var values: [Float] = []; values.reserveCapacity(count * components)
            for v in 0..<count {
                var r = BinaryReader(data: data, position: base + v * stride, littleEndian: true)
                for component in 0..<components {
                    if component >= dimension { values.append(index == 3 && component == 3 ? 1 : 0); continue }
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
        var extra: [Int: [Float]] = [:]
        for (index, components) in [(2,4),(3,4),(5,2),(6,2),(12,4),(13,4)] { extra[index] = try channel(index, components: components) }
        if extra[12]?.isEmpty == true, extra[13]?.count == count * 4, channels.count > 13, channels[13]["dimension"].int & 15 == 1 {
            extra[12] = (0..<count).flatMap { _ in [Float(1),0,0,0] }
        }
        return (positions, normals, uv, indices, groups, extra)
    }
}
