import Foundation

internal extension LocalizableData {
    func value(in locale: SekaiLocale) -> T? {
        switch self {
        case .localized(let data): data[locale]
        case .unlocalized(let value): value
        }
    }
}

extension Comic: TitleDescribable, SekaiSearchable, SekaiFilterable, SekaiSortable {
    public var _searchLocalizedStrings: [LocalizableData<String>] { [title] }
    public static var filterKeys: [SekaiFilter.Key] { [SekaiLocale.filterKey] }
    public func _matches(_ filter: SekaiFilter) -> Bool { availableLocales.contains { filter.permits($0) } }
    public static var applicableSortingTypes: [SekaiSorter.Keyword] { [.id] }
    public static var hasEndingDate: Bool { false }
    public static func _compare<T>(usingSekaiSorter sorter: SekaiSorter, lhs: T, rhs: T) -> Bool? {
        guard let lhs = lhs as? Self, let rhs = rhs as? Self, sorter.keyword == .id else { return nil }
        return sorter.compare(lhs.id, rhs.id)
    }
}

extension MySekaiFixture: TitleDescribable, SekaiSearchable, SekaiFilterable, SekaiSortable {
    public var _searchLocalizedStrings: [LocalizableData<String>] { [title, description, mainGenre, subGenre] }
    public static var filterKeys: [SekaiFilter.Key] { [SekaiLocale.filterKey, FixtureType.filterKey, Site.filterKey, Layout.filterKey] }
    public func _matches(_ filter: SekaiFilter) -> Bool {
        availableLocales.contains {
            filter.permits($0) && filter.permits(type.value(in: $0)) && filter.permits(site.value(in: $0)) && filter.permits(layout.value(in: $0))
        }
    }
    public static var applicableSortingTypes: [SekaiSorter.Keyword] { [.id] }
    public static var hasEndingDate: Bool { false }
    public static func _compare<T>(usingSekaiSorter sorter: SekaiSorter, lhs: T, rhs: T) -> Bool? {
        guard let lhs = lhs as? Self, let rhs = rhs as? Self, sorter.keyword == .id else { return nil }
        return sorter.compare(lhs.id, rhs.id)
    }
}
