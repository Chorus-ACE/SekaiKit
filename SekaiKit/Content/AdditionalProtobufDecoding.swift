import Foundation

extension Comic {
    internal init(protobuf p: _Comic) {
        id = Int(p.id); title = .unlocalized(p.title); assetBundleName = .unlocalized(p.assetbundleName)
        minimumRank = .unlocalized(p.hasFromUserRank ? Int(p.fromUserRank) : nil)
        maximumRank = .unlocalized(p.hasToUserRank ? Int(p.toUserRank) : nil)
    }
}
extension Sticker {
    internal init(protobuf p: _Sticker) {
        id = Int(p.id); title = .unlocalized(p.name)
        let text = p.description_p.trimmingCharacters(in: .whitespacesAndNewlines)
        description = .unlocalized(p.hasDescription_p && !text.isEmpty ? text : nil)
        type = .unlocalized(StickerType(rawValue: p.stampType) ?? .unknown)
        assetBundleName = .unlocalized(p.hasAssetbundleName ? p.assetbundleName : nil)
        balloonAssetBundleName = .unlocalized(p.hasBalloonAssetbundleName ? p.balloonAssetbundleName : nil)
        characterIDs = .unlocalized(Array(Set([p.characterID1, p.characterID2].filter { $0 > 0 }.map(Int.init))).sorted())
        gameCharacterUnitID = .unlocalized(p.hasGameCharacterUnitID ? Int(p.gameCharacterUnitID) : nil)
        let seconds = Double(p.archivePublishedAt) / 1000
        releaseDate = .unlocalized(p.hasArchivePublishedAt && !(1230768000..<1262304000).contains(seconds) ? Date(timeIntervalSince1970: seconds) : nil)
        archiveIsHidden = .unlocalized(p.archiveDisplayType == "hide")
    }
}
extension MySekaiFixture {
    internal init(protobuf p: _Fixture) {
        id = Int(p.id); title = .unlocalized(p.name)
        displayOrder = .unlocalized(p.hasSeq ? Int(p.seq) : nil)
        description = .unlocalized(p.hasFlavorText ? p.flavorText : nil)
        type = .unlocalized(FixtureType(rawValue: p.mysekaiFixtureType))
        site = .unlocalized(Site(rawValue: p.mysekaiSettableSiteType))
        layout = .unlocalized(Layout(rawValue: p.mysekaiSettableLayoutType))
        assetBundleName = .unlocalized(p.hasAssetbundleName ? p.assetbundleName : nil)
        mainGenre = .unlocalized(p.hasMainGenre ? p.mainGenre : nil)
        subGenre = .unlocalized(p.hasSubGenre ? p.subGenre : nil)
        size = .unlocalized(p.hasGridSize && p.gridSize.hasWidth && p.gridSize.hasDepth && p.gridSize.hasHeight ? Size(width: Int(p.gridSize.width), depth: Int(p.gridSize.depth), height: Int(p.gridSize.height)) : nil)
        canDisassemble = .unlocalized(p.hasIsDisassembled ? p.isDisassembled : nil)
        hasCharacterAction = .unlocalized(p.hasIsGameCharacterAction ? p.isGameCharacterAction : nil)
        blueprints = .unlocalized(p.blueprints.map { blueprint in
            Blueprint(id: Int(blueprint.id), canSketch: blueprint.isEnableSketch,
                      obtainedByConversion: blueprint.isObtainedByConvert,
                      craftCountLimit: blueprint.hasCraftCountLimit ? Int(blueprint.craftCountLimit) : nil,
                      availableWithoutPossession: blueprint.isAvailableWithoutPossession,
                      materials: blueprint.materials.map { MaterialCost(id: Int($0.id), name: $0.hasName ? $0.name : nil, quantity: Int($0.quantity), assetBundleName: $0.hasAssetbundleName ? $0.assetbundleName : nil) })
        })
        // No blueprint means unknown/unavailable crafting cost, rather than free crafting.
        materials = .unlocalized(p.blueprints.first.map { blueprint in
            blueprint.materials.map { MaterialCost(id: Int($0.id), name: $0.hasName ? $0.name : nil, quantity: Int($0.quantity), assetBundleName: $0.hasAssetbundleName ? $0.assetbundleName : nil) }
        })
    }
}
extension ReleaseCondition {
    internal init(protobuf p: _ReleaseCondition) {
        id = Int(p.id); title = .unlocalized(p.hasSentence ? p.sentence : nil)
        type = p.releaseConditionType
        typeID = p.hasReleaseConditionTypeID ? Int(p.releaseConditionTypeID) : nil
        typeLevel = p.hasReleaseConditionTypeLevel ? Int(p.releaseConditionTypeLevel) : nil
    }
}
extension Skill {
    internal init(protobuf p: _Skill) {
        id = Int(p.id); description = p.description_p; shortDescription = p.shortDescription
        style = Style(rawValue: Int(p.skillFilterID)); _descriptionSpriteName = p.descriptionSpriteName; _filterID = Int(p.skillFilterID)
        effects = p.skillEffects.map { effect in
            Effect(type: Effect.EffectType(rawValue: effect.skillEffectType) ?? .unknown,
                   activateNotesJudgmentType: Effect.NotesJudgmentType(rawValue: effect.activateNotesJudgmentType),
                   activateCharacterRank: effect.hasActivateCharacterRank ? Int(effect.activateCharacterRank) : nil,
                   conditionIncludesGreater: effect.conditionType == "equals_or_over",
                   _conditionType: effect.hasConditionType ? effect.conditionType : nil,
                   details: effect.skillEffectDetails.map {
                       Effect.EffectDetail(level: Int($0.level), duration: $0.activateEffectDuration, valueType: Effect.EffectDetail.ValueType(rawValue: $0.activateEffectValueType) ?? .unknown, value: Int($0.activateEffectValue))
                   }, enhancement: Unit(rawValue: effect.skillEnhanceCondition.unit))
        }
    }
}
extension Song {
    internal init(protobuf p: _Song) {
        id = Int(p.id); title = .unlocalized(p.title); isNewlyWrittenMusic = p.isNewlyWrittenMusic
        creatorArtist = .unlocalized(p.creator); composer = .unlocalized(p.composer); arranger = .unlocalized(p.arranger); lyricist = .unlocalized(p.lyricist)
        publishDate = protobufDate(p.publishedAt, present: p.hasPublishedAt); _releaseDate = protobufDate(p.releasedAt, present: p.hasReleasedAt)
        categories = p.tags.compactMap(Category.init(rawValue:)); availableMedia = p.media.compactMap(MediaType.init(rawValue:))
        difficultyLevel = Dictionary(p.charts.compactMap { chart in Difficulty(rawValue: chart.musicDifficulty).map { ($0, Int(chart.playLevel)) } }, uniquingKeysWith: { _, last in last })
        noteCounts = Dictionary(p.charts.compactMap { chart in Difficulty(rawValue: chart.musicDifficulty).map { ($0, Int(chart.totalNoteCount)) } }, uniquingKeysWith: { _, last in last })
        liveStageID = Int(p.liveStageID); dancerCount = Int(p.dancerCount); selfDancerPosition = Int(p.selfDancerPosition); releaseConditionID = Int(p.releaseConditionID)
        assetbundleName = p.assetbundleName; liveTalkBackgroundAssetBundleName = p.liveTalkBackgroundAssetbundleName
        isFullLength = p.isFullLength; fillerSec = p.fillerSec
        secForMusicScoreMaker = p.hasSecForMusicScoreMaker ? Int(p.secForMusicScoreMaker) : nil
        isAvailableForMusicScoreMaker = p.hasIsAvailableForMusicScoreMaker ? p.isAvailableForMusicScoreMaker : nil
    }
}
extension Song.VocalVersion {
    internal init(protobuf p: _SongVocal) {
        id = Int(p.id); songID = Int(p.musicID); caption = .unlocalized(p.hasCaption ? p.caption : nil)
        type = VocalType(rawValue: p.musicVocalType) ?? .unknown
        publishDate = Date(timeIntervalSince1970: Double(p.archivePublishedAt) / 1000)
        releaseConditionID = Int(p.releaseConditionID); assetBundleName = p.assetbundleName
        characters = p.characters.map { VocalCharacter(protobuf: $0) }
    }
}
extension Song.VocalVersion.VocalCharacter {
    internal init(protobuf p: _Vocalist) {
        name = .unlocalized(p.hasName ? p.name : nil); characterID = Int(p.id); isInternalCharacter = p.isInternal
    }
}
extension MusicMeta {
    internal init?(protobuf p: _MusicMeta) {
        guard let difficulty = Song.Difficulty(rawValue: p.difficulty), p.musicTime.isFinite, p.musicTime > 0,
              p.baseScore.isFinite, p.feverScore.isFinite, p.eventRate.isFinite else { return nil }
        musicID = Int(p.musicID); self.difficulty = difficulty; duration = p.musicTime
        baseScore = p.baseScore; feverScore = p.feverScore; eventRate = p.eventRate
    }
}
extension Episode {
    internal init(protobuf p: _Episode, locale: SekaiLocale, kind: Kind) {
        episodeID = Int(p.id); parentID = Int(p.parentID); number = Int(p.number); title = p.title; chapterTitle = p.chapterTitle
        scenarioID = p.scenarioID; scenarioPath = p.scenarioPath; imagePath = p.hasImagePath ? p.imagePath : nil
        self.locale = locale; self.kind = kind
    }
}
extension Gacha {
    internal init(protobuf p: _Gacha) {
        id = Int(p.id); title = .unlocalized(p.name)
        let oldTypes = [1: "normal", 2: "ceil", 3: "gift", 4: "beginner", 5: "subeginner", 6: "sureturn", 7: "sunormal", 8: "return"]
        type = GachaType(rawValue: p.hasGachaTypeName ? p.gachaTypeName : oldTypes[p.gachaType.rawValue] ?? "") ?? .unknown
        summary = .unlocalized(p.gachaInformation.hasSummary ? p.gachaInformation.summary : nil)
        description = .unlocalized(p.gachaInformation.hasDescription_p ? p.gachaInformation.description_p : nil)
        startDate = protobufDate(p.startAt, present: p.hasStartAt); endDate = protobufDate(p.endAt, present: p.hasEndAt)
        assetBundleName = p.assetBundleName
        configuration = .unlocalized(Configuration(showsPeriod: p.isShowPeriod,
            spinLimit: p.hasSpinLimit ? Int(p.spinLimit) : nil, dailySpinLimit: p.hasDailySpinLimit ? Int(p.dailySpinLimit) : nil,
            drawableHours: p.hasDrawableGachaHour ? Int(p.drawableGachaHour) : nil, ceilItemID: p.hasGachaCeilItemID ? Int(p.gachaCeilItemID) : nil,
            wishSelectCount: Int(p.wishSelectCount), selectsCharacter: p.isSelectCharacter,
            pickupCardIDs: p.gachaPickups.map { Int($0.cardID) },
            cards: p.gachaDetails.map { PoolCard(id: Int($0.id), cardID: Int($0.cardID), weight: Int($0.weight), isWish: $0.isWish, wishType: $0.hasWishType ? $0.wishType : nil, fixedBonusWeight: $0.hasFixedBonusWeight ? Int($0.fixedBonusWeight) : nil) },
            rarityRates: p.gachaCardRarityRates.enumerated().map { index, rate in
                let rarity = [1: "rarity_2", 2: "rarity_3", 3: "rarity_4", 4: "rarity_birthday"]
                let lottery = [1: "normal", 2: "categorized_wish", 3: "rate_choice_first", 4: "rate_choice_second"]
                return RarityRate(id: rate.hasID ? Int(rate.id) : -(index + 1), rarityType: rate.hasRarityName ? rate.rarityName : rarity[rate.cardRarityType.rawValue] ?? "", lotteryType: rate.hasLotteryName ? rate.lotteryName : lottery[rate.lotteryType.rawValue] ?? "", rate: rate.hasPreciseRate ? rate.preciseRate : Double(rate.rate))
            }, behaviors: p.gachaBehaviors.map {
                let behavior = [1: "normal", 2: "once_a_day", 3: "once_a_week", 4: "over_rarity_3_once", 5: "over_rarity_4_once"]
                let resource = [1: "jewel", 2: "paid_jewel", 3: "gacha_ticket"]
                return Behavior(id: Int($0.id), type: $0.hasTypeName ? $0.typeName : behavior[$0.gachaBehaviorType.rawValue] ?? "", costResourceType: $0.hasCostResourceTypeName ? $0.costResourceTypeName : resource[$0.costResourceType.rawValue], costResourceID: $0.hasCostResourceID ? Int($0.costResourceID) : nil, costQuantity: Int($0.costResourceQuantity), spinCount: Int($0.spinCount), executeLimit: $0.hasExecuteLimit ? Int($0.executeLimit) : nil, groupID: $0.hasGroupID ? Int($0.groupID) : nil, priority: Int($0.priority))
            }))
    }
}
