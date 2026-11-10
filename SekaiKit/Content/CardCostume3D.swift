import Foundation

/// A card's clothing design and its matching regional viewer selection.
public struct CardCostume3D: Identifiable, Sendable {
    public var id: String { variant.id }
    public let characterID: Int
    public let costume: Costume
    public let variant: CostumeVariant
    public let selection: Model3DSelection

    internal struct Relation: Decodable, Sendable {
        let cardID: Int
        let costumeID: Int

        enum CodingKeys: String, CodingKey {
            case cardID = "cardId", costumeID = "costume3dId"
        }
    }

    internal static func relations(in locale: SekaiLocale) async -> [Relation]? {
        guard let json = await requestJSON("https://raw.githubusercontent.com/Sekai-World/\(locale._databasePath)/main/cardCostume3ds.json"),
              let data = try? json.rawData() else { return nil }
        return try? JSONDecoder().decode([Relation].self, from: data)
    }

    internal static func costumeIDs(forCharacterID characterID: Int, cardCharacterIDs: [Int: Int], relations: [Relation]) -> Set<Int> {
        Set(relations.filter { cardCharacterIDs[$0.cardID] == characterID }.map(\.costumeID))
    }

    internal static func resolve(costumeIDs: Set<Int>, character: Model3DCharacter) -> [Self] {
        guard let defaults = character.defaultSelection() else { return [] }
        let hair = character.hairstyles.flatMap(\.variants).first { costumeIDs.contains($0.costumeID) }
        let accessory = character.accessories.flatMap(\.variants).first { costumeIDs.contains($0.costumeID) }
        return character.costumes.compactMap { costume in
            guard let variant = costume.variants.first(where: { costumeIDs.contains($0.costumeID) }) else { return nil }
            var selection = defaults
            selection.costumeID = variant.id
            if let hair { selection.hairstyleID = hair.id }
            if let accessory { selection.accessoryID = accessory.id }
            return .init(characterID: character.characterID, costume: costume, variant: variant, selection: selection)
        }
    }
}

extension Card {
    /// The costumes associated with this character's cards in one region.
    /// Other characters being able to wear them does not change their original card association.
    public static func costume3DIDs(forCharacterID characterID: Int, in locale: SekaiLocale = .primaryLocale) async -> Set<Int>? {
        async let cards = Card.allInLocale(locale)
        async let relations = CardCostume3D.relations(in: locale)
        guard let cards = await cards, let relations = await relations, !Task.isCancelled else { return nil }
        let owners = Dictionary(cards.map { ($0.id, $0.characterID) }, uniquingKeysWith: { first, _ in first })
        return CardCostume3D.costumeIDs(forCharacterID: characterID, cardCharacterIDs: owners, relations: relations)
    }

    /// Loads card-to-costume relations and a renderable wardrobe from the same region.
    /// An empty result means no matching clothing is available; `nil` indicates a loading failure.
    public func costumes3D(in locale: SekaiLocale = .primaryLocale) async -> [CardCostume3D]? {
        guard let rows = await CardCostume3D.relations(in: locale) else { return nil }
        let ids = Set(rows.filter { $0.cardID == id }.map(\.costumeID))
        guard !ids.isEmpty else { return [] }
        do {
            try Task.checkCancellation()
            let library = try await Model3DLocalClient.shared.library(for: locale)
            guard let role = library.roles.first(where: {
                $0.characterID == characterID && $0.unitID == (supportUnit ?? unit).rawValue
            }) else { return [] }
            let wardrobe = try await Model3DLocalClient.shared.wardrobe(for: role.id, in: library)
            try Task.checkCancellation()
            return CardCostume3D.resolve(costumeIDs: ids, character: wardrobe.character)
        } catch {
            return nil
        }
    }
}
