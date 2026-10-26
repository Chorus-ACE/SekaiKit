import Foundation
import XCTest
import SekaiKit

final class Model3DDeviceClientTests: XCTestCase {
    func testPublicDeviceAPIKeepsImporterImplementationPrivate() throws {
        let manifest = try Model3DDeviceSourceManifest.japaneseSamples()
        XCTAssertEqual(manifest.locale, .jp)
        XCTAssertEqual(Set(manifest.parts.map(\.id)), ["body-7002", "hair-29001", "accessory-2075025"])
        let decoded = try JSONDecoder().decode(Model3DDeviceSourceManifest.self, from: JSONEncoder().encode(manifest))
        XCTAssertEqual(decoded.sourceRevision, manifest.sourceRevision)
        XCTAssertTrue(Model3DDeviceClient.thirdPartyNotices.contains("Perfare"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(manifest)) as? [String: Any])
        json["region"] = "en"
        XCTAssertThrowsError(try JSONDecoder().decode(Model3DDeviceSourceManifest.self, from: JSONSerialization.data(withJSONObject: json)))
    }
}
