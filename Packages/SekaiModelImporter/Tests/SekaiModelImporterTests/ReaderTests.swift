import XCTest
@testable import SekaiModelImporter
final class ReaderTests: XCTestCase {
    func testNullSkinSlotsDoNotShiftWeightedBindings() throws {
        let result = try DeviceModelImporter.skinBonePalette([10,nil,30], indices: [2,0,0,0], weights: [1,0,0,0], fallback: 10)
        XCTAssertEqual(result, [10,10,30])
        XCTAssertThrowsError(try DeviceModelImporter.skinBonePalette([10,nil,30], indices: [1,0,0,0], weights: [1,0,0,0], fallback: 10))
        XCTAssertThrowsError(try DeviceModelImporter.skinBonePalette([10,nil,30], indices: [3,0,0,0], weights: [1,0,0,0], fallback: 10))
        XCTAssertThrowsError(try DeviceModelImporter.skinBonePalette([10,nil,30], indices: [], weights: [], fallback: 10))
    }
    func testExistingHairVariantsRetainSkinPalettes() throws {
        guard let root = ProcessInfo.processInfo.environment["SEKAI_RAW_BUNDLE_FIXTURES"] else { throw XCTSkip("Opt-in local resource test") }
        let directory = URL(filePath: root)
        let common = try Data(contentsOf: directory.appendingPathComponent("live_pv/model/characterv2/face/common.bundle"))
        for name in ["0001", "0016", "0086", "2115n"] {
            let data = try Data(contentsOf: directory.appendingPathComponent("live_pv/model/characterv2/face/01/" + name + ".bundle"))
            do {
                let result = try DeviceModelImporter.convert(bundles: [data, common])
                XCTAssertFalse(result.scene.meshes.isEmpty)
                for mesh in result.scene.meshes {
                    let indices = mesh.skinIndices ?? [], weights = mesh.skinWeights ?? []
                    let bones = mesh.boneIDs ?? []
                    XCTAssertEqual(indices.count, weights.count)
                    for (index, weight) in zip(indices, weights) where weight > 0 {
                        XCTAssertTrue(bones.indices.contains(Int(index)))
                    }
                }
                if name == "2115n" {
                    let mesh = try XCTUnwrap(result.scene.meshes.first { $0.boneIDs?.count == 24 })
                    let unused: Set<Int> = [2,3,6,7,14,15,22,23]
                    for (index, weight) in zip(mesh.skinIndices ?? [], mesh.skinWeights ?? []) where weight > 0 {
                        XCTAssertFalse(unused.contains(Int(index)))
                    }
                    if let output = ProcessInfo.processInfo.environment["SEKAI_HAIR_REGRESSION_OUTPUT"] {
                        let folder = URL(filePath: output)
                        try FileManager.default.createDirectory(at: folder.appendingPathComponent("textures"), withIntermediateDirectories: true)
                        try JSONEncoder().encode(result.scene).write(to: folder.appendingPathComponent("scene.json"))
                        for (name, data) in result.texturePNGs { try data.write(to: folder.appendingPathComponent(name)) }
                    }
                }
                print("HAIR SKIN PALETTE", name, result.vertexCount)
                if let output = ProcessInfo.processInfo.environment["SEKAI_HAIR_VARIANT_FIXTURES"] {
                    let folder = URL(filePath: output).appendingPathComponent(name)
                    try FileManager.default.createDirectory(at: folder.appendingPathComponent("textures"), withIntermediateDirectories: true)
                    try JSONEncoder().encode(result.scene).write(to: folder.appendingPathComponent("scene.json"))
                    for (path, data) in result.texturePNGs { try data.write(to: folder.appendingPathComponent(path)) }
                }
            } catch { XCTFail("Hairstyle \(name): \(error)"); throw error }
        }
    }
    func testColorVariationChangesTexturesAndPreservesGeometry() throws {
        guard let root = ProcessInfo.processInfo.environment["SEKAI_RAW_BUNDLE_FIXTURES"] else { throw XCTSkip("Opt-in local resource test") }
        let directory = URL(filePath: root)
        let body = try Data(contentsOf: directory.appendingPathComponent("live_pv/model/characterv2/body/99/2209/ladies_m.bundle"))
        let colors = try Data(contentsOf: directory.appendingPathComponent("live_pv/model/characterv2/color_variation/body/99/2209/ladies_m/01.bundle"))
        let base = try DeviceModelImporter.convert(bundles: [body])
        let variant = try DeviceModelImporter.convert(bundles: [body, colors], variationBundleIndices: [1])
        XCTAssertEqual(base.vertexCount, variant.vertexCount)
        XCTAssertEqual(base.scene.meshes.first?.positions, variant.scene.meshes.first?.positions)
        XCTAssertNotEqual(base.scene.materials.first?.textures, variant.scene.materials.first?.textures)
    }
    func testTruncatedAndOversizedArchivesFail() {
        for data in [Data(), Data("UnityFS\0".utf8), Data([0x10, 0, 0, 0]), Data(repeating: 0, count: 200)] {
            XCTAssertThrowsError(try UnityFSArchive(data: data))
        }
    }
    func testRealLocalConversion() throws {
        guard let root = ProcessInfo.processInfo.environment["SEKAI_RAW_BUNDLE_FIXTURES"] else { throw XCTSkip("Opt-in local resource test") }
        for path in ["live_pv/model/characterv2/body/99/0005/ladies_m.bundle", "live_pv/model/characterv2/face/01/0016.bundle", "live_pv/model/characterv2/head_optional/2209/a01.bundle"] {
            let data = try Data(contentsOf: URL(filePath: root).appending(path: path))
            let common = try Data(contentsOf: URL(filePath: root).appending(path: "live_pv/model/characterv2/face/common.bundle"))
            let result = try DeviceModelImporter.convert(bundles: path.contains("/face/") ? [data,common] : path.contains("/body/") ? [data, try Data(contentsOf: URL(filePath: root).appending(path: "character/motion/costume_setting/01_00.bundle"))] : [data])
            XCTAssertGreaterThan(result.scene.meshes.count, 0)
            XCTAssertEqual(result.vertexCount, path.contains("/body/") ? 6822 : path.contains("/face/") ? 3745 : 300)
            XCTAssertGreaterThan(result.texturePNGs.count, 0)
            print("NATIVE CONVERSION", path, result.vertexCount, "vertices", result.texturePNGs.count, "textures", result.elapsedSeconds, "seconds")
            if let output = ProcessInfo.processInfo.environment["SEKAI_RAW_SCENE_OUTPUT"] {
                let folder = URL(filePath: output).appending(path: path.contains("/body/") ? "body" : path.contains("/face/") ? "hair" : "accessory")
                try FileManager.default.createDirectory(at: folder.appending(path: "textures"), withIntermediateDirectories: true)
                try JSONEncoder().encode(result.scene).write(to: folder.appending(path: "scene.json"))
                for (name, image) in result.texturePNGs { try image.write(to: folder.appending(path: name)) }
            }
        }
    }
    func testRealLocalBundles() throws {
        guard let root = ProcessInfo.processInfo.environment["SEKAI_RAW_BUNDLE_FIXTURES"] else { throw XCTSkip("Opt-in local resource test") }
        let urls = FileManager.default.enumerator(at: URL(filePath: root), includingPropertiesForKeys: nil)!.allObjects.compactMap { $0 as? URL }.filter { $0.pathExtension == "bundle" }
        var objects = 0
        for url in urls {
            let archive = try UnityFSArchive(data: Data(contentsOf: url))
            for entry in archive.entries where !entry.name.hasSuffix(".resS") && !entry.name.hasSuffix(".resource") {
                let file = try UnitySerializedFile(name: entry.name, data: entry.data)
                for object in file.objects where [1, 4, 21, 28, 43, 137, 23, 33, 142].contains(file.types[object.typeIndex].classID) {
                    do { _ = try file.read(object); objects += 1 }
                    catch {
                        XCTFail("\(url.lastPathComponent) class \(file.types[object.typeIndex].classID): \(error)")
                        throw error
                    }
                }
            }
        }
        XCTAssertGreaterThan(objects, 100)
        print("NATIVE UNITY OBJECTS", objects, "BUNDLES", urls.count)
    }
}
