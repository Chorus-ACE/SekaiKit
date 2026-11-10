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

    public struct Size: Hashable, Codable, Sendable, SekaiCachable {
        public var width: Int
        public var depth: Int
        public var height: Int
        
        public var isEmpty: Bool {
            width == 0 && depth == 0 && height == 0
        }
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
            switch self.rawValue {
            case "canvas": NSLocalizedString("Fixture.type.canvas", bundle: #bundle, comment: "")
            case "custom": NSLocalizedString("Fixture.type.custom", bundle: #bundle, comment: "")
            case "gate": NSLocalizedString("Fixture.type.gate", bundle: #bundle, comment: "")
            case "house_plant": NSLocalizedString("Fixture.type.house_plant", bundle: #bundle, comment: "")
            case "normal": NSLocalizedString("Fixture.type.normal", bundle: #bundle, comment: "")
            case "plant": NSLocalizedString("Fixture.type.plant", bundle: #bundle, comment: "")
            case "surface_appearance": NSLocalizedString("Fixture.type.surface_appearance", bundle: #bundle, comment: "")
            case "system": NSLocalizedString("Fixture.type.system", bundle: #bundle, comment: "")
            default: String(describing: self.rawValue)
            }
        }
    }
    public enum Site: String, CaseIterable, Hashable, Codable, Sendable, SekaiCachable {
        case any = "any"
        case home = "home"
        case room = "room"
        public var localizedName: String {
            switch self.rawValue {
            case "any": NSLocalizedString("Fixture.site.any", bundle: #bundle, comment: "")
            case "home": NSLocalizedString("Fixture.site.home", bundle: #bundle, comment: "")
            case "room": NSLocalizedString("Fixture.site.room", bundle: #bundle, comment: "")
            default: String(describing: self.rawValue)
            }
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
            switch self.rawValue {
            case "floor": NSLocalizedString("Fixture.layout.floor", bundle: #bundle, comment: "")
            case "floor_appearance": NSLocalizedString("Fixture.layout.floor_appearance", bundle: #bundle, comment: "")
            case "road": NSLocalizedString("Fixture.layout.road", bundle: #bundle, comment: "")
            case "rug": NSLocalizedString("Fixture.layout.rug", bundle: #bundle, comment: "")
            case "wall": NSLocalizedString("Fixture.layout.wall", bundle: #bundle, comment: "")
            case "wall_appearance": NSLocalizedString("Fixture.layout.wall_appearance", bundle: #bundle, comment: "")
            default: String(describing: self.rawValue)
            }
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
