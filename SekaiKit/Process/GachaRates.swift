import Foundation

extension Gacha.Configuration {
    /// Rarity percentages for an ordinary draw or a supported guaranteed slot.
    /// Special wish/rate-choice lotteries retain their source rates and are not approximated.
    public func rates(guaranteeing rarity: Card.Rarity? = nil) -> [Gacha.RarityRate]? {
        guard let rarity else { return rarityRates }
        guard rarity == .three || rarity == .four,
              rarityRates.allSatisfy({ $0.lotteryType == "normal" }),
              let target = rarityRates.firstIndex(where: { $0.rarity == rarity }) else { return nil }
        let lower: Set<Card.Rarity> = rarity == .three ? [.one, .two] : [.one, .two, .three]
        var result = rarityRates
        var transferred = 0.0
        for index in result.indices where result[index].rarity.map(lower.contains) == true {
            transferred += result[index].rate
            result[index].rate = 0
        }
        result[target].rate += transferred
        return result
    }

    /// The single-card probability, as a fraction, when the complete ordinary pool is known.
    /// Returns `nil` for zero weights, missing cards, or lotteries requiring player choices.
    public func probability(of entry: Gacha.PoolCard, cardRarities: [Int: Card.Rarity], guaranteeing rarity: Card.Rarity? = nil) -> Double? {
        guard wishSelectCount == 0, !selectsCharacter,
              rarityRates.allSatisfy({ $0.lotteryType == "normal" }),
              cards.allSatisfy({ cardRarities[$0.cardID] != nil && $0.weight >= 0 && ($0.fixedBonusWeight ?? 0) == 0 }),
              cards.contains(entry), entry.weight >= 0,
              let cardRarity = cardRarities[entry.cardID],
              let rates = rates(guaranteeing: rarity),
              let rate = rates.first(where: { $0.rarity == cardRarity })?.rate else { return nil }
        let total = cards.filter { cardRarities[$0.cardID] == cardRarity }.reduce(0.0) { $0 + Double($1.weight) }
        guard total > 0, rate.isFinite, (0...100).contains(rate) else { return nil }
        return Double(entry.weight) / total * rate / 100
    }
}

/// Independent ordinary draws. Guarantees, exchanges and player-selected lotteries are excluded.
public enum GachaDrawEstimate {
    public static func probability(perDraw: Double, draws: Int) -> Double? {
        guard perDraw.isFinite, (0...1).contains(perDraw), draws >= 0 else { return nil }
        if draws == 0 || perDraw == 0 { return 0 }
        if perDraw == 1 { return 1 }
        return -expm1(Double(draws) * log1p(-perDraw))
    }

    public static func draws(perDraw: Double, target: Double) -> Int? {
        guard perDraw.isFinite, target.isFinite, (0...1).contains(perDraw), (0..<1).contains(target) else { return nil }
        if target == 0 { return 0 }
        if perDraw == 0 { return nil }
        if perDraw == 1 { return 1 }
        let result = ceil(log1p(-target) / log1p(-perDraw))
        guard result.isFinite, result < Double(Int.max) else { return nil }
        return Int(result)
    }
}
