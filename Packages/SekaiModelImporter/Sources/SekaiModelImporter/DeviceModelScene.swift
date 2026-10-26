import Foundation

/// Geometry imported on the device. Version 1 previews the authored rest pose;
/// animation, SEKAI shaders and spring-bone simulation are not yet applied.
public struct DeviceModelScene: Codable, Sendable {
    public var schemaVersion = 1
    public let meshes: [Mesh]
    public let materials: [Material]
    public let warnings: [String]
    public struct Mesh: Codable, Sendable {
        public let name: String
        public let positions: [Float]
        public let normals: [Float]
        public let uv: [Float]
        public let indices: [UInt32]
        public let groups: [Group]
        public let matrix: [Float]
    }
    public struct Group: Codable, Sendable { public let start: Int; public let count: Int; public let material: Int }
    public struct Material: Codable, Sendable {
        public let name: String
        public let texture: String?
        public let color: [Float]
        public let transparent: Bool
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
