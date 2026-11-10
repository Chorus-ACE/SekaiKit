import Foundation
import SekaiKitMacro
internal import SwiftProtobuf
internal import SwiftyJSON

/// Regional master-data values; absent scalar fields remain nil.
public struct HonorLevel: Codable, Hashable, Sendable, SekaiCachable {
    public var assetBundleName: String?
    public var bonus: Int?
    public var description: String?
    public var honorID: Int?
    public var honorRarity: String?
    public var level: Int?
    public var startAt: Double?
    enum CodingKeys: String, CodingKey {
        case assetBundleName = "assetbundleName"
        case bonus = "bonus"
        case description = "description"
        case honorID = "honorId"
        case honorRarity = "honorRarity"
        case level = "level"
        case startAt = "startAt"
    }
}

/// Regional layout metadata used to compose a title's artwork.
public struct HonorGroup: Codable, Hashable, Sendable, SekaiCachable {
    public var id: Int?
    public var name: String?
    public var pronunciation: String?
    public var honorType: String?
    public var backgroundAssetBundleName: String?
    public var frameName: String?
    public var isMedalDisplayed: Bool?
    enum CodingKeys: String, CodingKey {
        case id, name, pronunciation, honorType, frameName, isMedalDisplayed
        case backgroundAssetBundleName = "backgroundAssetbundleName"
    }
    internal init(protobuf p: _HonorGroup) {
        id = p.hasID ? Int(p.id) : nil
        name = p.hasName ? p.name : nil
        pronunciation = p.hasPronunciation ? p.pronunciation : nil
        honorType = p.hasHonorType ? p.honorType : nil
        backgroundAssetBundleName = p.hasBackgroundAssetbundleName ? p.backgroundAssetbundleName : nil
        frameName = p.hasFrameName ? p.frameName : nil
        isMedalDisplayed = p.hasIsMedalDisplayed ? p.isMedalDisplayed : nil
    }
}

/// Regional master-data values; absent scalar fields remain nil.
public struct HonorConfiguration: Codable, Hashable, Sendable, SekaiCachable {
    public var group: HonorGroup? = nil
    public var assetBundleName: String?
    public var groupID: Int?
    public var honorMissionType: String?
    public var honorRarity: String?
    public var honorTypeID: Int?
    public var id: Int?
    public var levels: [HonorLevel]?
    public var name: String?
    public var seq: Int?
    public var startAt: Double?
    enum CodingKeys: String, CodingKey {
        case group
        case assetBundleName = "assetbundleName"
        case groupID = "groupId"
        case honorMissionType = "honorMissionType"
        case honorRarity = "honorRarity"
        case honorTypeID = "honorTypeId"
        case id = "id"
        case levels = "levels"
        case name = "name"
        case seq = "seq"
        case startAt = "startAt"
    }
}

