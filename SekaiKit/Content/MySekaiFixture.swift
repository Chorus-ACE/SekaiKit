import Foundation
import SekaiKitMacro
internal import SwiftyJSON

/// A placeable object or surface decoration in MY SEKAI.
@LocalizationsCombinable
public struct MySekaiFixture: Hashable, Identifiable, Sendable, SekaiCachable, LocalizationsCombinable {
    public var id: Int
    /// Regional display sequence from the master data.
    public var displayOrder: LocalizableData<Int>
    public var title: LocalizableData<String>
    public var description: LocalizableData<String>
    public var type: LocalizableData<FixtureType>
    public var site: LocalizableData<Site>
    public var layout: LocalizableData<Layout>
    public var assetBundleName: LocalizableData<String>
    public var mainGenre: LocalizableData<String>
    public var subGenre: LocalizableData<String>
    public var size: LocalizableData<Size>
    public var canDisassemble: LocalizableData<Bool>
    public var hasCharacterAction: LocalizableData<Bool>
    public var materials: LocalizableData<[MaterialCost]>
    /// All regional recipes, including an explicitly empty material list for a free recipe.
    public var blueprints: LocalizableData<[Blueprint]>

    public struct Blueprint: Hashable, Codable, Sendable, SekaiCachable, Identifiable {
        public var id: Int
        public var canSketch: Bool
        public var obtainedByConversion: Bool
        public var craftCountLimit: Int?
        public var availableWithoutPossession: Bool
        public var materials: [MaterialCost]
    }

    /// Decodes fields absent from older caches as unknown.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        displayOrder = try container.decodeIfPresent(LocalizableData<Int>.self, forKey: .displayOrder) ?? .unlocalized(nil)
        title = try container.decode(LocalizableData<String>.self, forKey: .title)
        description = try container.decode(LocalizableData<String>.self, forKey: .description)
        type = try container.decode(LocalizableData<FixtureType>.self, forKey: .type)
        site = try container.decode(LocalizableData<Site>.self, forKey: .site)
        layout = try container.decode(LocalizableData<Layout>.self, forKey: .layout)
        assetBundleName = try container.decode(LocalizableData<String>.self, forKey: .assetBundleName)
        mainGenre = try container.decode(LocalizableData<String>.self, forKey: .mainGenre)
        subGenre = try container.decode(LocalizableData<String>.self, forKey: .subGenre)
        size = try container.decode(LocalizableData<Size>.self, forKey: .size)
        canDisassemble = try container.decode(LocalizableData<Bool>.self, forKey: .canDisassemble)
        hasCharacterAction = try container.decode(LocalizableData<Bool>.self, forKey: .hasCharacterAction)
        blueprints = try container.decodeIfPresent(LocalizableData<[Blueprint]>.self, forKey: .blueprints) ?? .unlocalized(nil)
        materials = try container.decode(LocalizableData<[MaterialCost]>.self, forKey: .materials)
    }

    public struct Size: Hashable, Codable, Sendable, SekaiCachable {
        public var width: Int
        public var depth: Int
        public var height: Int
    }
    public struct MaterialCost: Hashable, Codable, Sendable, SekaiCachable, Identifiable {
        public var id: Int
        /// Absent when a regional recipe references a missing material record.
        public var name: String?
        public var quantity: Int
        public var assetBundleName: String?
        public func imageURL(in locale: SekaiLocale) -> URL? {
            guard let assetBundleName else { return nil }
            return URL(string: "https://storage.sekai.best/\(locale._assetsPath)/mysekai/thumbnail/material/\(assetBundleName).webp")
        }
    }
    public enum FixtureType: String, CaseIterable, Hashable, Codable, Sendable, SekaiCachable {
        case normal = "normal"
        case system = "system"
        case canvas = "canvas"
        case custom = "custom"
        case gate = "gate"
        case housePlant = "house_plant"
        case plant = "plant"
        case surfaceAppearance = "surface_appearance"
        public var localizedName: String {
            NSLocalizedString("Fixture.type.\(rawValue)", bundle: #bundle, comment: "")
        }
    }
    public enum Site: String, CaseIterable, Hashable, Codable, Sendable, SekaiCachable {
        case any = "any"
        case home = "home"
        case room = "room"
        public var localizedName: String {
            NSLocalizedString("Fixture.site.\(rawValue)", bundle: #bundle, comment: "")
        }
    }
    public enum Layout: String, CaseIterable, Hashable, Codable, Sendable, SekaiCachable {
        case floor = "floor"
        case floorAppearance = "floor_appearance"
        case road = "road"
        case rug = "rug"
        case wall = "wall"
        case wallAppearance = "wall_appearance"
        public var localizedName: String {
            NSLocalizedString("Fixture.layout.\(rawValue)", bundle: #bundle, comment: "")
        }
    }
    public var availableLocales: [SekaiLocale] {
        SekaiLocale.allCases.filter { title.localizedData?.availableInLocale($0) ?? ($0 == .primaryLocale) }
    }
    public func imageURL(in locale: SekaiLocale? = nil) -> URL? {
        let locale = locale ?? assetBundleName.majorLocale ?? .primaryLocale
        guard let bundle = assetBundleName.value(in: locale) else { return nil }
        let path: String
        if type.value(in: locale) == .surfaceAppearance, let layout = layout.value(in: locale) {
            path = "surface_appearance/\(bundle)/tex_\(bundle)_\(layout.rawValue)_1.png"
        } else {
            path = "fixture/\(bundle)_1.webp"
        }
        return URL(string: "https://storage.sekai.best/\(locale._assetsPath)/mysekai/thumbnail/\(path)")
    }
}

extension MySekaiFixture: ListGettable, GettableByID {
    public static func allInLocale(_ locale: SekaiLocale) async -> [MySekaiFixture]? {
        guard let list = await requestProtobuf("fixture.aar", as: _FixtureList.self) else { return nil }
        return list.items(in: locale).map { MySekaiFixture(protobuf: $0) }
    }
    internal init?(json: JSON) {
        guard let id = json["id"].int, let title = json["name"].string else { return nil }
        self.id = id
        displayOrder = json["seq"].int.localizable()
        self.title = .unlocalized(title)
        description = json["flavorText"].string.localizable()
        type = .unlocalized(FixtureType(rawValue: json["mysekaiFixtureType"].stringValue))
        site = .unlocalized(Site(rawValue: json["mysekaiSettableSiteType"].stringValue))
        layout = .unlocalized(Layout(rawValue: json["mysekaiSettableLayoutType"].stringValue))
        assetBundleName = json["assetbundleName"].string.localizable()
        let grid = json["gridSize"]
        if let w = grid["width"].int, let d = grid["depth"].int, let h = grid["height"].int {
            size = .unlocalized(Size(width: w, depth: d, height: h))
        } else { size = .unlocalized(nil) }
        canDisassemble = json["isDisassembled"].bool.localizable()
        hasCharacterAction = json["isGameCharacterAction"].bool.localizable()
        mainGenre = .unlocalized(nil)
        subGenre = .unlocalized(nil)
        materials = .unlocalized(nil)
        blueprints = .unlocalized(nil)
    }
}
