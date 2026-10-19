//
//  ReleaseCondition.swift
//  SekaiKit
//
//  Created by Rain on 2026/8/17.
//

import SekaiKitMacro

/// A condition required to unlock game content.
@LocalizationsCombinable
public struct ReleaseCondition: Hashable, Sendable, Identifiable, SekaiCachable, LocalizationsCombinable {
    /// The unique identifier of the release condition.
    public var id: Int
    /// The localized sentence describing the release condition.
    public var title: LocalizableData<String>
    /// The release condition type string from the source data.
    public var type: String
    /// The identifier associated with the condition type, if provided.
    public var typeID: Int?
    /// The level required by the condition, if provided.
    public var typeLevel: Int?
}


extension ReleaseCondition: ListGettable, GettableByID {
    /// Loads the records available in a locale.
    ///
    /// - Parameter locale: The locale whose records are requested.
    /// - Returns: The records for the locale, or `nil` if the required data cannot be loaded.
    public static func allInLocale(_ locale: SekaiLocale) async -> [ReleaseCondition]? {
        guard let list = await requestProtobuf("release_condition.aar", as: _ReleaseConditionList.self) else { return nil }
        return list.items(in: locale).map { ReleaseCondition(protobuf: $0) }
    }
}