/// An in-game title with independently merged regional records.
@LocalizationsCombinable
public struct Honor: Hashable, Identifiable, Sendable, SekaiCachable, LocalizationsCombinable {
    public var id: Int
    public var title: LocalizableData<String>
    public var record: LocalizableData<HonorConfiguration>
    public var startDate: LocalizableData<Date> { record.map { $0?.startAt.map { Date(timeIntervalSince1970: $0 / 1000) } } }
    public var availableLocales: [SekaiLocale] { record.localizedData.map { data in SekaiLocale.allCases.filter { data[$0] != nil } } ?? [.primaryLocale] }
    internal init(protobuf p: _HonorRecord) throws {
        let record = HonorConfiguration(protobuf: p)
        guard let id = record.id, let name = record.name else { throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Missing Honor identifier or name")) }
        self.id = id; title = .unlocalized(name); self.record = .unlocalized(record)
    }
}
extension Honor: ListGettable, GettableByID {
    public static func allInLocale(_ locale: SekaiLocale) async -> [Honor]? {
        guard let list = await requestProtobuf("honor.aar", as: _HonorList.self) else { return nil }
        let records = list.items(in: locale)
        // Existing archives predate group/background metadata. Enrich them only
        // from the selected edition while those archives remain in circulation.
        if records.contains(where: { !$0.hasGroup }),
           let json = await requestJSON("https://raw.githubusercontent.com/Sekai-World/\(locale._databasePath)/main/honorGroups.json"),
           let rows = json.array,
           let data = try? JSONSerialization.data(withJSONObject: rows.map(\.object)),
           let groups = try? JSONDecoder().decode([HonorGroup].self, from: data) {
            let lookup = Dictionary(groups.compactMap { group in group.id.map { ($0, group) } }, uniquingKeysWith: { first, _ in first })
            return try? records.map { wire in
                var model = try Honor(protobuf: wire)
                if !wire.hasGroup, let group = lookup[Int(wire.groupID)], var configuration = model.record.majorValue {
                    configuration.group = group
                    model.record = .unlocalized(configuration)
                }
                return model
            }
        }
        return try? records.map { try Honor(protobuf: $0) }
    }
}

/// Regional master-data values; absent scalar fields remain nil.
public struct VirtualLiveItem: Codable, Hashable, Sendable, SekaiCachable {
    public var assetBundleName: String?
    public var cheerPoint: Int?
    public var costJewel: Int?
    public var costVirtualCoin: Int?
    public var effectAssetbundleName: String?
    public var effectExpressionType: String?
    public var gameCharacterUnitID: Int?
    public var id: Int?
    public var name: String?
    public var priority: Int?
    public var seq: Int?
    public var subGameCharacterID: Int?
    public var unit: String?
    public var virtualItemCategory: String?
    public var virtualItemLabelType: String?
    public var virtualItemType: String?
    enum CodingKeys: String, CodingKey {
        case assetBundleName = "assetbundleName"
        case cheerPoint = "cheerPoint"
        case costJewel = "costJewel"
        case costVirtualCoin = "costVirtualCoin"
        case effectAssetbundleName = "effectAssetbundleName"
        case effectExpressionType = "effectExpressionType"
        case gameCharacterUnitID = "gameCharacterUnitId"
        case id = "id"
        case name = "name"
        case priority = "priority"
        case seq = "seq"
        case subGameCharacterID = "subGameCharacterId"
        case unit = "unit"
        case virtualItemCategory = "virtualItemCategory"
        case virtualItemLabelType = "virtualItemLabelType"
        case virtualItemType = "virtualItemType"
    }
}

/// Regional master-data values; absent scalar fields remain nil.
public struct VirtualLiveAppeal: Codable, Hashable, Sendable, SekaiCachable {
    public var appealText: String?
    public var id: Int?
    public var virtualLiveID: Int?
    public var virtualLiveStageStatus: String?
    enum CodingKeys: String, CodingKey {
        case appealText = "appealText"
        case id = "id"
        case virtualLiveID = "virtualLiveId"
        case virtualLiveStageStatus = "virtualLiveStageStatus"
    }
}

/// Regional master-data values; absent scalar fields remain nil.
public struct VirtualLiveBackgroundMusic: Codable, Hashable, Sendable, SekaiCachable {
    public var backgroundMusicID: Int?
    public var id: Int?
    public var virtualLiveID: Int?
    enum CodingKeys: String, CodingKey {
        case backgroundMusicID = "backgroundMusicId"
        case id = "id"
        case virtualLiveID = "virtualLiveId"
    }
}

/// Regional master-data values; absent scalar fields remain nil.
public struct VirtualLiveWeeklySchedule: Codable, Hashable, Sendable, SekaiCachable {
    public var dayOfWeek: String?
    public var endTime: String?
    public var id: Int?
    public var startTime: String?
    public var virtualLiveID: Int?
    enum CodingKeys: String, CodingKey {
        case dayOfWeek = "dayOfWeek"
        case endTime = "endTime"
        case id = "id"
        case startTime = "startTime"
        case virtualLiveID = "virtualLiveId"
    }
}

/// Regional master-data values; absent scalar fields remain nil.
public struct VirtualLivePerformer: Codable, Hashable, Sendable, SekaiCachable {
    public var gameCharacterUnitID: Int?
    public var id: Int?
    public var seq: Int?
    public var subGameCharacter2DID: Int?
    public var virtualLiveID: Int?
    public var virtualLivePerformanceType: String?
    enum CodingKeys: String, CodingKey {
        case gameCharacterUnitID = "gameCharacterUnitId"
        case id = "id"
        case seq = "seq"
        case subGameCharacter2DID = "subGameCharacter2dId"
        case virtualLiveID = "virtualLiveId"
        case virtualLivePerformanceType = "virtualLivePerformanceType"
    }
}

/// Regional master-data values; absent scalar fields remain nil.
public struct VirtualLiveInformation: Codable, Hashable, Sendable, SekaiCachable {
    public var description: String?
    public var summary: String?
    public var virtualLiveID: Int?
    enum CodingKeys: String, CodingKey {
        case description = "description"
        case summary = "summary"
        case virtualLiveID = "virtualLiveId"
    }
}

/// Regional master-data values; absent scalar fields remain nil.
public struct VirtualLiveLegacyReward: Codable, Hashable, Sendable, SekaiCachable {
    public var id: Int?
    public var resourceBoxID: Int?
    public var virtualLiveID: Int?
    public var virtualLiveType: String?
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case resourceBoxID = "resourceBoxId"
        case virtualLiveID = "virtualLiveId"
        case virtualLiveType = "virtualLiveType"
    }
}

/// Regional master-data values; absent scalar fields remain nil.
public struct VirtualLiveReward: Codable, Hashable, Sendable, SekaiCachable {
    public var id: Int?
    public var resourceBoxID: Int?
    public var virtualLiveID: Int?
    public var virtualLiveType: String?
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case resourceBoxID = "resourceBoxId"
        case virtualLiveID = "virtualLiveId"
        case virtualLiveType = "virtualLiveType"
    }
}

