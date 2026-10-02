import Foundation
import SwiftUI

extension Character {
    internal init(protobuf value: _Character) {
        self.init(
            id: Int(value.id),
            resourceID: Int(value.resourceID),
            familyName: .unlocalized(value.hasFamilyName ? value.familyName : nil),
            givenName: .unlocalized(value.hasGivenName ? value.givenName : nil),
            familyNameRuby: .unlocalized(value.hasFamilyNameRuby ? value.familyNameRuby : nil),
            givenNameRuby: .unlocalized(value.hasGivenNameRuby ? value.givenNameRuby : nil),
            familyNameEnglish: value.hasFamilyNameEnglish ? value.familyNameEnglish : nil,
            givenNameEnglish: value.givenNameEnglish,
            gender: Gender(rawValue: value.gender) ?? .female,
            height: Measurement(value: value.height, unit: .centimeters),
            characterVoice: .unlocalized(value.hasCharacterVoice ? value.characterVoice : nil),
            birthday: value.hasBirthday ? parseToDateComponents(value.birthday) : nil,
            literalBirthday: .unlocalized(value.hasBirthday ? value.birthday : nil),
            school: .unlocalized(value.hasSchool ? value.school : nil),
            schoolClass: .unlocalized(value.hasSchoolClass ? value.schoolClass : nil),
            hobby: .unlocalized(value.hasHobby ? value.hobby : nil),
            specialSkill: .unlocalized(value.hasSpecialSkill ? value.specialSkill : nil),
            favoriteFood: .unlocalized(value.hasFavoriteFood ? value.favoriteFood : nil),
            dislikedFood: .unlocalized(value.hasDislikedFood ? value.dislikedFood : nil),
            weakness: .unlocalized(value.hasWeakness ? value.weakness : nil),
            introduction: .unlocalized(value.hasIntroduction ? value.introduction : nil),
            introductionStoryID: value.introductionStoryID,
            live2DHeightAdjustment: value.live2DHeightAdjustment,
            figure: Figure(rawValue: value.figure) ?? .lady,
            breastSize: BreastSize(rawValue: value.breastSize) ?? .none,
            unit: Unit(rawValue: value.unit) ?? .virtualSinger,
            supportUnitType: SupportUnitType(rawValue: value.supportUnitType) ?? .none,
            colorInfo: value.colorInfo.map {
                CharacterColors(
                    id: Int($0.id), unit: Unit(rawValue: $0.unit) ?? .virtualSinger,
                    mainColor: Color(hex: $0.mainColor) ?? .white,
                    skinColor: Color(hex: $0.skinColor) ?? .white,
                    skinShadowColor1: Color(hex: $0.skinShadowColor1) ?? .white,
                    skinShadowColor2: Color(hex: $0.skinShadowColor2) ?? .white
                )
            }
        )
    }
}

extension Card {
    internal init(protobuf value: _Card) {
        var parameters: [ParameterType: [Int: Int]] = [:]
        for parameter in value.cardParameters {
            if let type = ParameterType(rawValue: parameter.type) {
                parameters[type, default: [:]][Int(parameter.level)] = Int(parameter.power)
            }
        }
        self.init(
            id: Int(value.id),
            name: .unlocalized(value.hasName ? value.name : nil),
            characterID: Int(value.characterID),
            unit: Unit(member: Int(value.characterID)) ?? .virtualSinger,
            supportUnit: Unit(rawValue: value.supportUnit),
            rarity: Rarity(rawValue: value.rarity) ?? .one,
            attribute: Attribute(rawValue: value.attribute) ?? .cute,
            releaseDate: protobufDate(value.releaseAt, present: value.hasReleaseAt),
            sourceType: SourceType(rawValue: Int(value.sourceType)) ?? .normal,
            gachaPhrase: .unlocalized(value.hasGachaPhrase && value.gachaPhrase != "-" ? value.gachaPhrase : nil),
            isInitiallySpecialTrained: value.initialSpecialTrainingStatus == "done",
            skillID: Int(value.skillID),
            skillName: .unlocalized(value.hasSkillName ? value.skillName : nil),
            specialTrainingSkillID: value.hasSpecialTrainingSkillID ? Int(value.specialTrainingSkillID) : nil,
            specialTrainingSkillName: .unlocalized(value.hasSpecialTrainingSkillName ? value.specialTrainingSkillName : nil),
            cardParameters: parameters,
            specialTrainingFixedBonus: [
                .performance: Int(value.specialTrainingPower1BonusFixed),
                .stamina: Int(value.specialTrainingPower2BonusFixed),
                .technique: Int(value.specialTrainingPower3BonusFixed)
            ],
            specialTrainingRewardResourceBoxID: value.hasSpecialTrainingRewardResourceBoxID ? Int(value.specialTrainingRewardResourceBoxID) : nil,
            archiveIsHidden: value.archiveDisplayType == "hide",
            archivePublishedDate: protobufDate(value.archivePublishedAt, present: value.hasArchivePublishedAt),
            assetbundleName: value.assetbundleName
        )
    }
}

extension Event {
    internal init(protobuf value: _Event) {
        self.init(
            id: Int(value.id),
            title: .unlocalized(value.hasTitle ? value.title : nil),
            eventType: EventType(rawValue: value.eventType) ?? .marathon,
            displayingStartDate: protobufDate(value.displayingStartAt, present: value.hasDisplayingStartAt),
            startDate: protobufDate(value.startAt, present: value.hasStartAt),
            aggregateDate: protobufDate(value.aggregateAt, present: value.hasAggregateAt),
            rankingAnnouncementDate: protobufDate(value.rankingAnnounceAt, present: value.hasRankingAnnounceAt),
            distributionStartDate: protobufDate(value.distributionStartAt, present: value.hasDistributionStartAt),
            displayingEndDate: protobufDate(value.displayingEndAt, present: value.hasDisplayingEndAt),
            endDate: protobufDate(value.closedAt, present: value.hasClosedAt),
            distributionEndDate: protobufDate(value.distributionEndAt, present: value.hasDistributionEndAt),
            unit: Unit(rawValue: value.unit),
            attribute: value.hasAttribute ? Card.Attribute(rawValue: value.attribute) : nil,
            characters: value.characters.map(Int.init),
            attributeBonus: value.hasAttributeBonus ? Int(value.attributeBonus) : nil,
            characterBonus: Int(value.characterBonus),
            virtualLiveID: Int(value.virtualLiveID),
            isCountLeaderCharacterPlay: value.isCountLeaderCharacterPlay,
            eventRankingRewardRanges: value.eventRankingRewardRanges.map { range in
                EventRankingRewardRange(
                    upperBound: Int(range.upperBound), lowerBound: Int(range.lowerBound),
                    includeLowerBound: range.includeLowerBound,
                    eventRankingRewards: range.eventRankingRewards.map {
                        EventRankingRewardRange.EventRankingReward(
                            resourceBoxId: Int($0.resourceBoxID),
                            rewardConditionType: $0.hasRewardConditionType ? $0.rewardConditionType : nil
                        )
                    }
                )
            },
            assetBundleName: value.assetbundleName,
            bgmAssetbundleName: value.bgmAssetbundleName
        )
    }
}
