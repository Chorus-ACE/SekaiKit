import Foundation

/// A typed wardrobe for one region. Load it with `Model3DClient.library(for:)`.
public struct Model3DLibrary: Sendable {
    public let locale: SekaiLocale
    public let revision: String
    public let characters: [Model3DCharacter]
    private let catalog: Model3DCatalog

    public enum Failure: LocalizedError {
        case unknownCharacter, unknownVariant, wrongLocale, missingDefaults

        public var errorDescription: String? {
            let key: String
            switch self {
            case .unknownCharacter: key = "Model3D.error.unknown-character"
            case .unknownVariant: key = "Model3D.error.unknown-variant"
            case .wrongLocale: key = "Model3D.error.wrong-locale"
            case .missingDefaults: key = "Model3D.error.missing-defaults"
            }
            return NSLocalizedString(key, bundle: #bundle, comment: "")
        }
    }

    /// Builds one region's wardrobe, including older indexes without grouping metadata.
    public init(catalog: Model3DCatalog) throws {
        guard catalog.schemaVersion == 1 else { throw Model3DClient.Failure.invalidManifest }
        self.catalog = catalog
        locale = catalog.region
        revision = catalog.revision
        characters = catalog.roles.map { Self.character($0, locale: catalog.region) }
    }

    /// Resolves the three choices within this index. Selections from another region fail.
    public func resolve(_ selection: Model3DSelection) throws -> Model3DRenderConfiguration {
        guard selection.locale == locale else { throw Failure.wrongLocale }
        guard let character = characters.first(where: { $0.id == selection.characterID }) else { throw Failure.unknownCharacter }
        guard let costume = character.costumes.lazy.flatMap(\.variants).first(where: { $0.id == selection.costumeID }),
              let hairstyle = character.hairstyles.lazy.flatMap(\.variants).first(where: { $0.id == selection.hairstyleID }) else { throw Failure.unknownVariant }
        let accessory = character.accessories.lazy.flatMap(\.variants).first { $0.id == selection.accessoryID }
        guard selection.accessoryID == nil || accessory != nil else { throw Failure.unknownVariant }
        let recipe: [String: Any] = [
            "roleId": character.id,
            "bodyCostume3dId": costume.costumeID,
            "hairCostume3dId": hairstyle.costumeID,
            "headCostume3dId": accessory?.costumeID ?? character.defaultHeadID,
            "headOptionalCostume3dId": NSNull()
        ]
        let encoded = try JSONSerialization.data(withJSONObject: recipe, options: [.sortedKeys])
        return .init(selection: selection, locale: locale, hairstyleIsLocked: accessory?.includesHairstyle ?? false,
                     recipeJSON: String(decoding: encoded, as: UTF8.self), catalog: catalog)
    }

    private struct Group {
        var name: String?
        var variants: [CostumeVariant]
        var order: Int
    }

    private static func character(_ role: Model3DCatalog.Role, locale: SekaiLocale) -> Model3DCharacter {
        var groups: [String: [String: Group]] = [:]
        for (order, part) in role.parts.enumerated() {
            // Preserve unknown slots in the transport manifest; they cannot be selected
            // until the renderer's new assembly semantics are supported.
            guard let kind = Model3DPartKind(rawValue: part.type) else { continue }
            if kind.category == "accessory", part.costumeID == role.headCostumeID { continue }
            let prefix = "\(locale.rawValue):\(role.id):\(kind.category)"
            let identity = part.metadata.groupID.map { "group:\($0)" } ?? "part:\(part.id)"
            let groupID = prefix + ":" + identity
            var group = groups[kind.category]?[groupID] ?? .init(name: part.name, variants: [], order: order)
            let variant = CostumeVariant(id: "\(locale.rawValue):\(part.id)", costumeID: part.costumeID, name: part.name,
                                         colorName: part.colorName, metadata: part.metadata, includesHairstyle: kind == .head,
                                         thumbnailPart: kind.category == "accessory" ? "head" : kind.rawValue)
            group.variants.append(variant)
            groups[kind.category, default: [:]][groupID] = group
        }
        func items(_ category: String) -> [(String, Group)] {
            (groups[category] ?? [:]).sorted { $0.value.order < $1.value.order }.map { id, group in
                var group = group
                group.variants.sort { $0.costumeID == $1.costumeID ? $0.id < $1.id : $0.costumeID < $1.costumeID }
                return (id, group)
            }
        }
        return .init(id: role.id, characterID: role.characterID, unit: Unit(rawValue: role.unit), unitID: role.unit, name: role.name,
                     costumes: items("costume").map { Costume(id: $0.0, name: $0.1.name, variants: $0.1.variants) },
                     hairstyles: items("hairstyle").map { Hairstyle(id: $0.0, name: $0.1.name, variants: $0.1.variants) },
                     accessories: items("accessory").map { Accessory(id: $0.0, name: $0.1.name, variants: $0.1.variants) },
                     locale: locale, height: role.height, defaultCostumeID: role.bodyCostumeID,
                     defaultHairstyleID: role.hairCostumeID, defaultHeadID: role.headCostumeID)
    }
}
