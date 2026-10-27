import XCTest
import CTextureDecoder

final class TextureTests: XCTestCase {
    private func decode(_ bytes: [UInt8], width: Int32, height: Int32, format: Int32) throws -> [UInt8] {
        var output = [UInt8](repeating: 0, count: Int(width * height * 4))
        let count = output.count
        let result = bytes.withUnsafeBufferPointer { input in
            output.withUnsafeMutableBufferPointer { destination in
                sekai_decode_texture(input.baseAddress, bytes.count, width, height, format, destination.baseAddress, count)
            }
        }
        XCTAssertEqual(result, 1)
        return output
    }
    func testPNGRowsMatchHarukiWithoutVerticalFlip() throws {
        let rgba: [UInt8] = [255,0,0,255, 0,255,0,255, 0,0,255,255, 255,255,255,255]
        XCTAssertEqual(try decode(rgba, width: 2, height: 2, format: 4), rgba)
    }
    func testIOSChannelOrdersAndPackedPixels() throws {
        XCTAssertEqual(try decode([30,20,10,40], width: 1,height: 1,format: 14), [10,20,30,40])
        XCTAssertEqual(try decode([40,10,20,30], width: 1,height: 1,format: 5), [10,20,30,40])
        XCTAssertEqual(try decode([0x00,0xf8], width: 1,height: 1,format: 7), [255,0,0,255])
        XCTAssertEqual(try decode([0x34,0x12], width: 1,height: 1,format: 13), [17,34,51,68])
    }
}