/// Regional master-data values; absent scalar fields remain nil.
public struct VirtualLiveSchedule: Codable, Hashable, Sendable, SekaiCachable {
    public var endAt: Double?
    public var id: Int?
    public var isAfterEvent: Bool?
    public var noticeGroupID: String?
    public var seq: Int?
    public var startAt: Double?
    public var virtualLiveID: Int?
    enum CodingKeys: String, CodingKey {
        case endAt = "endAt"
        case id = "id"
        case isAfterEvent = "isAfterEvent"
        case noticeGroupID = "noticeGroupId"
        case seq = "seq"
        case startAt = "startAt"
        case virtualLiveID = "virtualLiveId"
    }
}

/// Regional master-data values; absent scalar fields remain nil.
public struct VirtualLiveSetlistEntry: Codable, Hashable, Sendable, SekaiCachable {
    public var assetBundleName: String?
    public var character3DID1: Int?
    public var character3DID2: Int?
    public var character3DID3: Int?
    public var character3DID4: Int?
    public var character3DID5: Int?
    public var character3DID6: Int?
    public var id: Int?
    public var musicID: Int?
    public var musicVideoDataID: Int?
    public var musicVocalID: Int?
    public var seq: Int?
    public var virtualLiveID: Int?
    public var virtualLiveSetlistType: String?
    public var virtualLiveStageID: Int?
    enum CodingKeys: String, CodingKey {
        case assetBundleName = "assetbundleName"
        case character3DID1 = "character3dId1"
        case character3DID2 = "character3dId2"
        case character3DID3 = "character3dId3"
        case character3DID4 = "character3dId4"
        case character3DID5 = "character3dId5"
        case character3DID6 = "character3dId6"
        case id = "id"
        case musicID = "musicId"
        case musicVideoDataID = "musicVideoDataId"
        case musicVocalID = "musicVocalId"
        case seq = "seq"
        case virtualLiveID = "virtualLiveId"
        case virtualLiveSetlistType = "virtualLiveSetlistType"
        case virtualLiveStageID = "virtualLiveStageId"
    }
}

/// Regional master-data values; absent scalar fields remain nil.
public struct VirtualLiveTotalCheerPointReward: Codable, Hashable, Sendable, SekaiCachable {
    public var id: Int?
    public var resourceBoxID: Int?
    public var threshold: Int?
    public var virtualLiveID: Int?
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case resourceBoxID = "resourceBoxId"
        case threshold = "threshold"
        case virtualLiveID = "virtualLiveId"
    }
}

/// Regional master-data values; absent scalar fields remain nil.
public struct VirtualLiveTotalCheerPointSurplusReward: Codable, Hashable, Sendable, SekaiCachable {
    public var basePoint: Int?
    public var id: Int?
    public var resourceBoxID: Int?
    public var virtualLiveID: Int?
    enum CodingKeys: String, CodingKey {
        case basePoint = "basePoint"
        case id = "id"
        case resourceBoxID = "resourceBoxId"
        case virtualLiveID = "virtualLiveId"
    }
}

/// Regional master-data values; absent scalar fields remain nil.
public struct VirtualLiveItemOverrideCost: Codable, Hashable, Sendable, SekaiCachable {
    public var assetBundleName: String?
    public var costResourceID: Int?
    public var costResourceType: String?
    public var id: Int?
    public var virtualLiveID: Int?
    enum CodingKeys: String, CodingKey {
        case assetBundleName = "assetbundleName"
        case costResourceID = "costResourceId"
        case costResourceType = "costResourceType"
        case id = "id"
        case virtualLiveID = "virtualLiveId"
    }
}

/// Regional master-data values; absent scalar fields remain nil.
public struct VirtualLiveWaitingRoom: Codable, Hashable, Sendable, SekaiCachable {
    public var assetBundleName: String?
    public var endAt: Double?
    public var id: Int?
    public var lobbyAssetbundleName: String?
    public var startAt: Double?
    public var virtualLiveID: Int?
    enum CodingKeys: String, CodingKey {
        case assetBundleName = "assetbundleName"
        case endAt = "endAt"
        case id = "id"
        case lobbyAssetbundleName = "lobbyAssetbundleName"
        case startAt = "startAt"
        case virtualLiveID = "virtualLiveId"
    }
}

