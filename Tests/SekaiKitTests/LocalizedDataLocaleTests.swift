import XCTest
@testable import SekaiKit

final class LocalizedDataLocaleTests: XCTestCase {
    @MainActor
    func testAllPreferencePairsAndAvailabilityCombinationsHaveUniqueOrderedLocales() {
        let primary = SekaiLocale.primaryLocale
        let secondary = SekaiLocale.secondaryLocale
        defer {
            SekaiLocale.primaryLocale = primary
            SekaiLocale.secondaryLocale = secondary
        }
        for first in SekaiLocale.allCases {
            for second in SekaiLocale.allCases {
                SekaiLocale.primaryLocale = first
                SekaiLocale.secondaryLocale = second
                for mask in 0..<32 {
                    let available = Set(SekaiLocale.allCases.enumerated().compactMap { index, locale in
                        mask & (1 << index) != 0 ? locale : nil
                    })
                    let data = LocalizedData(repeating: "value", forLocale: available)
                    let locales = data.allAvailableLocales
                    XCTAssertEqual(Set(locales), available)
                    XCTAssertEqual(locales.count, available.count)
                    let preferences = first == second ? [first] : [first, second]
                    let expected = preferences.filter(available.contains)
                        + SekaiLocale.allCases.filter { available.contains($0) && !preferences.contains($0) }
                    XCTAssertEqual(locales, expected)
                }
            }
        }
    }
}
