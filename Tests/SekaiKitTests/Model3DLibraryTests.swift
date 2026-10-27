import XCTest
@testable import SekaiKit

final class Model3DLibraryTests: XCTestCase {
    private func fixture(locale: SekaiLocale = .jp, legacy: Bool = false, unit: String = "light_sound", thumbnail: String? = nil, defaultHead: Int = 1) throws -> Model3DCatalog {
        func part(_ id: Int, _ kind: String, group: Int? = nil, color: Int = 1) -> [String: Any] {
            var value: [String: Any] = ["id": "1:\(unit):\(kind):\(id)", "costumeID": id, "type": kind,
                "name": locale == .jp ? "衣装" : "Outfit", "colorName": color == 1 ? "" : "Another"]
            if !legacy {
                value.merge(["costume3dGroupId": group ?? id, "colorId": color,
                             "modelAssetbundleName": "shared", "costumeAssetbundleName": thumbnail ?? (locale.rawValue + "-thumbnail"),
                             "headCostume3dAssetbundleType": kind == "head" ? "head_and_hair" : "head_only"]) { _, new in new }
            }
            return value
        }
        let source: [String: Any] = ["schemaVersion": 1, "region": locale.rawValue, "revision": locale.rawValue, "files": [:],
            "roles": [["id": "1:\(unit)", "characterId": 1, "unit": unit, "name": "Ichika",
                       "bodyCostume3dId": 2, "headCostume3dId": defaultHead, "hairCostume3dId": 201,
                       "characterHeightMeters": 1.61, "skinColors": ["default": "#fff5e8"],
                       "parts": [part(2, "body"), part(201, "hair"), part(1, "head_optional"),
                                 part(1002, "body", group: 1001), part(1004, "body", group: 1001, color: 2),
                                 part(8, "head_optional", group: 1001), part(9, "head"), part(999, "future_slot")]]]]
        return try JSONDecoder().decode(Model3DCatalog.self, from: JSONSerialization.data(withJSONObject: source))
    }

    func testDefaultCompleteHeadRemainsVisibleAndSelected() throws {
        let library = try Model3DLibrary(catalog: fixture(defaultHead: 9))
        let character = try XCTUnwrap(library.characters.first)
        let selection = try XCTUnwrap(character.defaultSelection())
        let head = try XCTUnwrap(character.accessories.flatMap(\.variants).first { $0.costumeID == 9 })
        XCTAssertEqual(selection.accessoryID, head.id)
        XCTAssertTrue(try library.resolve(selection).hairstyleIsLocked)
    }

    func testRegionalWardrobeGroupsColorsAndPreservesSourceValues() throws {
        let catalog = try fixture()
        let library = try Model3DLibrary(catalog: catalog)
        let character = try XCTUnwrap(library.characters.first)
        XCTAssertEqual(library.locale, .jp)
        XCTAssertEqual(character.unit, .leoNeed)
        XCTAssertEqual(character.height, 1.61)
        XCTAssertEqual(catalog.roles[0].skinColors?["default"], "#fff5e8")
        let clothing = try XCTUnwrap(character.costumes.first { $0.variants.count == 2 })
        XCTAssertEqual(clothing.name, "衣装")
        XCTAssertEqual(clothing.variants.map(\.costumeID), [1002, 1004])
        XCTAssertEqual(clothing.variants[0].colorName, "")
        XCTAssertEqual(clothing.variants[0].metadata.thumbnailAssetBundleName, "jp-thumbnail")
        XCTAssertEqual(character.accessories.flatMap(\.variants).count, 2)
        XCTAssertFalse(character.costumes.flatMap(\.variants).contains { $0.costumeID == 999 })
    }

    func testSelectionsAndVariantIdentitiesCannotCrossRegions() throws {
        let jp = try Model3DLibrary(catalog: fixture(locale: .jp))
        let en = try Model3DLibrary(catalog: fixture(locale: .en))
        var selection = try XCTUnwrap(jp.characters.first?.defaultSelection())
        XCTAssertThrowsError(try en.resolve(selection)) {
            guard case Model3DLibrary.Failure.wrongLocale = $0 else { return XCTFail("Unexpected error: \($0)") }
        }
        selection.costumeID = try XCTUnwrap(en.characters.first?.costumes.first?.variants.first?.id)
        XCTAssertThrowsError(try jp.resolve(selection))
    }

