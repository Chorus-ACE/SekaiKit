import Foundation
import SekaiKitMacro
internal import SwiftyJSON

/// A gacha and its regional schedules, card pools, rates, and payment options.
///
/// Pools and payment rules are stored per locale because editions can offer
/// different cards and guarantees under the same gacha identifier.
@LocalizationsCombinable
public struct Gacha: Hashable, Identifiable, Sendable, SekaiCachable, LocalizationsCombinable {
    /// The unique identifier of the gacha.
    public var id: Int
    /// The localized gacha name.
    public var title: LocalizableData<String>
    /// The gacha category in each locale.
    public var type: GachaType
    /// The localized introduction to the gacha.
    public var summary: LocalizableData<String>
    /// The localized rules and additional information.
    public var description: LocalizableData<String>
    /// The opening date in each locale.
    public var startDate: LocalizableData<Date>
    /// The closing date in each locale.
    public var endDate: LocalizableData<Date>
    /// The asset bundle name in each locale.
    public var assetBundleName: String
    /// The regional pool and drawing rules.
    public var configuration: LocalizableData<Configuration>

    /// The category of a gacha.
    public enum GachaType: String, CaseIterable, Codable, Hashable, SekaiCachable, Sendable {
        /// A standard gacha.
        case normal
        /// A gacha with an exchange system.
        case ceil
        /// A gacha with an additional gift.
        case gift
        /// A beginner gacha.
        case beginner
        /// A special beginner gacha.
        case specialBeginner = "subeginner"
        /// A special returning-player gacha.
        case specialReturn = "sureturn"
        /// A special standard gacha.
        case specialNormal = "sunormal"
        /// A returning-player gacha.
        case returning = "return"
        /// A category not recognized by this version of SekaiKit.
        case unknown

        /// The category name localized for the app’s current language.
        public var localizedName: String {
            NSLocalizedString("Gacha.type.\(self.rawValue)", bundle: #bundle, comment: "")
        }
    }

    /// The card pool, rates, and payment rules for one regional edition.
    public struct Configuration: Hashable, Sendable, SekaiCachable {
        /// Whether the game displays a fixed opening period.
        public var showsPeriod: Bool
        /// The total draw limit, if specified.
        public var spinLimit: Int?
        /// The daily draw limit, if specified.
        public var dailySpinLimit: Int?
        /// The availability duration after activation, in hours, if specified.
        public var drawableHours: Int?
        /// The exchange item identifier, if this gacha awards seals.
        public var ceilItemID: Int?
        /// The number of wish selections supported by the gacha.
        public var wishSelectCount: Int
        /// Whether the player must choose a character before drawing.
        public var selectsCharacter: Bool
        /// The card identifiers highlighted by the gacha.
        public var pickupCardIDs: [Int]
        /// The cards in the pool and their relative weights.
        public var cards: [PoolCard]
        /// The percentage rates for each rarity and lottery category.
        public var rarityRates: [RarityRate]
        /// The available ways to draw from this gacha.
        public var behaviors: [Behavior]
    }

    /// A card entry in a regional gacha pool.
    public struct PoolCard: Hashable, Identifiable, Sendable, SekaiCachable {
        /// The unique pool entry identifier.
        public var id: Int
        /// The identifier of the card.
        public var cardID: Int
        /// The relative drawing weight; this is not a percentage probability.
        public var weight: Int
        /// Whether this entry participates in wish selection.
        public var isWish: Bool
        /// The wish category, if the source specifies one.
        public var wishType: String?
        /// An additional fixed bonus weight, if provided.
        public var fixedBonusWeight: Int?
    }

    /// A percentage rate for one rarity within a particular lottery category.
    public struct RarityRate: Hashable, Identifiable, Sendable, SekaiCachable {
        /// The unique rate entry identifier.
        public var id: Int
        /// The source rarity value, preserving unknown rarity categories.
        public var rarityType: String
        /// The lottery category to which the rate applies.
        public var lotteryType: String
        /// The rate expressed as a percentage, such as `3` for three percent.
        public var rate: Double
        /// The recognized card rarity, or `nil` for an unknown source value.
        public var rarity: Card.Rarity? { Card.Rarity(rawValue: rarityType) }
    }

    /// A payment option and the number of draws it grants.
    public struct Behavior: Hashable, Identifiable, Sendable, SekaiCachable {
        /// The unique payment option identifier.
        public var id: Int
        /// The source behavior type, including guarantee and daily-draw rules.
        public var type: String
        /// The consumed resource type, or `nil` for a source without a resource.
        public var costResourceType: String?
        /// The consumed ticket or resource identifier, if applicable.
        public var costResourceID: Int?
        /// The number of resource units consumed.
        public var costQuantity: Int
        /// The number of draws performed by this option.
        public var spinCount: Int
        /// The execution limit, if specified.
        public var executeLimit: Int?
        /// The payment option group identifier.
        public var groupID: Int?
        /// The ordering priority within the group.
        public var priority: Int
    }

