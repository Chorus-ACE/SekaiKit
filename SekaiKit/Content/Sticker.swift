import Foundation
import SekaiKitMacro
internal import SwiftyJSON

/// An in-game sticker from the regional `stamps` databases.
@LocalizationsCombinable
public struct Sticker: Hashable, Identifiable, Sendable, SekaiCachable, LocalizationsCombinable {
    /// The unique sticker identifier.
    public var id: Int
    /// The localized sticker name.
    public var title: LocalizableData<String>
    /// The localized description of how the sticker is obtained.
    public var description: LocalizableData<String>
    /// The sticker category in each locale.
    public var type: LocalizableData<StickerType>
    /// The regional sticker asset bundle names.
    public var assetBundleName: LocalizableData<String>
    /// The regional speech balloon asset bundle names, if provided.
    public var balloonAssetBundleName: LocalizableData<String>
    /// The characters depicted in the sticker; text-only stickers can have none.
    public var characterIDs: LocalizableData<[Int]>
    /// The game character unit identifier, if provided.
    public var gameCharacterUnitID: LocalizableData<Int>
    /// The regional release date, excluding the master database’s 2009 placeholders.
    public var releaseDate: LocalizableData<Date>
    /// Whether the sticker is hidden in each regional archive.
    public var archiveIsHidden: LocalizableData<Bool>

    /// The category of a sticker.
    public enum StickerType: String, CaseIterable, Codable, Hashable, SekaiCachable, Sendable {
        /// An illustration featuring one or more characters.
        case illustration
        /// A text-only sticker.
        case text
        /// A message used in Cheerful Carnival events.
        case cheerfulCarnivalMessage = "cheerful_carnival_message"
        /// An illustration without a character.
        case nonCharacterIllustration = "non_character_illustration"
        /// A category not recognized by this version of SekaiKit.
        case unknown

        /// The category name localized for the app’s current language.
        public var localizedName: String {
            NSLocalizedString("Sticker.type.\(self.rawValue)", bundle: #bundle, comment: "")
        }
    }

    /// The locales containing this sticker, in declaration order.
    public var availableLocales: [SekaiLocale] {
        SekaiLocale.allCases.filter { title.localizedData?.availableInLocale($0) ?? ($0 == .primaryLocale) }
    }

    /// Returns the sticker image URL for a locale.
    ///
    /// - Parameter locale: The locale to use, or `nil` for the preferred available locale.
    /// - Returns: The image URL, or `nil` if that locale has no image bundle.
    public func imageURL(in locale: SekaiLocale? = nil) -> URL? {
        let locale = locale ?? assetBundleName.majorLocale ?? .primaryLocale
        guard let bundle = assetBundleName.localizedData?[locale] ?? (assetBundleName.localizedData == nil ? assetBundleName.majorValue : nil), !bundle.isEmpty else { return nil }
        let assets = locale._assetsPath
        return URL(string: "https://storage.sekai.best/\(assets)/stamp/\(bundle)/\(bundle).webp")
    }
}

extension Sticker: ListGettable, GettableByID {
    /// Loads stickers from a regional master database.
    ///
    /// - Parameter locale: The edition to request.
    /// - Returns: The stickers, or `nil` if the response is unavailable or not an array.
    public static func allInLocale(_ locale: SekaiLocale) async -> [Sticker]? {
        guard let json = await requestJSON("https://sekai-world.github.io/\(locale._databasePath)/stamps.json"), let items = json.array else { return nil }
        return await Task.detached(priority: .userInitiated) { items.compactMap(Sticker.init(json:)) }.value
    }

    /// Creates a sticker from a master-data record without inventing absent dates or characters.
    internal init?(json: JSON) {
        guard let id = json["id"].int, let name = json["name"].string else { return nil }
        self.id = id
        title = .unlocalized(name)
        description = json["description"].string.flatMap {
            let text = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }.localizable()
        type = .unlocalized(StickerType(rawValue: json["stampType"].stringValue) ?? .unknown)
        assetBundleName = json["assetbundleName"].string.localizable()
        balloonAssetBundleName = json["balloonAssetbundleName"].string.localizable()
        characterIDs = .unlocalized(Array(Set([json["characterId1"].int, json["characterId2"].int].compactMap { $0 }.filter { $0 > 0 })).sorted())
        gameCharacterUnitID = json["gameCharacterUnitId"].int.localizable()
        releaseDate = json["archivePublishedAt"].date.flatMap { date in
            // Use UTC boundaries so the placeholder check is independent of the device time zone.
            (1230768000..<1262304000).contains(date.timeIntervalSince1970) ? nil : date
        }.localizable()
        archiveIsHidden = .unlocalized(json["archiveDisplayType"].string == "hide")
    }
}
