//
//  3DModels.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/10/25.
//

import Foundation

/// One clothing design, with its available colors.
public struct Costume: Identifiable, Sendable {
    public let id: String
    public let name: String?
    public let variants: [CostumeVariant]
}

/// One hairstyle, with its available variants.
public struct Hairstyle: Identifiable, Sendable {
    public let id: String
    public let name: String?
    public let variants: [CostumeVariant]
}

/// A head accessory or a complete head set. The renderer resolves its attachment.
public struct Accessory: Identifiable, Sendable {
    public let id: String
    public let name: String?
    public let variants: [CostumeVariant]
}

/// A selectable color in one region's wardrobe.
public struct CostumeVariant: Identifiable, Sendable {
    public let id: String
    public let costumeID: Int
    public let name: String?
    public let colorName: String?
    public let metadata: Model3DPartMetadata
    /// Complete head sets supply their own hairstyle.
    public let includesHairstyle: Bool
    internal let thumbnailPart: String

    /// Thumbnail endpoints for this variant's region; fallback only changes the host.
    public func thumbnailImageURLs(in locale: SekaiLocale) -> [URL] {
        guard id.hasPrefix(locale.rawValue + ":") else { return [] }
        let raw = metadata.thumbnailAssetBundleName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name: String
        if raw.contains("_") {
            name = raw
        } else {
            // Some regional masters supply only the numeric thumbnail stem.
            // Reconstruct missing names only when exporter identity metadata exists.
            guard metadata.groupID != nil else { return [] }
            let stem = raw.isEmpty ? String(format: "%04d", costumeID / 1000) : raw
            let suffix = metadata.colorID.flatMap { $0 >= 2 ? String(format: "_%02d", $0 - 1) : nil } ?? ""
            name = "cos\(stem)_\(thumbnailPart)\(suffix)"
        }
        guard !name.contains("/"), !name.contains("\\"), !name.contains("..") else { return [] }
        return ["https://sekai-assets-cn03-she01-cdn.haruki.seiunx.com", "https://sekai-assets-haruki.seiunx.net"].map {
            URL(string: $0)!.appendingPathComponent("\(locale.rawValue)-assets/startapp/thumbnail/costume/\(name).png")
        }
    }
}

/// Exporter metadata from the selected region. Missing and empty values remain distinct.
public struct Model3DPartMetadata: SekaiCache.Cacheable, Sendable {
    public let groupID: Int?
    public let colorID: Int?
    public let outfitID: Int?
    public let accessoryID: Int?
    public let thumbnailAssetBundleName: String?
    public let modelAssetBundleName: String?
    public let colorAssetBundleName: String?
    public let headAssetBundleType: String?
    public let part: String?
    public let attachNode: String?
    public let packagePath: String?
    public let sourcePackagePath: String?
    public let sourceKey: String?
    public let baseSourceKey: String?
    public let status: String?
    public let warnings: [String]?

    enum CodingKeys: String, CodingKey {
        case groupID = "costume3dGroupId", colorID = "colorId"
        case outfitID = "outfitId", accessoryID = "accessoryId"
        case thumbnailAssetBundleName = "costumeAssetbundleName"
        case modelAssetBundleName = "modelAssetbundleName"
        case colorAssetBundleName = "colorAssetbundleName"
        case headAssetBundleType = "headCostume3dAssetbundleType"
        case part, attachNode, packagePath, sourcePackagePath, sourceKey, baseSourceKey, status, warnings
    }
}

/// A character's wardrobe. Virtual Singer support units have separate identities.
public struct Model3DCharacter: Identifiable, Sendable {
    public let id: String
    public let characterID: Int
    public let unit: Unit?
    /// Retained even if a new upstream unit is not yet known to SekaiKit.
    public let unitID: String
    public let name: String?
    public let costumes: [Costume]
    public let hairstyles: [Hairstyle]
    public let accessories: [Accessory]
    public let locale: SekaiLocale
    public let height: Double?
    internal let defaultCostumeID: Int
    internal let defaultHairstyleID: Int
    internal let defaultHeadID: Int

    /// Starts with this region's default outfit. No other region is consulted.
    public func defaultSelection() -> Model3DSelection? {
        guard let costume = costumes.lazy.flatMap(\.variants).first(where: { $0.costumeID == defaultCostumeID }),
              let hairstyle = hairstyles.lazy.flatMap(\.variants).first(where: { $0.costumeID == defaultHairstyleID }) else { return nil }
        return .init(locale: locale, characterID: id, costumeID: costume.id, hairstyleID: hairstyle.id)
    }
}

/// The three choices a host app stores. Numeric IDs and renderer slots are resolved internally.
public struct Model3DSelection: Equatable, Sendable {
    public let locale: SekaiLocale
    public let characterID: Model3DCharacter.ID
    public var costumeID: CostumeVariant.ID
    public var hairstyleID: CostumeVariant.ID
    public var accessoryID: CostumeVariant.ID?

    public init(locale: SekaiLocale, characterID: Model3DCharacter.ID, costumeID: CostumeVariant.ID, hairstyleID: CostumeVariant.ID, accessoryID: CostumeVariant.ID? = nil) {
        self.locale = locale
        self.characterID = characterID
        self.costumeID = costumeID
        self.hairstyleID = hairstyleID
        self.accessoryID = accessoryID
    }
}

/// A coherent regional render plan, ready to pass to the embedded viewer.
public struct Model3DRenderConfiguration: Sendable {
    public let selection: Model3DSelection
    public let locale: SekaiLocale
    public let hairstyleIsLocked: Bool
    public let recipeJSON: String
    public var revision: String { catalog.revision }
    internal let catalog: Model3DCatalog
}

internal enum Model3DPartKind: String, Sendable {
    case body, hair, head, accessory = "head_optional"
    var category: String {
        switch self {
        case .body: "costume"
        case .hair: "hairstyle"
        case .head, .accessory: "accessory"
        }
    }
}
