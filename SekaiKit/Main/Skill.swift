//
//  Skill.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/2/28.
//

public struct Skill: Hashable, Identifiable, Sendable, SekaiCachable {
    public var id: Int
    public var description: String
    public var shortDescription: String
    public var style: Style?
    public var _descriptionSpriteName: String
    public var _filterID: Int
    public var effects: [Effect]
    
    public struct Effect: Hashable, Sendable, SekaiCachable {
        public var type: EffectType
        public var activateNotesJudgmentType: NotesJudgmentType?
        public var activateCharacterRank: Int?
        public var conditionIncludesGreater: Bool
        public var _conditionType: String?
        public var details: [EffectDetail]
        public var enhancement: Unit?
        
        public struct EffectDetail: Hashable, Sendable, SekaiCachable {
            public var level: Int
            public var duration: Int
            public var valueType: ValueType
            public var value: Int
            
            public enum ValueType: String, Hashable, CaseIterable, Codable, Sendable, SekaiCachable {
                case rate
                case fixed
                case referenceRate = "reference_rate"
            }
        }
        
        public enum EffectType: String, Hashable, CaseIterable, Codable, Sendable, SekaiCachable {
            case scoreUp = "score_up"
            case judgmentUp = "judgment_up"
            case lifeRecovery = "life_recovery"
            case scoreUpConditionLife = "score_up_condition_life"
            case scoreUpKeep = "score_up_keep"
            case scoreUpCharacterRank = "score_up_character_rank"
            case otherMemberScoreUpReferenceRate = "other_member_score_up_reference_rate"
            case scoreUpUnitCount = "score_up_unit_count"
        }
        
        public enum NotesJudgmentType: String, Hashable, CaseIterable, Codable, Sendable, SekaiCachable {
            case bad
            case good
            case great
            case perfect
        }
    }
    
    public enum Style: Int, Hashable, CaseIterable, Codable, Sendable, SekaiCachable {
        case scoreUp = 1
        case specialScoreUp
        case judgmentUp
        case lifeRecovery
    }
}

extension Skill {
    public static func all(forLocale locale: SekaiLocale = .primaryLocale) async -> [Skill]? {
        let json = await requestJSON("https://sekai-world.github.io/\(locale._databasePath)/skills.json")
        
        if let json {
            let task = Task.detached(priority: .userInitiated) {
                var result: [Skill] = []
                for (key, value) in json {
                    var effects: [Effect] = []
                    
                    for (ek, ev) in value["skillEffects"] {
                        var details: [Effect.EffectDetail] = []
                        
                        for (dk, dv) in ev["skillEffectDetails"] {
                            details.append(.init(
                                level: dv["level"].intValue,
                                duration: dv["activateEffectDuration"].intValue,
                                valueType: Effect.EffectDetail.ValueType(rawValue: dv["activateEffectValueType"].stringValue) ?? .rate,
                                value: dv["activateEffectValue"].intValue
                            ))
                        }
                        
                        effects.append(.init(
                            type: Effect.EffectType(rawValue: ev["skillEffectType"].stringValue) ?? .scoreUp,
                            activateNotesJudgmentType: Effect.NotesJudgmentType(rawValue: ev["activateNotesJudgmentType"].stringValue),
                            activateCharacterRank: ev["activateCharacterRank"].int,
                            conditionIncludesGreater: ev["conditionType"].stringValue == "equals_or_over",
                            _conditionType: ev["conditionType"].string,
                            details: details,
                            enhancement: Unit(rawValue: ev["skillEnhanceCondition"]["unit"].stringValue)
                        ))
                    }
                    
                    result.append(.init(
                        id: value["id"].intValue,
                        description: value["description"].stringValue,
                        shortDescription: value["shortDescription"].stringValue,
                        style: Style(rawValue: value["skillFilterId"].int ?? -1),
                        _descriptionSpriteName: value["descriptionSpriteName"].stringValue,
                        _filterID: value["skillFilterId"].intValue,
                        effects: effects
                    ))
                }
                return result
            }
            return await task.value
        } else {
            return nil
        }
    }
}
