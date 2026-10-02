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
        guard let json = await requestJSON("https://sekai-world.github.io/\(locale._databasePath)/releaseConditions.json") else { return nil }
        
        let task = Task.detached(priority: .userInitiated) {
            var result: [ReleaseCondition] = []
            
            for (_, value) in json {
                result.append(.init(
                    id: value["id"].intValue,
                    title: value["sentence"].string.localizable(),
                    type: value["releaseConditionType"].stringValue,
                    typeID: value["releaseConditionTypeId"].int,
                    typeLevel: value["releaseConditionTypeLevel"].int
                ))
            }
            return result
        }
        return await task.value
    }
}