    func testThreeChoicesResolveIntoEngineSlotsAndFullHeadsLockHair() throws {
        let library = try Model3DLibrary(catalog: fixture())
        let character = try XCTUnwrap(library.characters.first)
        var selection = try XCTUnwrap(character.defaultSelection())
        for rawID in [8, 9] {
            selection.accessoryID = try XCTUnwrap(character.accessories.flatMap(\.variants).first { $0.costumeID == rawID }).id
            let plan = try library.resolve(selection)
            let recipe = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(plan.recipeJSON.utf8)) as? [String: Any])
            XCTAssertEqual(recipe["headCostume3dId"] as? Int, rawID)
            XCTAssertTrue(recipe["headOptionalCostume3dId"] is NSNull)
            XCTAssertEqual(plan.hairstyleIsLocked, rawID == 9)
            XCTAssertEqual(plan.locale, .jp)
        }
        selection.accessoryID = nil
        let plan = try library.resolve(selection)
        XCTAssertFalse(plan.hairstyleIsLocked)
        XCTAssertTrue(plan.recipeJSON.contains("\"headCostume3dId\":1"))
    }

    func testLegacyIndexAndUnknownUnitsRemainUsable() throws {
        let library = try Model3DLibrary(catalog: fixture(legacy: true, unit: "future_unit"))
        let character = try XCTUnwrap(library.characters.first)
        XCTAssertNil(character.unit)
        XCTAssertEqual(character.unitID, "future_unit")
        XCTAssertTrue(character.costumes.allSatisfy { $0.variants.count == 1 })
        let selection = try XCTUnwrap(character.defaultSelection())
        XCTAssertEqual(try library.resolve(selection).locale, .jp)
    }

    func testThumbnailURLsKeepTheSelectedRegionAndRespectExplicitAssetNames() throws {
        let library = try Model3DLibrary(catalog: fixture(thumbnail: "cos0001_body_01"))
        let variant = try XCTUnwrap(library.characters.first?.costumes.first?.variants.first)
        let urls = variant.thumbnailImageURLs(in: .jp)
        XCTAssertEqual(urls.count, 2)
        XCTAssertTrue(urls.allSatisfy { $0.path == "/jp-assets/startapp/thumbnail/costume/cos0001_body_01.png" })
        XCTAssertTrue(variant.thumbnailImageURLs(in: .en).isEmpty)
    }

    func testNumericThumbnailStemsUseTheMetadataInsteadOfTheCostumeID() throws {
        let library = try Model3DLibrary(catalog: fixture(thumbnail: "01001"))
        let group = try XCTUnwrap(library.characters.first?.costumes.first { $0.variants.count == 2 })
        XCTAssertEqual(group.variants[1].thumbnailImageURLs(in: .jp).first?.lastPathComponent, "cos01001_body_01.png")
        let accessory = try XCTUnwrap(library.characters.first?.accessories.first?.variants.first)
        XCTAssertEqual(accessory.thumbnailImageURLs(in: .jp).first?.lastPathComponent, "cos01001_head.png")
    }

    func testMissingAndUnsafeThumbnailNamesDoNotProduceSpeculativeURLs() throws {
        let legacy = try Model3DLibrary(catalog: fixture(legacy: true))
        XCTAssertTrue(try XCTUnwrap(legacy.characters.first?.costumes.first?.variants.first).thumbnailImageURLs(in: .jp).isEmpty)
        for name in ["../hidden", "nested/cos0001_body", "nested\\cos0001_body"] {
            let library = try Model3DLibrary(catalog: fixture(thumbnail: name))
            XCTAssertTrue(try XCTUnwrap(library.characters.first?.costumes.first?.variants.first).thumbnailImageURLs(in: .jp).isEmpty)
        }
    }

    func testPublishedRegionalIndexesProduceCompleteDefaultRenderPlans() throws {
        guard let directory = ProcessInfo.processInfo.environment["SEKAI_3D_LOCAL_REGIONS"] else {
            throw XCTSkip("Set SEKAI_3D_LOCAL_REGIONS to validate regional catalogs without model downloads")
        }
        for locale in SekaiLocale.allCases {
            let url = URL(fileURLWithPath: directory).appendingPathComponent(locale.rawValue + ".json")
            let catalog = try JSONDecoder().decode(Model3DCatalog.self, from: Data(contentsOf: url))
            let library = try Model3DLibrary(catalog: catalog)
            XCTAssertEqual(library.locale, locale)
            XCTAssertFalse(library.characters.isEmpty)
            for character in library.characters {
                let selection = try XCTUnwrap(character.defaultSelection())
                let plan = try library.resolve(selection)
                let original = try XCTUnwrap(catalog.roles.first { $0.id == character.id })
                let recipe = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(plan.recipeJSON.utf8)) as? [String: Any])
                XCTAssertEqual(recipe["bodyCostume3dId"] as? Int, original.bodyCostumeID)
                XCTAssertEqual(recipe["headCostume3dId"] as? Int, original.headCostumeID)
                XCTAssertEqual(recipe["hairCostume3dId"] as? Int, original.hairCostumeID)
            }
        }
    }
}
