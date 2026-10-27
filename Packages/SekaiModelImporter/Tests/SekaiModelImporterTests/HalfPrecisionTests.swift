import XCTest
import CTextureDecoder

final class HalfPrecisionTests: XCTestCase {
    func testIEEEBinary16BoundaryValues() {
        let samples: [(UInt16, UInt32)] = [
            (0x0000, 0x00000000), (0x8000, 0x80000000),
            (0x3c00, 0x3f800000), (0xc000, 0xc0000000),
            (0x0001, 0x33800000), (0x03ff, 0x387fc000),
            (0x0400, 0x38800000), (0x7bff, 0x477fe000),
            (0x7c00, 0x7f800000), (0xfc00, 0xff800000)
        ]
        for (source, expected) in samples {
            XCTAssertEqual(sekai_decode_float16(source).bitPattern, expected)
        }
        for source: UInt16 in [0x7c01, 0x7e00, 0xffff] {
            XCTAssertTrue(sekai_decode_float16(source).isNaN)
        }
    }

    #if arch(arm64)
    func testEveryBinary16ValueMatchesSwiftOnSupportedArchitecture() {
        for bits in UInt16.min...UInt16.max {
            let expected = Float(Swift.Float16(bitPattern: bits))
            let actual = sekai_decode_float16(bits)
            if expected.isNaN { XCTAssertTrue(actual.isNaN) }
            else { XCTAssertEqual(actual.bitPattern, expected.bitPattern) }
        }
    }
    #endif
}