    /// The locales with gacha data, in declaration order.
    public var availableLocales: [SekaiLocale] {
        SekaiLocale.allCases.filter { configuration.localizedData?.availableInLocale($0) ?? ($0 == .primaryLocale) }
    }

    /// Returns the banner URL for a regional gacha.
    ///
    /// - Parameter locale: The locale to use, or `nil` for the primary locale.
    /// - Returns: A URL derived from the gacha ID. This does not verify that a banner exists in that locale.
    public func bannerImageURL(in locale: SekaiLocale? = nil) -> URL? {
        let locale = locale ?? .primaryLocale
        let assets = locale._assetsPath
        return URL(string: "https://storage.sekai.best/\(assets)/home/banner/banner_gacha\(id)/banner_gacha\(id).webp")
    }
    /// Image candidates, preferring the selected edition and falling back to other available editions.
    /// Some gachas have no home banner; their logo is still usable as a preview.
    public func previewImageURLs(in locale: SekaiLocale? = nil) -> [URL] {
        let preferred = locale ?? .primaryLocale
        let locales = [preferred] + availableLocales.filter { $0 != preferred }
        var result: [URL] = []
        for locale in locales {
            for url in [bannerImageURL(in: locale), logoImageURL(in: locale)].compactMap({ $0 }) where !result.contains(url) {
                result.append(url)
            }
        }
        return result
    }

    /// Returns the gacha logo URL for a locale.
    /// - Parameter locale: The locale to use, or `nil` for the preferred available locale.
    /// - Returns: The logo URL, or `nil` if the locale has no asset bundle.
    public func logoImageURL(in locale: SekaiLocale? = nil) -> URL? {
        let locale = locale ?? .primaryLocale
        let assets = locale._assetsPath
        return URL(string: "https://storage.sekai.best/\(assets)/gacha/\(assetBundleName)/logo/logo.webp")
    }
}

extension Gacha: ListGettable, GettableByID {
    /// Loads gachas from a regional master database.
    ///
    /// - Parameter locale: The edition to request.
    /// - Returns: The gacha list, or `nil` if the response is unavailable or not an array.
    public static func allInLocale(_ locale: SekaiLocale) async -> [Gacha]? {
        guard let json = await requestJSON("https://sekai-world.github.io/\(locale._databasePath)/gachas.json"), let items = json.array else { return nil }
        return await Task.detached(priority: .userInitiated) { items.compactMap(Gacha.init(json:)) }.value
    }

    /// Creates a gacha from one master-data record, retaining optional field presence.
    internal init?(json: JSON) {
        guard let id = json["id"].int, let name = json["name"].string else { return nil }
        self.id = id
        title = .unlocalized(name)
        type = GachaType(rawValue: json["gachaType"].stringValue) ?? .unknown
        summary = json["gachaInformation"]["summary"].string.localizable()
        description = json["gachaInformation"]["description"].string.localizable()
        startDate = json["startAt"].date.localizable()
        endDate = json["endAt"].date.localizable()
        assetBundleName = json["assetbundleName"].stringValue
        configuration = .unlocalized(Configuration(
            showsPeriod: json["isShowPeriod"].boolValue,
            spinLimit: json["spinLimit"].int,
            dailySpinLimit: json["dailySpinLimit"].int,
            drawableHours: json["drawableGachaHour"].int,
            ceilItemID: json["gachaCeilItemId"].int,
            wishSelectCount: json["wishSelectCount"].intValue,
            selectsCharacter: json["isSelectCharacter"].boolValue,
            pickupCardIDs: json["gachaPickups"].arrayValue.compactMap { $0["cardId"].int },
            cards: json["gachaDetails"].arrayValue.compactMap { entry in
                guard let id = entry["id"].int, let cardID = entry["cardId"].int else { return nil }
                return PoolCard(id: id, cardID: cardID, weight: entry["weight"].intValue, isWish: entry["isWish"].boolValue, wishType: entry["gachaDetailWishType"].string, fixedBonusWeight: entry["fixedBonusWeight"].int)
            },
            rarityRates: json["gachaCardRarityRates"].arrayValue.compactMap { entry in
                guard let id = entry["id"].int, let rate = entry["rate"].double else { return nil }
                return RarityRate(id: id, rarityType: entry["cardRarityType"].stringValue, lotteryType: entry["lotteryType"].stringValue, rate: rate)
            },
            behaviors: json["gachaBehaviors"].arrayValue.compactMap { entry in
                guard let id = entry["id"].int else { return nil }
                return Behavior(id: id, type: entry["gachaBehaviorType"].stringValue, costResourceType: entry["costResourceType"].string, costResourceID: entry["costResourceId"].int, costQuantity: entry["costResourceQuantity"].intValue, spinCount: entry["spinCount"].intValue, executeLimit: entry["executeLimit"].int, groupID: entry["groupId"].int, priority: entry["priority"].intValue)
            }
        ))
    }
}
