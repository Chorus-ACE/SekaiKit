//
//  Skill.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/2/28.
//

import Foundation

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
        /// The source effect ID used by description placeholders.
        public var id: Int
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
        /// The additional value per matching member, when supplied by the source.
        public var enhancementValue: Int? = nil
        /// How to interpret the enhancement magnitude.
        public var enhancementValueType: EffectDetail.ValueType? = nil
        /// The rule used to apply the enhancement.
        public var enhancementType: EnhancementType? = nil

        public enum EnhancementType: String, Hashable, Codable, Sendable, SekaiCachable {
            case subUnitScoreUp = "sub_unit_score_up"
            case unknown
        }
        
        /// The duration and magnitude of an effect at a particular skill level.
        public struct EffectDetail: Hashable, Sendable, SekaiCachable {
            /// The skill level to which these values apply.
            public var level: Int
            /// The activation duration value from the source data.
            public var duration: Double
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
                case unknown
            }
        }
        
        /// The gameplay behavior of a skill effect.
        public enum EffectType: String, Hashable, CaseIterable, Codable, Sendable, SekaiCachable {
            /// An effect that increases score.
            case scoreUp = "score_up"
            case unknown
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

        /// The display name localized for the app’s current language.
        public var localizedName: String {
            NSLocalizedString("Skill.style.\(rawValue)", bundle: #bundle, comment: "")
        }
    }
}

extension Skill {
    /// Loads skills for a locale.
    ///
    /// - Parameter locale: The locale whose skill descriptions are requested.
    /// - Returns: The skills, or `nil` if the request fails.
    public static func all(forLocale locale: SekaiLocale = .primaryLocale) async -> [Skill]? {
        guard let list = await requestProtobuf("skill.aar", as: _SkillList.self) else { return nil }
        return list.items(in: locale).map { Skill(protobuf: $0) }
    }
}


extension Skill {
    /// Resolves source effect IDs and ranges at the requested level.
    /// Player-dependent placeholders stay unavailable when no player state is provided.
    public func description(atLevel level: Int, short: Bool = false, characterName: String? = nil, characterRank: Int? = nil) -> String {
        let template = short ? shortDescription : description
        guard let regex = try? NSRegularExpression(pattern: #"\{\{([^{}]+)\}\}"#) else { return template }
        var result = template
        for match in regex.matches(in: template, range: NSRange(template.startIndex..., in: template)).reversed() {
            guard let range = Range(match.range, in: result),
                  let bodyRange = Range(match.range(at: 1), in: template) else { continue }
            let parts = template[bodyRange].split(separator: ";")
            var replacement: String?
            if parts.count == 2 {
                let ids = parts[0].split(separator: ",").compactMap { Int($0) }
                let first = effects.first { $0.id == ids.first }
                let detail = first?.details.first { $0.level == level }
                let last = effects.first { $0.id == ids.last }?.details.first { $0.level == level }
                func number(_ value: Int?) -> String? { value?.formatted(.number.grouping(.never)) }
                switch parts[1] {
                case "c": replacement = characterName
                case "d": replacement = detail?.duration.formatted(.number.precision(.fractionLength(0...2)))
                case "e": replacement = number(first?.enhancementValue)
                case "m":
                    if first?.enhancementType == .subUnitScoreUp, first?.enhancementValueType == .rate, let base = detail?.value, let bonus = first?.enhancementValue {
                        // Four other unit members, plus the full-team matching bonus.
                        replacement = number(base + bonus * 5)
                    }
                case "v":
                    if ids.count == 2, let base = detail?.value, let bonus = last?.value { replacement = number(base + bonus) }
                    else { replacement = number(detail?.value) }
                case "r":
                    if let low = detail?.value, let high = last?.value { replacement = low == high ? number(low) : "\(low)–\(high)" }
                case "s":
                    if let rank = characterRank, let base = detail?.value, let lower = ids.first, let upper = ids.last, lower <= upper {
                        let bonus = effects.filter { (lower...upper).contains($0.id) && $0.type == .scoreUpCharacterRank }
                            .filter { ($0.activateCharacterRank ?? Int.max) <= rank }
                            .compactMap { $0.details.first { $0.level == level }?.value }.max() ?? 0
                        replacement = number(base + bonus)
                    }
                default: break
                }
            }
            result.replaceSubrange(range, with: replacement ?? "—")
        }
        return result
    }
}
