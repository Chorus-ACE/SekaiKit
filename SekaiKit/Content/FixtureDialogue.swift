import Foundation

extension MySekaiFixture {
    /// A character's regional reaction to this furniture, joined through the fixture and tweet groups.
    public struct Dialogue: Hashable, Identifiable, Sendable {
        public var id: String { "\(characterUnitID)-\(reactionType)-\(tweetID)" }
        public var tweetID: Int
        public var characterUnitID: Int
        public var characterID: Int?
        public var unit: Unit?
        /// Kept as an upstream value so new reaction types remain readable.
        public var reactionType: String
        public var text: String
        public var motionName: String?
        public var expressionEyeName: String?
        public var expressionMouthName: String?
        public var emoticonName: String?
    }

    public func dialogues(in locale: SekaiLocale) async -> [Dialogue]? {
        guard let list = await requestProtobuf("fixture.aar", as: _FixtureList.self),
              let record = list.items(in: locale).first(where: { $0.id == id }),
              record.dialoguesIncluded else { return nil }
        return record.dialogues.map(Dialogue.init(protobuf:))
    }
}

extension MySekaiFixture.Dialogue {
    internal init(protobuf p: _FixtureDialogue) {
        tweetID = Int(p.id); characterUnitID = Int(p.gameCharacterUnitID)
        characterID = p.hasCharacterID ? Int(p.characterID) : nil
        unit = p.hasUnit ? Unit(rawValue: p.unit) : nil
        reactionType = p.reactionType; text = p.text
        motionName = p.hasMotionName ? p.motionName : nil
        expressionEyeName = p.hasExpressionEyeName ? p.expressionEyeName : nil
        expressionMouthName = p.hasExpressionMouthName ? p.expressionMouthName : nil
        emoticonName = p.hasEmoticonName ? p.emoticonName : nil
    }
}
