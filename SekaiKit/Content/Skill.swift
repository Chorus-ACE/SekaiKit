//
//  Skill.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/2/28.
//

/// A card skill and the effects it applies during gameplay.
public struct Skill: Hashable, Identifiable, Sendable, SekaiCachable {
    /// The unique identifier of the skill.
    public var id: Int
    /// The full skill description in the requested locale.
    public var description: String
    /// The abbreviated skill description in the requested locale.
    public var shortDescription: String
    /// The recognized display category of the skill, if available.
    public var style: Style?
    /// The sprite name associated with the skill description in the source data.
    public var _descriptionSpriteName: String
    /// The skill filter identifier from the source data.
    public var _filterID: Int
    /// The effects activated by the skill.
    public var effects: [Effect]
    
    /// An effect applied by a skill, including activation conditions and level details.
    public struct Effect: Hashable, Sendable, SekaiCachable {
        /// The kind of effect applied by the skill.
        public var type: EffectType
        /// The note judgment required to activate the effect, if specified.
        public var activateNotesJudgmentType: NotesJudgmentType?
        /// The character rank used by the activation condition, if specified.
        public var activateCharacterRank: Int?
        /// A Boolean value indicating whether the condition accepts values at or above its threshold.
        public var conditionIncludesGreater: Bool
        /// The activation condition type string from the source data, if provided.
        public var _conditionType: String?
        /// The effect’s values at each skill level.
        public var details: [EffectDetail]
        /// The unit specified by the skill enhancement condition, if any.
        public var enhancement: Unit?
        
        /// The duration and magnitude of an effect at a particular skill level.
        public struct EffectDetail: Hashable, Sendable, SekaiCachable {
            /// The skill level to which these values apply.
            public var level: Int
            /// The activation duration value from the source data.
            public var duration: Int
            /// The interpretation of the effect’s magnitude.
            public var valueType: ValueType
            /// The effect magnitude, interpreted according to ``valueType``.
            public var value: Int
            
            /// The way an effect magnitude is interpreted.
            public enum ValueType: String, Hashable, CaseIterable, Codable, Sendable, SekaiCachable {
                /// A proportional rate.
                case rate
                /// A fixed amount.
                case fixed
                /// A rate relative to a reference value.
                case referenceRate = "reference_rate"
            }
        }
        
        /// The gameplay behavior of a skill effect.
        public enum EffectType: String, Hashable, CaseIterable, Codable, Sendable, SekaiCachable {
            /// An effect that increases score.
            case scoreUp = "score_up"
            /// An effect that improves note judgments.
            case judgmentUp = "judgment_up"
            /// An effect that restores life.
            case lifeRecovery = "life_recovery"
            /// A score increase conditional on remaining life.
            case scoreUpConditionLife = "score_up_condition_life"
            /// A score increase with a maintenance condition.
            case scoreUpKeep = "score_up_keep"
            /// A score increase based on character rank.
            case scoreUpCharacterRank = "score_up_character_rank"
            /// A score increase based on other members’ skill values.
            case otherMemberScoreUpReferenceRate = "other_member_score_up_reference_rate"
            /// A score increase based on the number of members in a unit.
            case scoreUpUnitCount = "score_up_unit_count"
        }
        
        /// A note judgment used by a skill activation condition.
        public enum NotesJudgmentType: String, Hashable, CaseIterable, Codable, Sendable, SekaiCachable {
            /// A Bad judgment.
            case bad
            /// A Good judgment.
            case good
            /// A Great judgment.
            case great
            /// A Perfect judgment.
            case perfect
        }
    }
    
    /// A skill category used for display and filtering.
    public enum Style: Int, Hashable, CaseIterable, Codable, Sendable, SekaiCachable {
        /// An effect that increases score.
        case scoreUp = 1
        /// A special score increase skill.
        case specialScoreUp
        /// An effect that improves note judgments.
        case judgmentUp
        /// An effect that restores life.
        case lifeRecovery
    }
}

extension Skill {
    /// Loads skills for a locale.
    ///
    /// - Parameter locale: The locale whose skill descriptions are requested.
    /// - Returns: The skills, or `nil` if the request fails.
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
