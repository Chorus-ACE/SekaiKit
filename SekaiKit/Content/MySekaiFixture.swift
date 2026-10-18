import Foundation
import SekaiKitMacro
internal import SwiftyJSON

/// A placeable object or surface decoration in MY SEKAI.
@LocalizationsCombinable
public struct MySekaiFixture: Hashable, Identifiable, Sendable, SekaiCachable, LocalizationsCombinable {
    public var id: Int
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

    public struct Size: Hashable, Codable, Sendable, SekaiCachable {
        public var width: Int
        public var depth: Int
        public var height: Int
    }
    public struct MaterialCost: Hashable, Codable, Sendable, SekaiCachable, Identifiable {
        public var id: Int
        public var name: String
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
        let base = "https://sekai-world.github.io/\(locale._databasePath)/"
        async let fixtures = requestJSON(base + "mysekaiFixtures.json")
        async let genres = requestJSON(base + "mysekaiFixtureMainGenres.json")
        async let subgenres = requestJSON(base + "mysekaiFixtureSubGenres.json")
        async let blueprints = requestJSON(base + "mysekaiBlueprints.json")
        async let costs = requestJSON(base + "mysekaiBlueprintMysekaiMaterialCosts.json")
        async let materials = requestJSON(base + "mysekaiMaterials.json")
        guard let items = await fixtures?.array else { return nil }
        let dependencies = await (genres, subgenres, blueprints, costs, materials)
        return await Task.detached(priority: .userInitiated) {
            let genres = Dictionary((dependencies.0?.arrayValue ?? []).map { ($0["id"].intValue, $0["name"].stringValue) }, uniquingKeysWith: { a, _ in a })
            let subgenres = Dictionary((dependencies.1?.arrayValue ?? []).map { ($0["id"].intValue, $0["name"].stringValue) }, uniquingKeysWith: { a, _ in a })
            let blueprints = Dictionary((dependencies.2?.arrayValue ?? []).filter { $0["mysekaiCraftType"].string == "mysekai_fixture" }.map { ($0["craftTargetId"].intValue, $0["id"].intValue) }, uniquingKeysWith: { a, _ in a })
            let costs = Dictionary(grouping: dependencies.3?.arrayValue ?? [], by: { $0["mysekaiBlueprintId"].intValue })
            let materials = Dictionary((dependencies.4?.arrayValue ?? []).map { ($0["id"].intValue, $0) }, uniquingKeysWith: { a, _ in a })
            return items.compactMap { json in
                guard var fixture = MySekaiFixture(json: json) else { return nil }
                fixture.mainGenre = genres[json["mysekaiFixtureMainGenreId"].intValue].localizable()
                fixture.subGenre = subgenres[json["mysekaiFixtureSubGenreId"].intValue].localizable()
                if dependencies.2 != nil && dependencies.3 != nil && dependencies.4 != nil {
                    fixture.materials = .unlocalized((costs[blueprints[fixture.id] ?? -1] ?? []).compactMap { cost in
                        let id = cost["mysekaiMaterialId"].intValue
                        guard let material = materials[id], let quantity = cost["quantity"].int else { return nil }
                        return MaterialCost(id: id, name: material["name"].stringValue, quantity: quantity, assetBundleName: material["iconAssetbundleName"].string)
                    })
                }
                return fixture
            }
        }.value
    }
    internal init?(json: JSON) {
        guard let id = json["id"].int, let title = json["name"].string else { return nil }
        self.id = id
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
    }
}
