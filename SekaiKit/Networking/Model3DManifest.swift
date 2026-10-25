import Foundation

/// A region's published, render-ready wardrobe. Objects are shared across regions by SHA-256.
public struct Model3DCatalog: Decodable, Sendable {
    public let schemaVersion: Int
    public let region: SekaiLocale
    public let revision: String
    public let roles: [Role]
    public let files: [String: Resource]

    public struct Role: Decodable, Identifiable, Sendable {
        public let id: String
        public let name: String?
        public let characterID: Int
        public let unit: String
        public let bodyCostumeID: Int
        public let headCostumeID: Int
        public let hairCostumeID: Int
        public let height: Double?
        public let skinColors: [String: String]?
        public let runtimePath: String?
        public let parts: [Part]
        
        enum CodingKeys: String, CodingKey {
            case id, name, unit, parts
            case characterID = "characterId"
            case bodyCostumeID = "bodyCostume3dId", headCostumeID = "headCostume3dId", hairCostumeID = "hairCostume3dId"
            case height = "characterHeightMeters", skinColors, runtimePath = "roleRuntimePath"
        }
    }
    public struct Part: Decodable, Identifiable, Sendable {
        public let id: String
        public let costumeID: Int
        public let type: String
        public let name: String?
        public let colorName: String?
        public let metadata: Model3DPartMetadata

        enum CodingKeys: String, CodingKey { case id, costumeID, type, name, colorName }
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            costumeID = try container.decode(Int.self, forKey: .costumeID)
            type = try container.decode(String.self, forKey: .type)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            colorName = try container.decodeIfPresent(String.self, forKey: .colorName)
            metadata = try Model3DPartMetadata(from: decoder)
        }
    }
    public struct Resource: Decodable, Sendable {
        public let sha256: String
        public let bytes: Int
        public let archiveBytes: Int
        public let url: URL
    }
}

