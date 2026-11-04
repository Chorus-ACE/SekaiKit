import Foundation
import MCP
import SekaiKit

/// The master-data collections exposed by the MCP server.
public enum SekaiMCPCollection: String, CaseIterable, Sendable {
    case characters, cards, events, gachas, songs, stickers, comics, fixtures
}

/// A searchable summary and the complete Codable representation of a SekaiKit model.
public struct SekaiMCPRecord: Sendable {
    public let id: Int
    public let name: String?
    public let data: Value

    public init(id: Int, name: String?, data: Value) {
        self.id = id
        self.name = name
        self.data = data
    }
}

/// Loads one region at a time. Missing translations never fall back to another region.
public enum SekaiMCPDataSource {
    public static func load(_ collection: SekaiMCPCollection, locale: SekaiLocale) async throws -> [SekaiMCPRecord] {
        switch collection {
        case .characters:
            return try await records(Character.self, locale: locale) {
                let names = [value($0.familyName, locale), value($0.givenName, locale)].compactMap { $0 }
                return names.isEmpty ? nil : names.joined(separator: " ")
            }
        case .cards: return try await records(Card.self, locale: locale) { value($0.name, locale) }
        case .events: return try await records(Event.self, locale: locale) { value($0.title, locale) }
        case .gachas: return try await records(Gacha.self, locale: locale) { value($0.title, locale) }
        case .songs: return try await records(Song.self, locale: locale) { value($0.title, locale) }
        case .stickers: return try await records(Sticker.self, locale: locale) { value($0.title, locale) }
        case .comics: return try await records(Comic.self, locale: locale) { value($0.title, locale) }
        case .fixtures: return try await records(MySekaiFixture.self, locale: locale) { value($0.title, locale) }
        }
    }

    private static func value(_ data: LocalizableData<String>, _ locale: SekaiLocale) -> String? {
        switch data {
        case .localized(let localized): return localized[locale]
        case .unlocalized(let value): return value
        }
    }

    private static func records<T: ListGettable & Encodable>(
        _ type: T.Type, locale: SekaiLocale, name: (T) -> String?
    ) async throws -> [SekaiMCPRecord] where T.ID == Int {
        guard let models = await T.allInLocale(locale) else {
            throw MCPError.internalError("Could not load \(T.self) for \(locale.rawValue). Check the archive source and retry.")
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.ISO8601Format(.init(includingFractionalSeconds: true)))
        }
        let decoder = JSONDecoder()
        return try models.map {
            SekaiMCPRecord(id: $0.id, name: name($0), data: try decoder.decode(Value.self, from: encoder.encode($0)))
        }
    }
}
