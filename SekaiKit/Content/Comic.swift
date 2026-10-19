import Foundation
import SekaiKitMacro
internal import SwiftyJSON

/// A localized one-panel comic displayed in the game’s loading screen.
@LocalizationsCombinable
public struct Comic: Hashable, Identifiable, Sendable, SekaiCachable, LocalizationsCombinable {
    public var id: Int
    public var title: LocalizableData<String>
    public var assetBundleName: LocalizableData<String>
    public var minimumRank: LocalizableData<Int>
    public var maximumRank: LocalizableData<Int>

    public var availableLocales: [SekaiLocale] {
        SekaiLocale.allCases.filter { title.localizedData?.availableInLocale($0) ?? ($0 == .primaryLocale) }
    }
    public func imageURL(in locale: SekaiLocale? = nil) -> URL? {
        let locale = locale ?? assetBundleName.majorLocale ?? .primaryLocale
        guard let bundle = assetBundleName.value(in: locale) else { return nil }
        return URL(string: "https://storage.sekai.best/\(locale._assetsPath)/comic/one_frame/\(bundle).webp")
    }
}

extension Comic: ListGettable, GettableByID {
    public static func allInLocale(_ locale: SekaiLocale) async -> [Comic]? {
        guard let list = await requestProtobuf("comic.aar", as: _ComicList.self) else { return nil }
        return list.items(in: locale).map { Comic(protobuf: $0) }
    }
    internal init?(json: JSON) {
        guard let id = json["id"].int, let title = json["title"].string,
              let bundle = json["assetbundleName"].string, bundle.hasPrefix("comic_") else { return nil }
        self.id = id
        self.title = .unlocalized(title)
        assetBundleName = .unlocalized(bundle)
        minimumRank = json["fromUserRank"].int.localizable()
        maximumRank = json["toUserRank"].int.localizable()
    }
}
