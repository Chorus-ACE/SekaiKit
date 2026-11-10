import XCTest
@testable import SekaiKit

final class NewsTests: XCTestCase {
    private func data(path: String, tag: String = "information", browse: String = "internal") -> Data {
        Data("""
        [{"id":1,"seq":0,"informationType":"normal","informationTag":"\(tag)","browseType":"\(browse)","platform":"all","title":"Announcement","path":"\(path)","startAt":0,"endAt":0}]
        """.utf8)
    }
    func testRegionalPathsAndUnknownCategories() throws {
        let jp = try XCTUnwrap(NewsItem.decode(data(path: "information/index.html?id=jp"), in: .jp).first)
        let en = try XCTUnwrap(NewsItem.decode(data(path: "information/index.html?id=en"), in: .en).first)
        XCTAssertEqual(jp.contentURL?.host, "production-web.sekai.colorfulpalette.org")
        XCTAssertEqual(en.contentURL?.host, "n-production-web.sekai-en.com")
        for locale in [SekaiLocale.tw, .kr, .cn] {
            let item = try XCTUnwrap(NewsItem.decode(data(path: "https://regional.example/news", tag: "future"), in: locale).first)
            XCTAssertEqual(item.contentURL?.host, "regional.example")
            XCTAssertEqual(item.tag, .unknown)
            XCTAssertEqual(item.tagName, "future")
            XCTAssertEqual(item.endDate, Date(timeIntervalSince1970: 0))
            XCTAssertNil(item.displayOrder)
            XCTAssertNil(try NewsItem.decode(data(path: "information/index.html"), in: locale).first?.contentURL)
        }
        XCTAssertNotEqual(jp.id, en.id)
    }
    func testBannerOnlyNewsPreservesMissingTitle() throws {
        let input = String(decoding: data(path: "https://www.tw-pjsekai.com", browse: "external"), as: UTF8.self)
            .replacingOccurrences(of: "\"title\":\"Announcement\",", with: "")
        let item = try XCTUnwrap(NewsItem.decode(Data(input.utf8), in: .tw).first)
        XCTAssertNil(item.title)
        XCTAssertEqual(item.displayTitle, "www.tw-pjsekai.com")
    }
    
    func testInvalidLinksAreNotOpened() throws {
        for path in ["javascript:alert(1)", "//other.example/path", "", "file:///tmp/a"] {
            XCTAssertNil(try NewsItem.decode(data(path: path), in: .jp).first?.contentURL)
        }
        XCTAssertNil(try NewsItem.decode(data(path: "https://example.com", browse: "future"), in: .jp).first?.contentURL)
    }
    func testDownloadedRegionalNewsWhenProvided() throws {
        guard let directory = ProcessInfo.processInfo.environment["SEKAI_NEWS_FIXTURES"] else { throw XCTSkip("Optional regional news snapshots") }
        for locale in [SekaiLocale.jp, .en, .tw, .kr] {
            let data = try Data(contentsOf: URL(filePath: directory).appending(path: "news-\(locale.rawValue).json"))
            let items = try NewsItem.decode(data, in: locale)
            XCTAssertFalse(items.isEmpty)
            XCTAssertTrue(items.allSatisfy { $0.contentURL != nil })
            XCTAssertTrue(zip(items, items.dropFirst()).allSatisfy { $0.startDate >= $1.startDate })
        }
    }
}
