//
//  ReleaseCondition.swift
//  SekaiKit
//
//  Created by Rain on 2026/8/17.
//

import SekaiKitMacro

@LocalizationsCombinable
public struct ReleaseCondition: Hashable, Sendable, Identifiable, SekaiCachable, LocalizationsCombinable {
    public var id: Int
    public var title: LocalizableData<String>
    public var type: String
    public var typeID: Int?
    public var typeLevel: Int?
}


extension ReleaseCondition: ListGettable, GettableByID {
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
