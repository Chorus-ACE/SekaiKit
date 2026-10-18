import Foundation

private func categoryFilter(id: String, values: [String]) -> SekaiFilter.Key {
    SekaiFilter.Key(id: id, options: values.enumerated().map { index, value in
        .init(id: index, selectorName: NSLocalizedString("Filter.option.\(id).\(value)", bundle: #bundle, comment: ""))
    }).withOtherOption
}

extension Gacha: TitleDescribable, SekaiSearchable, SekaiFilterable, SekaiSortable {
    private static let costs = ["free", "jewel", "paid_jewel", "gacha_ticket"]
    /// Whether a regional edition is upcoming, open, or closed.
    public static var statusFilterKey: SekaiFilter.Key { categoryFilter(id: "gachaStatus", values: ["upcoming", "open", "closed"]) }
    /// The resources accepted by at least one payment option.
    public static var costFilterKey: SekaiFilter.Key { categoryFilter(id: "gachaCost", values: costs) }
    public var _searchLocalizedStrings: [LocalizableData<String>] { [title, summary] }
    public static var filterKeys: [SekaiFilter.Key] { [SekaiLocale.filterKey, GachaType.filterKey, statusFilterKey, costFilterKey] }

    public func _matches(_ filter: SekaiFilter) -> Bool { matches(filter, at: Date()) }

    /// Evaluates all filters against the same regional edition at a supplied time.
    public func matches(_ filter: SekaiFilter, at date: Date) -> Bool {
        availableLocales.contains(where: { (locale: SekaiLocale) in
            guard filter.permits(locale), let configuration = configuration.value(in: locale),
                  filter.permits(type) else { return false }
            let start = startDate.value(in: locale)
            let end = endDate.value(in: locale)
            let status: Int?
            if let start, date < start { status = 0 }
            else if let end, date >= end { status = 2 }
            else if let start, let end, start <= date, date < end { status = 1 }
            else { status = nil }
            guard filter.permits(status, inKey: Self.statusFilterKey.id) else { return false }
            if configuration.behaviors.isEmpty { return filter.permits(nil, inKey: Self.costFilterKey.id) }
            return configuration.behaviors.contains {
                let cost = $0.costQuantity == 0 ? "free" : $0.costResourceType
                return filter.permits(cost.flatMap { Self.costs.firstIndex(of: $0) }, inKey: Self.costFilterKey.id)
            }
        })
    }

    public static var applicableSortingTypes: [SekaiSorter.Keyword] {
        SekaiLocale.allCases.map { .releaseDate(in: $0) } + [.id]
    }
    public static var hasEndingDate: Bool { true }
    public static func _compare<ValueType>(usingSekaiSorter sorter: SekaiSorter, lhs: ValueType, rhs: ValueType) -> Bool? {
        guard let lhs = lhs as? Self, let rhs = rhs as? Self else { return nil }
        switch sorter.keyword {
        case .releaseDate(let locale):
            return sorter.strictCompare(lhs.startDate.value(in: locale), rhs.startDate.value(in: locale)) ?? sorter.compare(lhs.id, rhs.id)
        case .id: return sorter.compare(lhs.id, rhs.id)
        default: return nil
        }
    }
}

extension Sticker: TitleDescribable, SekaiSearchable, SekaiFilterable, SekaiSortable {
    public var _searchLocalizedStrings: [LocalizableData<String>] { [title, description] }
    public static var filterKeys: [SekaiFilter.Key] {
        [SekaiLocale.filterKey, StickerType.filterKey, Character.filterKey.withOtherOption, Character.matchingStrategyKey]
    }
    public func _matches(_ filter: SekaiFilter) -> Bool {
        availableLocales.contains { locale in
            guard filter.permits(locale),
                  filter.permits(type.value(in: locale)) else { return false }
            let ids = (characterIDs.value(in: locale) ?? []).map { Character.mapVirtualSingerID($0, includeMiku: true) }
            guard let selected = filter[Character.filterKey.id] else { return true }
            guard !selected.isEmpty else { return false }
            if filter[Character.matchingStrategyKey]?.first == 1 {
                let actual: Set<Int?> = ids.isEmpty ? [nil] : Set(ids.map { Optional($0) })
                return selected.isSubset(of: actual)
            }
            if ids.isEmpty { return selected.contains(nil) }
            return ids.contains { selected.contains($0) }
        }
    }
    public static var applicableSortingTypes: [SekaiSorter.Keyword] {
        SekaiLocale.allCases.map { .releaseDate(in: $0) } + [.id]
    }
    public static var hasEndingDate: Bool { false }
    public static func _compare<ValueType>(usingSekaiSorter sorter: SekaiSorter, lhs: ValueType, rhs: ValueType) -> Bool? {
        guard let lhs = lhs as? Self, let rhs = rhs as? Self else { return nil }
        switch sorter.keyword {
        case .releaseDate(let locale):
            return sorter.strictCompare(lhs.releaseDate.value(in: locale), rhs.releaseDate.value(in: locale)) ?? sorter.compare(lhs.id, rhs.id)
        case .id: return sorter.compare(lhs.id, rhs.id)
        default: return nil
        }
    }
}

