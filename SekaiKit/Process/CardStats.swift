import Foundation

/// Regional rules needed to calculate a card's own power, before team bonuses.
public struct CardStatRules: Hashable, Sendable, SekaiCachable {
    public struct Power: Hashable, Codable, Sendable {
        public var performance: Int
        public var technique: Int
        public var stamina: Int
        public var total: Int { performance + technique + stamina }

        internal init(_ values: [Card.ParameterType: Int]) {
            performance = values[.performance] ?? 0
            technique = values[.technique] ?? 0
            stamina = values[.stamina] ?? 0
        }
    }

    /// The regional fixed bonus for owning the card’s MySekai canvas, when available.
    public let mySekaiCanvasBonus: Power?

    public let normalMaxLevel: Int
    public let trainedMaxLevel: Int?
    public let masterRanks: [Int]
    public var episodeCount: Int { episodeBonuses.count }
    private let masterBonuses: [Int: [Card.ParameterType: Int]]
    private let episodeBonuses: [[Card.ParameterType: Int]]

    /// Decodes only complete rules; an absent or incomplete rule set is unavailable.
    internal init?(protobuf value: _CardStatRules) {
        guard value.hasNormalMaxLevel, value.normalMaxLevel > 0,
              !value.hasTrainedMaxLevel || value.trainedMaxLevel > 0 else { return nil }
        normalMaxLevel = Int(value.normalMaxLevel)
        trainedMaxLevel = value.hasTrainedMaxLevel ? Int(value.trainedMaxLevel) : nil
        func bonus(_ value: _CardFixedBonus) -> [Card.ParameterType: Int]? {
            guard value.hasPerformance, value.hasStamina, value.hasTechnique else { return nil }
            return [.performance: Int(value.performance), .stamina: Int(value.stamina), .technique: Int(value.technique)]
        }
        if value.hasMysekaiCanvasBonus {
            guard let values = bonus(value.mysekaiCanvasBonus) else { return nil }
            mySekaiCanvasBonus = Power(values)
        } else {
            mySekaiCanvasBonus = nil
        }
        var masters: [Int: [Card.ParameterType: Int]] = [0: [:]]
        var ranks = Set<Int>()
        for row in value.masterBonuses {
            guard row.hasRank, row.rank >= 0, ranks.insert(Int(row.rank)).inserted,
                  row.hasBonus, let values = bonus(row.bonus) else { return nil }
            masters[Int(row.rank)] = values
        }
        masterBonuses = masters
        masterRanks = masters.keys.sorted()
        var bonuses: [[Card.ParameterType: Int]] = []
        var sequences = Set<Int32>()
        // The converter writes episode bonuses in gameplay order, including regions without seq.
        for row in value.episodeBonuses {
            guard (!row.hasSequence || sequences.insert(row.sequence).inserted),
                  row.hasBonus, let values = bonus(row.bonus) else { return nil }
            bonuses.append(values)
        }
        episodeBonuses = bonuses
    }

    /// Returns nil when the archive lacks a requested level or the configuration is invalid.
    public func power(for card: Card, level: Int, masterRank: Int = 0, episodes: Int = 0, trained: Bool = false, mySekaiCanvas: Bool = false) -> Power? {
        let isTrained = card.isInitiallySpecialTrained || (card.canTrain && trained)
        let maximum = isTrained ? (trainedMaxLevel ?? normalMaxLevel) : normalMaxLevel
        guard (1...maximum).contains(level), masterBonuses[masterRank] != nil,
              (0...episodeCount).contains(episodes),
              !mySekaiCanvas || mySekaiCanvasBonus != nil else { return nil }
        var values: [Card.ParameterType: Int] = [:]
        for type in Card.ParameterType.allCases {
            guard let base = card.cardParameters[type]?[level] else { return nil }
            values[type] = base + masterBonuses.filter { $0.key <= masterRank }.reduce(0) { $0 + ($1.value[type] ?? 0) }
                + episodeBonuses.prefix(episodes).reduce(0) { $0 + ($1[type] ?? 0) }
                + (isTrained ? (card.specialTrainingFixedBonus[type] ?? 0) : 0)
        }
        if mySekaiCanvas, let bonus = mySekaiCanvasBonus {
            values[.performance, default: 0] += bonus.performance
            values[.technique, default: 0] += bonus.technique
            values[.stamina, default: 0] += bonus.stamina
        }
        return Power(values)
    }
}