/// Regional master-data values; absent scalar fields remain nil.
public struct VirtualLiveConfiguration: Codable, Hashable, Sendable, SekaiCachable {
    public var archiveReleaseConditionID: Int?
    public var assetBundleName: String?
    public var endAt: Double?
    public var id: Int?
    public var name: String?
    public var rankingAnnounceAt: Double?
    public var screenMvMusicVocalID: Int?
    public var seq: Int?
    public var startAt: Double?
    public var subGameCharacterPenlightColorGroupID: Int?
    public var virtualItems: [VirtualLiveItem]?
    public var virtualLiveAppeals: [VirtualLiveAppeal]?
    public var virtualLiveBackgroundMusics: [VirtualLiveBackgroundMusic]?
    public var virtualLiveBeginnerSchedules: [VirtualLiveWeeklySchedule]?
    public var virtualLiveCharacters: [VirtualLivePerformer]?
    /// JSON values retained for an upstream table with no populated schema yet.
    public var cheerPointRewardsJSON: [String]?
    public var virtualLiveGroupID: Int?
    public var virtualLiveInformation: VirtualLiveInformation?
    public var virtualLivePlatform: String?
    public var virtualLiveReward: VirtualLiveLegacyReward?
    public var virtualLiveRewards: [VirtualLiveReward]?
    public var virtualLiveSchedules: [VirtualLiveSchedule]?
    public var virtualLiveSetlists: [VirtualLiveSetlistEntry]?
    public var virtualLiveTotalCheerPointRewards: [VirtualLiveTotalCheerPointReward]?
    public var virtualLiveTotalCheerPointSurplusReward: VirtualLiveTotalCheerPointSurplusReward?
    public var virtualLiveType: String?
    public var virtualLiveVirtualItemOverrideCost: VirtualLiveItemOverrideCost?
    public var virtualLiveWaitingRoom: VirtualLiveWaitingRoom?
    enum CodingKeys: String, CodingKey {
        case archiveReleaseConditionID = "archiveReleaseConditionId"
        case assetBundleName = "assetbundleName"
        case endAt = "endAt"
        case id = "id"
        case name = "name"
        case rankingAnnounceAt = "rankingAnnounceAt"
        case screenMvMusicVocalID = "screenMvMusicVocalId"
        case seq = "seq"
        case startAt = "startAt"
        case subGameCharacterPenlightColorGroupID = "subGameCharacterPenlightColorGroupId"
        case virtualItems = "virtualItems"
        case virtualLiveAppeals = "virtualLiveAppeals"
        case virtualLiveBackgroundMusics = "virtualLiveBackgroundMusics"
        case virtualLiveBeginnerSchedules = "virtualLiveBeginnerSchedules"
        case virtualLiveCharacters = "virtualLiveCharacters"
        case cheerPointRewardsJSON = "virtualLiveCheerPointRewards"
        case virtualLiveGroupID = "virtualLiveGroupId"
        case virtualLiveInformation = "virtualLiveInformation"
        case virtualLivePlatform = "virtualLivePlatform"
        case virtualLiveReward = "virtualLiveReward"
        case virtualLiveRewards = "virtualLiveRewards"
        case virtualLiveSchedules = "virtualLiveSchedules"
        case virtualLiveSetlists = "virtualLiveSetlists"
        case virtualLiveTotalCheerPointRewards = "virtualLiveTotalCheerPointRewards"
        case virtualLiveTotalCheerPointSurplusReward = "virtualLiveTotalCheerPointSurplusReward"
        case virtualLiveType = "virtualLiveType"
        case virtualLiveVirtualItemOverrideCost = "virtualLiveVirtualItemOverrideCost"
        case virtualLiveWaitingRoom = "virtualLiveWaitingRoom"
    }
}

