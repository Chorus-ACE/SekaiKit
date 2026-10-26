import XCTest
@testable import SekaiModelImporter
final class ReaderTests: XCTestCase {
    func testTruncatedAndOversizedArchivesFail() {
        for data in [Data(), Data("UnityFS\0".utf8), Data([0x10, 0, 0, 0]), Data(repeating: 0, count: 200)] {
            XCTAssertThrowsError(try UnityFSArchive(data: data))
        }
    }
    func testRealLocalConversion() throws {
        guard let root = ProcessInfo.processInfo.environment["SEKAI_RAW_BUNDLE_FIXTURES"] else { throw XCTSkip("Opt-in local resource test") }
        for path in ["live_pv/model/characterv2/body/99/0005/ladies_m.bundle", "live_pv/model/characterv2/face/01/0016.bundle", "live_pv/model/characterv2/head_optional/2209/a01.bundle"] {
            let data = try Data(contentsOf: URL(filePath: root).appending(path: path))
            let result = try DeviceModelImporter.convert(bundles: [data])
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
