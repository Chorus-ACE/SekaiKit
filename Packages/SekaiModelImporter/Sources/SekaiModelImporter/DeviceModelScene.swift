import Foundation

/// Geometry imported on the device. Version 1 previews the authored rest pose;
/// animation, SEKAI shaders and spring-bone simulation are not yet applied.
public struct DeviceModelScene: Codable, Sendable {
    public var schemaVersion = 1
    public let meshes: [Mesh]
    public let materials: [Material]
    public let warnings: [String]
    public var nodes: [Node]? = nil
    public var behaviours: [Behaviour]? = nil
    public var animationClips: [ModelJSON]? = nil
    public struct Mesh: Codable, Sendable {
        public let name: String
        public let positions: [Float]
        public let normals: [Float]
        public let uv: [Float]
        public let indices: [UInt32]
        public let groups: [Group]
        public let matrix: [Float]
        public var rootBoneID: Int? = nil
        public var transformID: Int? = nil
        public var boneNameHashes: [UInt32]? = nil
        public var boneIDs: [Int]? = nil
        public var inverseBindMatrices: [Float]? = nil
        public var skinIndices: [Float]? = nil
        public var skinWeights: [Float]? = nil
        public var tangents: [Float]? = nil
        public var uv1: [Float]? = nil
        public var uv2: [Float]? = nil
        public var colors: [Float]? = nil
        public var morphTargets: [ModelJSON]? = nil
    }
    public struct Group: Codable, Sendable { public let start: Int; public let count: Int; public let material: Int }
    public struct Material: Codable, Sendable {
        public let name: String
        public let texture: String?
        public let color: [Float]
        public let transparent: Bool
        public var textures: [String: String]? = nil
        public var floats: [String: Float]? = nil
        public var colors: [String: [Float]]? = nil
        public var validKeywords: [String]? = nil
        public var invalidKeywords: [String]? = nil
        public var textureTransforms: [String: [Float]]? = nil
    }
}
public struct DeviceModelConversion: Sendable {
    public let scene: DeviceModelScene
    public let texturePNGs: [String: Data]
    public let bundleCount: Int
    public let objectCount: Int
    public let vertexCount: Int
    public let elapsedSeconds: Double
}

public extension DeviceModelScene {
    struct Node: Codable, Sendable {
        public let id: Int
        public let name: String
        public let path: String
        public let parentID: Int?
        public let position: [Float]
        public let rotation: [Float]
        public let scale: [Float]
    }
    struct Behaviour: Codable, Sendable {
        public let id: Int
        public let nodeID: Int?
        public let script: String
        public let data: ModelJSON
    }
}
/// Lossless structured metadata for Unity controllers and clip curves. Large
/// vertex buffers are emitted as typed scene fields, never duplicated here.
public enum ModelJSON: Codable, Sendable {
    case object([String: ModelJSON]), array([ModelJSON]), number(Double), string(String), bool(Bool), null
    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([ModelJSON].self) { self = .array(v) }
        else { self = .object(try c.decode([String: ModelJSON].self)) }
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
}
