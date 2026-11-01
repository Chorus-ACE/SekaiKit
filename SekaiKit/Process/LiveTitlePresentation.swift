import Foundation

extension Honor {
    public func configuration(in locale: SekaiLocale) -> HonorConfiguration? { record.value(in: locale) }
}

extension VirtualLive {
    public func configuration(in locale: SekaiLocale) -> VirtualLiveConfiguration? { record.value(in: locale) }

    public var endDate: LocalizableData<Date> {
        record.map { $0?.endAt.map { Date(timeIntervalSince1970: $0 / 1000) } }
    }

    /// The region's live-selection artwork, whose bundle may differ by edition.
    public func bannerImageURL(in locale: SekaiLocale? = nil) -> URL? {
        let locale = locale ?? record.majorLocale ?? .primaryLocale
        guard let bundle = configuration(in: locale)?.assetBundleName, !bundle.isEmpty else { return nil }
        return URL(string: "https://storage.sekai.best/\(locale._assetsPath)/virtual_live/select/banner/\(bundle)/\(bundle).webp")
    }

    public func homeBannerImageURL(in locale: SekaiLocale? = nil) -> URL? {
        let locale = locale ?? record.majorLocale ?? .primaryLocale
        guard configuration(in: locale) != nil else { return nil }
        return URL(string: "https://storage.sekai.best/\(locale._assetsPath)/home/banner/banner_virtuallive\(id)/banner_virtuallive\(id).webp")
    }

    /// Explicit regional selections never fall back to artwork from a different edition.
    public func previewImageURLs(in locale: SekaiLocale? = nil) -> [URL] {
        let locales = locale.map { [$0] } ?? ([record.majorLocale ?? .primaryLocale] + availableLocales)
        var urls: [URL] = []
        for locale in locales {
            for url in [bannerImageURL(in: locale), homeBannerImageURL(in: locale)].compactMap({ $0 }) where !urls.contains(url) {
                urls.append(url)
            }
        }
        return urls
    }
}