/// A virtual live with independently merged regional records.
@LocalizationsCombinable
public struct VirtualLive: Hashable, Identifiable, Sendable, SekaiCachable, LocalizationsCombinable {
    public var id: Int
    public var title: LocalizableData<String>
    public var record: LocalizableData<VirtualLiveConfiguration>
    public var startDate: LocalizableData<Date> { record.map { $0?.startAt.map { Date(timeIntervalSince1970: $0 / 1000) } } }
    public var availableLocales: [SekaiLocale] { record.localizedData.map { data in SekaiLocale.allCases.filter { data[$0] != nil } } ?? [.primaryLocale] }
    internal init(protobuf p: _VirtualLiveRecord) throws {
        let record = VirtualLiveConfiguration(protobuf: p)
        guard let id = record.id, let name = record.name else { throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Missing VirtualLive identifier or name")) }
        self.id = id; title = .unlocalized(name); self.record = .unlocalized(record)
    }
}
extension VirtualLive: ListGettable, GettableByID {
    public static func allInLocale(_ locale: SekaiLocale) async -> [VirtualLive]? {
        guard let list = await requestProtobuf("virtual_live.aar", as: _VirtualLiveList.self) else { return nil }
        return try? list.items(in: locale).map { try VirtualLive(protobuf: $0) }
    }
}

extension Honor: TitleDescribable, SekaiSearchable, SekaiFilterable, SekaiSortable {
    public var _searchLocalizedStrings: [LocalizableData<String>] { [title] }
    public static var filterKeys: [SekaiFilter.Key] { [SekaiLocale.filterKey] }
    public func _matches(_ filter: SekaiFilter) -> Bool { availableLocales.contains { filter.permits($0) } }
    public static var applicableSortingTypes: [SekaiSorter.Keyword] { SekaiLocale.allCases.map { .releaseDate(in: $0) } + [.id] }
    public static var hasEndingDate: Bool { false }
    public static func _compare<T>(usingSekaiSorter sorter: SekaiSorter, lhs: T, rhs: T) -> Bool? {
        guard let lhs = lhs as? Self, let rhs = rhs as? Self else { return nil }
        switch sorter.keyword {
        case .id: return sorter.compare(lhs.id, rhs.id)
        case .releaseDate(let locale): return sorter.strictCompare(lhs.startDate.value(in: locale), rhs.startDate.value(in: locale)) ?? sorter.compare(lhs.id, rhs.id)
        default: return nil
        }
    }
}

extension VirtualLive: TitleDescribable, SekaiSearchable, SekaiFilterable, SekaiSortable {
    public var _searchLocalizedStrings: [LocalizableData<String>] { [title] }
    public static var filterKeys: [SekaiFilter.Key] { [SekaiLocale.filterKey] }
    public func _matches(_ filter: SekaiFilter) -> Bool { availableLocales.contains { filter.permits($0) } }
    public static var applicableSortingTypes: [SekaiSorter.Keyword] { SekaiLocale.allCases.map { .releaseDate(in: $0) } + [.id] }
    public static var hasEndingDate: Bool { true }
    public static func _compare<T>(usingSekaiSorter sorter: SekaiSorter, lhs: T, rhs: T) -> Bool? {
        guard let lhs = lhs as? Self, let rhs = rhs as? Self else { return nil }
        switch sorter.keyword {
        case .id: return sorter.compare(lhs.id, rhs.id)
        case .releaseDate(let locale): return sorter.strictCompare(lhs.startDate.value(in: locale), rhs.startDate.value(in: locale)) ?? sorter.compare(lhs.id, rhs.id)
        default: return nil
        }
    }
}

extension Honor {
    public enum Rarity: String, Codable, Hashable, Sendable, SekaiCachable, CaseIterable {
        case high = "high"
        case highest = "highest"
        case low = "low"
        case middle = "middle"
        case unknown
        public var localizedName: String { switch self.rawValue {
            case "high": NSLocalizedString("Honor.rarity.high", bundle: #bundle, comment: "")
            case "highest": NSLocalizedString("Honor.rarity.highest", bundle: #bundle, comment: "")
            case "low": NSLocalizedString("Honor.rarity.low", bundle: #bundle, comment: "")
            case "middle": NSLocalizedString("Honor.rarity.middle", bundle: #bundle, comment: "")
            case "unknown": NSLocalizedString("Honor.rarity.unknown", bundle: #bundle, comment: "")
            default: String(describing: self.rawValue)
            } }
    }
}

extension VirtualLive {
    public enum LiveType: String, Codable, Hashable, Sendable, SekaiCachable, CaseIterable {
        case beginner = "beginner"
        case cheerfulCarnival = "cheerful_carnival"
        case normal = "normal"
        case soloVirtualLive = "solo_virtual_live"
        case streaming = "streaming"
        case virtualMessage = "virtual_message"
        case unknown
        public var localizedName: String { switch self.rawValue {
            case "beginner": NSLocalizedString("VirtualLive.livetype.beginner", bundle: #bundle, comment: "")
            case "cheerful_carnival": NSLocalizedString("VirtualLive.livetype.cheerful_carnival", bundle: #bundle, comment: "")
            case "normal": NSLocalizedString("VirtualLive.livetype.normal", bundle: #bundle, comment: "")
            case "solo_virtual_live": NSLocalizedString("VirtualLive.livetype.solo_virtual_live", bundle: #bundle, comment: "")
            case "streaming": NSLocalizedString("VirtualLive.livetype.streaming", bundle: #bundle, comment: "")
            case "unknown": NSLocalizedString("VirtualLive.livetype.unknown", bundle: #bundle, comment: "")
            case "virtual_message": NSLocalizedString("VirtualLive.livetype.virtual_message", bundle: #bundle, comment: "")
            default: String(describing: self.rawValue)
            } }
    }
}

extension HonorLevel {
    internal init(protobuf p: _HonorRecordLevels) {
        assetBundleName = p.hasAssetbundleName ? p.assetbundleName : nil
        bonus = p.hasBonus ? Int(p.bonus) : nil
        description = p.hasDescription_p ? p.description_p : nil
        honorID = p.hasHonorID ? Int(p.honorID) : nil
        honorRarity = p.hasHonorRarity ? p.honorRarity : nil
        level = p.hasLevel ? Int(p.level) : nil
        startAt = p.hasStartAt ? p.startAt : nil
    }
}

extension HonorConfiguration {
    internal init(protobuf p: _HonorRecord) {
        group = p.hasGroup ? HonorGroup(protobuf: p.group) : nil
        assetBundleName = p.hasAssetbundleName ? p.assetbundleName : nil
        groupID = p.hasGroupID ? Int(p.groupID) : nil
        honorMissionType = p.hasHonorMissionType ? p.honorMissionType : nil
        honorRarity = p.hasHonorRarity ? p.honorRarity : nil
        honorTypeID = p.hasHonorTypeID ? Int(p.honorTypeID) : nil
        id = p.hasID ? Int(p.id) : nil
        levels = p.levels.map { HonorLevel(protobuf: $0) }
        name = p.hasName ? p.name : nil
        seq = p.hasSeq ? Int(p.seq) : nil
        startAt = p.hasStartAt ? p.startAt : nil
    }
}

extension VirtualLiveItem {
    internal init(protobuf p: _VirtualLiveRecordVirtualItems) {
        assetBundleName = p.hasAssetbundleName ? p.assetbundleName : nil
        cheerPoint = p.hasCheerPoint ? Int(p.cheerPoint) : nil
        costJewel = p.hasCostJewel ? Int(p.costJewel) : nil
        costVirtualCoin = p.hasCostVirtualCoin ? Int(p.costVirtualCoin) : nil
        effectAssetbundleName = p.hasEffectAssetbundleName ? p.effectAssetbundleName : nil
        effectExpressionType = p.hasEffectExpressionType ? p.effectExpressionType : nil
        gameCharacterUnitID = p.hasGameCharacterUnitID ? Int(p.gameCharacterUnitID) : nil
        id = p.hasID ? Int(p.id) : nil
        name = p.hasName ? p.name : nil
        priority = p.hasPriority ? Int(p.priority) : nil
        seq = p.hasSeq ? Int(p.seq) : nil
        subGameCharacterID = p.hasSubGameCharacterID ? Int(p.subGameCharacterID) : nil
        unit = p.hasUnit ? p.unit : nil
        virtualItemCategory = p.hasVirtualItemCategory ? p.virtualItemCategory : nil
        virtualItemLabelType = p.hasVirtualItemLabelType ? p.virtualItemLabelType : nil
        virtualItemType = p.hasVirtualItemType ? p.virtualItemType : nil
    }
}

extension VirtualLiveAppeal {
    internal init(protobuf p: _VirtualLiveRecordVirtualLiveAppeals) {
        appealText = p.hasAppealText ? p.appealText : nil
        id = p.hasID ? Int(p.id) : nil
        virtualLiveID = p.hasVirtualLiveID ? Int(p.virtualLiveID) : nil
        virtualLiveStageStatus = p.hasVirtualLiveStageStatus ? p.virtualLiveStageStatus : nil
    }
}

extension VirtualLiveBackgroundMusic {
    internal init(protobuf p: _VirtualLiveRecordVirtualLiveBackgroundMusics) {
        backgroundMusicID = p.hasBackgroundMusicID ? Int(p.backgroundMusicID) : nil
        id = p.hasID ? Int(p.id) : nil
        virtualLiveID = p.hasVirtualLiveID ? Int(p.virtualLiveID) : nil
    }
}

extension VirtualLiveWeeklySchedule {
    internal init(protobuf p: _VirtualLiveRecordVirtualLiveBeginnerSchedules) {
        dayOfWeek = p.hasDayOfWeek ? p.dayOfWeek : nil
        endTime = p.hasEndTime ? p.endTime : nil
        id = p.hasID ? Int(p.id) : nil
        startTime = p.hasStartTime ? p.startTime : nil
        virtualLiveID = p.hasVirtualLiveID ? Int(p.virtualLiveID) : nil
    }
}

extension VirtualLivePerformer {
    internal init(protobuf p: _VirtualLiveRecordVirtualLiveCharacters) {
        gameCharacterUnitID = p.hasGameCharacterUnitID ? Int(p.gameCharacterUnitID) : nil
        id = p.hasID ? Int(p.id) : nil
        seq = p.hasSeq ? Int(p.seq) : nil
        subGameCharacter2DID = p.hasSubGameCharacter2DID ? Int(p.subGameCharacter2DID) : nil
        virtualLiveID = p.hasVirtualLiveID ? Int(p.virtualLiveID) : nil
        virtualLivePerformanceType = p.hasVirtualLivePerformanceType ? p.virtualLivePerformanceType : nil
    }
}

extension VirtualLiveInformation {
    internal init(protobuf p: _VirtualLiveRecordVirtualLiveInformation) {
        description = p.hasDescription_p ? p.description_p : nil
        summary = p.hasSummary ? p.summary : nil
        virtualLiveID = p.hasVirtualLiveID ? Int(p.virtualLiveID) : nil
    }
}

extension VirtualLiveLegacyReward {
    internal init(protobuf p: _VirtualLiveRecordVirtualLiveReward) {
        id = p.hasID ? Int(p.id) : nil
        resourceBoxID = p.hasResourceBoxID ? Int(p.resourceBoxID) : nil
        virtualLiveID = p.hasVirtualLiveID ? Int(p.virtualLiveID) : nil
        virtualLiveType = p.hasVirtualLiveType ? p.virtualLiveType : nil
    }
}

extension VirtualLiveReward {
    internal init(protobuf p: _VirtualLiveRecordVirtualLiveRewards) {
        id = p.hasID ? Int(p.id) : nil
        resourceBoxID = p.hasResourceBoxID ? Int(p.resourceBoxID) : nil
        virtualLiveID = p.hasVirtualLiveID ? Int(p.virtualLiveID) : nil
        virtualLiveType = p.hasVirtualLiveType ? p.virtualLiveType : nil
    }
}

extension VirtualLiveSchedule {
    internal init(protobuf p: _VirtualLiveRecordVirtualLiveSchedules) {
        endAt = p.hasEndAt ? p.endAt : nil
        id = p.hasID ? Int(p.id) : nil
        isAfterEvent = p.hasIsAfterEvent ? p.isAfterEvent : nil
        noticeGroupID = p.hasNoticeGroupID ? p.noticeGroupID : nil
        seq = p.hasSeq ? Int(p.seq) : nil
        startAt = p.hasStartAt ? p.startAt : nil
        virtualLiveID = p.hasVirtualLiveID ? Int(p.virtualLiveID) : nil
    }
}

extension VirtualLiveSetlistEntry {
    internal init(protobuf p: _VirtualLiveRecordVirtualLiveSetlists) {
        assetBundleName = p.hasAssetbundleName ? p.assetbundleName : nil
        character3DID1 = p.hasCharacter3DID1 ? Int(p.character3DID1) : nil
        character3DID2 = p.hasCharacter3DID2 ? Int(p.character3DID2) : nil
        character3DID3 = p.hasCharacter3DID3 ? Int(p.character3DID3) : nil
        character3DID4 = p.hasCharacter3DID4 ? Int(p.character3DID4) : nil
        character3DID5 = p.hasCharacter3DID5 ? Int(p.character3DID5) : nil
        character3DID6 = p.hasCharacter3DID6 ? Int(p.character3DID6) : nil
        id = p.hasID ? Int(p.id) : nil
        musicID = p.hasMusicID ? Int(p.musicID) : nil
        musicVideoDataID = p.hasMusicVideoDataID ? Int(p.musicVideoDataID) : nil
        musicVocalID = p.hasMusicVocalID ? Int(p.musicVocalID) : nil
        seq = p.hasSeq ? Int(p.seq) : nil
        virtualLiveID = p.hasVirtualLiveID ? Int(p.virtualLiveID) : nil
        virtualLiveSetlistType = p.hasVirtualLiveSetlistType ? p.virtualLiveSetlistType : nil
        virtualLiveStageID = p.hasVirtualLiveStageID ? Int(p.virtualLiveStageID) : nil
    }
}

extension VirtualLiveTotalCheerPointReward {
    internal init(protobuf p: _VirtualLiveRecordVirtualLiveTotalCheerPointRewards) {
        id = p.hasID ? Int(p.id) : nil
        resourceBoxID = p.hasResourceBoxID ? Int(p.resourceBoxID) : nil
        threshold = p.hasThreshold ? Int(p.threshold) : nil
        virtualLiveID = p.hasVirtualLiveID ? Int(p.virtualLiveID) : nil
    }
}

extension VirtualLiveTotalCheerPointSurplusReward {
    internal init(protobuf p: _VirtualLiveRecordVirtualLiveTotalCheerPointSurplusReward) {
        basePoint = p.hasBasePoint ? Int(p.basePoint) : nil
        id = p.hasID ? Int(p.id) : nil
        resourceBoxID = p.hasResourceBoxID ? Int(p.resourceBoxID) : nil
        virtualLiveID = p.hasVirtualLiveID ? Int(p.virtualLiveID) : nil
    }
}

extension VirtualLiveItemOverrideCost {
    internal init(protobuf p: _VirtualLiveRecordVirtualLiveVirtualItemOverrideCost) {
        assetBundleName = p.hasAssetbundleName ? p.assetbundleName : nil
        costResourceID = p.hasCostResourceID ? Int(p.costResourceID) : nil
        costResourceType = p.hasCostResourceType ? p.costResourceType : nil
        id = p.hasID ? Int(p.id) : nil
        virtualLiveID = p.hasVirtualLiveID ? Int(p.virtualLiveID) : nil
    }
}

extension VirtualLiveWaitingRoom {
    internal init(protobuf p: _VirtualLiveRecordVirtualLiveWaitingRoom) {
        assetBundleName = p.hasAssetbundleName ? p.assetbundleName : nil
        endAt = p.hasEndAt ? p.endAt : nil
        id = p.hasID ? Int(p.id) : nil
        lobbyAssetbundleName = p.hasLobbyAssetbundleName ? p.lobbyAssetbundleName : nil
        startAt = p.hasStartAt ? p.startAt : nil
        virtualLiveID = p.hasVirtualLiveID ? Int(p.virtualLiveID) : nil
    }
}

extension VirtualLiveConfiguration {
    internal init(protobuf p: _VirtualLiveRecord) {
        archiveReleaseConditionID = p.hasArchiveReleaseConditionID ? Int(p.archiveReleaseConditionID) : nil
        assetBundleName = p.hasAssetbundleName ? p.assetbundleName : nil
        endAt = p.hasEndAt ? p.endAt : nil
        id = p.hasID ? Int(p.id) : nil
        name = p.hasName ? p.name : nil
        rankingAnnounceAt = p.hasRankingAnnounceAt ? p.rankingAnnounceAt : nil
        screenMvMusicVocalID = p.hasScreenMvMusicVocalID ? Int(p.screenMvMusicVocalID) : nil
        seq = p.hasSeq ? Int(p.seq) : nil
        startAt = p.hasStartAt ? p.startAt : nil
        subGameCharacterPenlightColorGroupID = p.hasSubGameCharacterPenlightColorGroupID ? Int(p.subGameCharacterPenlightColorGroupID) : nil
        virtualItems = p.virtualItems.map { VirtualLiveItem(protobuf: $0) }
        virtualLiveAppeals = p.virtualLiveAppeals.map { VirtualLiveAppeal(protobuf: $0) }
        virtualLiveBackgroundMusics = p.virtualLiveBackgroundMusics.map { VirtualLiveBackgroundMusic(protobuf: $0) }
        virtualLiveBeginnerSchedules = p.virtualLiveBeginnerSchedules.map { VirtualLiveWeeklySchedule(protobuf: $0) }
        virtualLiveCharacters = p.virtualLiveCharacters.map { VirtualLivePerformer(protobuf: $0) }
        cheerPointRewardsJSON = p.virtualLiveCheerPointRewards
        virtualLiveGroupID = p.hasVirtualLiveGroupID ? Int(p.virtualLiveGroupID) : nil
        virtualLiveInformation = p.hasVirtualLiveInformation ? VirtualLiveInformation(protobuf: p.virtualLiveInformation) : nil
        virtualLivePlatform = p.hasVirtualLivePlatform ? p.virtualLivePlatform : nil
        virtualLiveReward = p.hasVirtualLiveReward ? VirtualLiveLegacyReward(protobuf: p.virtualLiveReward) : nil
        virtualLiveRewards = p.virtualLiveRewards.map { VirtualLiveReward(protobuf: $0) }
        virtualLiveSchedules = p.virtualLiveSchedules.map { VirtualLiveSchedule(protobuf: $0) }
        virtualLiveSetlists = p.virtualLiveSetlists.map { VirtualLiveSetlistEntry(protobuf: $0) }
        virtualLiveTotalCheerPointRewards = p.virtualLiveTotalCheerPointRewards.map { VirtualLiveTotalCheerPointReward(protobuf: $0) }
        virtualLiveTotalCheerPointSurplusReward = p.hasVirtualLiveTotalCheerPointSurplusReward ? VirtualLiveTotalCheerPointSurplusReward(protobuf: p.virtualLiveTotalCheerPointSurplusReward) : nil
        virtualLiveType = p.hasVirtualLiveType ? p.virtualLiveType : nil
        virtualLiveVirtualItemOverrideCost = p.hasVirtualLiveVirtualItemOverrideCost ? VirtualLiveItemOverrideCost(protobuf: p.virtualLiveVirtualItemOverrideCost) : nil
        virtualLiveWaitingRoom = p.hasVirtualLiveWaitingRoom ? VirtualLiveWaitingRoom(protobuf: p.virtualLiveWaitingRoom) : nil
    }
}

extension HonorConfiguration {
    public var rarity: Honor.Rarity { Honor.Rarity(rawValue: honorRarity ?? "") ?? .unknown }
}
extension HonorLevel {
    public var rarity: Honor.Rarity { Honor.Rarity(rawValue: honorRarity ?? "") ?? .unknown }
}
extension VirtualLiveConfiguration {
    public var type: VirtualLive.LiveType { VirtualLive.LiveType(rawValue: virtualLiveType ?? "") ?? .unknown }
}

extension VirtualLive {
    public enum SetlistType: String, Codable, Hashable, Sendable, SekaiCachable, CaseIterable {
        case music, mc, unknown
        public var localizedName: String { switch self.rawValue {
            case "mc": NSLocalizedString("VirtualLive.setlist-type.mc", bundle: #bundle, comment: "")
            case "music": NSLocalizedString("VirtualLive.setlist-type.music", bundle: #bundle, comment: "")
            case "unknown": NSLocalizedString("VirtualLive.setlist-type.unknown", bundle: #bundle, comment: "")
            default: String(describing: self.rawValue)
            } }
    }
}
extension VirtualLiveSetlistEntry {
    public var type: VirtualLive.SetlistType { VirtualLive.SetlistType(rawValue: virtualLiveSetlistType ?? "") ?? .unknown }
}


extension VirtualLiveConfiguration {
    /// Includes both the legacy singular reward and the regional reward list.
    public var rewardBoxIDs: [Int] {
        Array(Set((virtualLiveRewards ?? []).compactMap(\.resourceBoxID)
            + [virtualLiveReward?.resourceBoxID].compactMap { $0 })).sorted()
    }
}
