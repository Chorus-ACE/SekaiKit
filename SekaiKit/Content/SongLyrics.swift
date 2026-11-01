import Foundation

extension Song {
    /// The complete published lyric document. Text languages are independent of game regions.
    public struct Lyrics: Decodable, Hashable, Sendable {
        public let version: Int
        public let songID: Int
        public let revision: Int
        public let updatedAt: String
        public let state: Availability?
        public let attribution: String?
        /// Legacy source fields are retained in addition to the normalized rendition.
        public let attributions: [Attribution]?
        public let originalLines: [Line]?
        public let availableVersions: [String]?
        public let translationCredits: TranslationCredits?
        public let gameProjection: GameProjection?
        public let renditions: [Rendition]
        public let defaultTranslationEditionKey: String?
        public let translationEditions: [TranslationEdition]

        public enum Length: String, CaseIterable, Hashable, Sendable {
            case full, game
            public var localizedName: String {
                switch self {
                case .full: String(localized: "Song.lyrics.full", bundle: .module)
                case .game: String(localized: "Song.lyrics.game", bundle: .module)
                }
            }
        }

        public enum Kind: Hashable, Sendable, Decodable {
            case original, sekai, vocaloid, alternate, unknown(String)
            public init(from decoder: Decoder) throws {
                let value = try decoder.singleValueContainer().decode(String.self)
                self = switch value {
                case "original": .original
                case "sekai": .sekai
                case "vocaloid": .vocaloid
                case "alternate": .alternate
                default: .unknown(value)
                }
            }
            public var localizedName: String {
                switch self {
                case .original: String(localized: "Song.lyrics.kind.original", bundle: .module)
                case .sekai: "SEKAI"
                case .vocaloid: "VOCALOID"
                case .alternate: String(localized: "Song.lyrics.kind.alternate", bundle: .module)
                case .unknown(let name): name
                }
            }
        }

        public enum Availability: Hashable, Sendable, Decodable {
            case complete, gameOnly, satisfiedNoLyrics, ambiguous, missing, incomplete, failed, unknown(String)
            public init(from decoder: Decoder) throws {
                let value = try decoder.singleValueContainer().decode(String.self)
                self = switch value {
                case "complete": .complete
                case "game_only": .gameOnly
                case "satisfied_no_lyrics": .satisfiedNoLyrics
                case "ambiguous": .ambiguous
                case "missing": .missing
                case "incomplete": .incomplete
                case "failed": .failed
                default: .unknown(value)
                }
            }
        }

        public struct PerformerID: Decodable, Hashable, Sendable {
            public let value: String
            public init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let text = try? container.decode(String.self) { value = text }
                else { value = String(try container.decode(Int.self)) }
            }
        }

        public struct Ruby: Decodable, Hashable, Sendable {
            public let text: String
            public let reading: String?
        }

        /// Source-provided performer/text spans; these are not inferred linguistic tokens.
        public struct Segment: Decodable, Hashable, Sendable {
            public let text: String
            public let performerIDs: [PerformerID]
            public let ruby: [Ruby]?
            private enum CodingKeys: String, CodingKey {
                case text, ruby
                case performerIDs = "performerIds"
            }
        }

        public struct Line: Decodable, Hashable, Identifiable, Sendable {
            public let id: String
            public let order: Int
            public let japanese: String
            public var chinese: String?
            public let english: String?
            public let stanzaBreakBefore: Bool?
            public let segments: [Segment]
            public let trailingPerformerIDs: [PerformerID]?
            private enum CodingKeys: String, CodingKey {
                case id, order, japanese, stanzaBreakBefore, segments
                case chinese = "zh-CN", english = "en-US"
                case trailingPerformerIDs = "trailingPerformerIds"
            }
        }

        public struct Attribution: Decodable, Hashable, Sendable {
            public let component: [Component]
            public let provider: Provider
            public let title: String
            public let revisionID: Int
            public let revisionURL: URL
            public let licenseName: String
            public let licenseURL: URL

            private enum CodingKeys: String, CodingKey {
                case component, provider, title, licenseName
                case revisionID = "revisionId", revisionURL = "revisionUrl", licenseURL = "licenseUrl"
            }

            /// Component paths are scoped to the containing rendition.
            public enum Component: Decodable, Hashable, Sendable {
                case fullText, gameText, fullPerformerSegmentation, gamePerformerSegmentation
                case fullRuby, gameRuby, relation, version, unknown(String)

                public init(from decoder: Decoder) throws {
                    let value = try decoder.singleValueContainer().decode(String.self)
                    let path = value.split(separator: "/", omittingEmptySubsequences: false)
                    let name = path.count == 3 && path[0] == "renditions" && !path[1].isEmpty
                        ? String(path[2]) : value
                    self = switch name {
                    case "full_text": .fullText
                    case "game_text": .gameText
                    case "full_performer_segmentation": .fullPerformerSegmentation
                    case "game_performer_segmentation": .gamePerformerSegmentation
                    case "full_ruby": .fullRuby
                    case "game_ruby": .gameRuby
                    case "relation": .relation
                    case "version": .version
                    default: .unknown(value)
                    }
                }

                public var localizedName: String {
                    switch self {
                    case .fullText: String(localized: "Song.lyrics.sources.full-text", bundle: .module)
                    case .gameText: String(localized: "Song.lyrics.sources.game-text", bundle: .module)
                    case .fullPerformerSegmentation: String(localized: "Song.lyrics.sources.full-segments", bundle: .module)
                    case .gamePerformerSegmentation: String(localized: "Song.lyrics.sources.game-segments", bundle: .module)
                    case .fullRuby: String(localized: "Song.lyrics.sources.full-readings", bundle: .module)
                    case .gameRuby: String(localized: "Song.lyrics.sources.game-readings", bundle: .module)
                    case .relation: String(localized: "Song.lyrics.sources.projection", bundle: .module)
                    case .version: String(localized: "Song.lyrics.sources.version", bundle: .module)
                    case .unknown(let value): value
                    }
                }
            }

            /// Merge only identical source revisions and licenses, preserving first-seen order.
            fileprivate static func merging(_ records: [Self]) -> [Self] {
                var result: [Self] = []
                var positions: [Self: Int] = [:]
                for record in records {
                    let source = record.replacingComponents([])
                    if let index = positions[source] {
                        var seen = Set(result[index].component)
                        let components = result[index].component + record.component.filter { seen.insert($0).inserted }
                        result[index] = source.replacingComponents(components)
                    } else {
                        positions[source] = result.count
                        var seen = Set<Component>()
                        result.append(record.replacingComponents(record.component.filter { seen.insert($0).inserted }))
                    }
                }
                return result
            }

            private func replacingComponents(_ components: [Component]) -> Self {
                Self(component: components, provider: provider, title: title, revisionID: revisionID,
                     revisionURL: revisionURL, licenseName: licenseName, licenseURL: licenseURL)
            }

            public enum Provider: Decodable, Hashable, Sendable {
                case vocaloidFandom, moegirl, moegirlPublicExact, sekaipedia, unknown(String)
                public init(from decoder: Decoder) throws {
                    let value = try decoder.singleValueContainer().decode(String.self)
                    self = switch value {
                    case "vocaloid_fandom": .vocaloidFandom
                    case "moegirl": .moegirl
                    case "moegirl_public_exact": .moegirlPublicExact
                    case "sekaipedia": .sekaipedia
                    default: .unknown(value)
                    }
                }
                public var localizedName: String {
                    switch self {
                    case .vocaloidFandom: "Vocaloid Lyrics Wiki"
                    case .moegirl, .moegirlPublicExact: "萌娘百科"
                    case .sekaipedia: "Sekaipedia"
                    case .unknown(let name): name
                    }
                }
            }
        }

        public struct TranslationCredits: Decodable, Hashable, Sendable {
            public let translation: String?
            public let proofreading: String?
        }

        public struct Performer: Decodable, Hashable, Identifiable, Sendable {
            public var id: String { performerID }
            public let performerID: String
            public let name: String
            public let color: String?
            private enum CodingKeys: String, CodingKey { case performerID = "performerId", name, color }
        }

        public struct RenditionVersion: Decodable, Hashable, Sendable {
            public let kind: Kind
            public let label: String
        }

        public struct Side: Decodable, Hashable, Sendable {
            public let version: RenditionVersion
            public let lines: [Line]
        }

        public struct Relation: Decodable, Hashable, Sendable {
            public let kind: Kind
            public let fullRenditionKey: String?
            public let lineIDs: [String]?
            private enum CodingKeys: String, CodingKey { case kind, fullRenditionKey, lineIDs = "lineIds" }
            public enum Kind: Decodable, Hashable, Sendable {
                case none, exactProjection, unknown(String)
                public init(from decoder: Decoder) throws {
                    let value = try decoder.singleValueContainer().decode(String.self)
                    self = switch value {
                    case "none": .none
                    case "exact_projection": .exactProjection
                    default: .unknown(value)
                    }
                }
            }
        }

        public struct Rendition: Decodable, Hashable, Identifiable, Sendable {
            public var id: String { key }
            public let key: String
            public let kind: Kind
            public let label: String
            public let availableVersions: [String]
            public let performers: [Performer]
            public let full: Side?
            public let game: Side?
            public let relation: Relation
            public let sourceTabPaths: [[String]]
            public let provenance: [Attribution]
            public let translationCredits: TranslationCredits?

            public var lengths: [Length] { availableVersions.compactMap(Length.init(rawValue:)) }
            public func lines(for length: Length) -> [Line] {
                switch length { case .full: full?.lines ?? []; case .game: game?.lines ?? [] }
            }

            private enum CodingKeys: String, CodingKey {
                case key, kind, label, availableVersions, performers, full, game, relation
                case sourceTabPaths, provenance, translationCredits
            }
        }

        public struct TranslationEdition: Decodable, Hashable, Identifiable, Sendable {
            public var id: String { key }
            public let key: String
            public let label: String
            public let renditions: [TranslationRendition]
        }

        public struct TranslationRendition: Decodable, Hashable, Sendable {
            public let renditionKey: String
            public let translationCredits: TranslationCredits?
            public let full: TranslationSide?
            public let game: TranslationSide?
        }

        public struct TranslationSide: Decodable, Hashable, Sendable {
            public let translations: [String]
        }

        /// V4 editions are Chinese only in the upstream contract; never treat them as English.
        public func lines(for rendition: Rendition, length: Length, editionKey: String? = nil) -> [Line] {
            var lines = rendition.lines(for: length)
            guard version == 4,
                  let edition = selectedEdition(key: editionKey),
                  let translation = edition.renditions.first(where: { $0.renditionKey == rendition.key }) else { return lines }
            let translations: [String]?
            if length == .game, rendition.relation.kind == .exactProjection {
                let fullLines = rendition.full?.lines ?? []
                let values = translation.full?.translations ?? []
                let byID = Dictionary(zip(fullLines, values).map { ($0.id, $1) }, uniquingKeysWith: { first, _ in first })
                translations = rendition.relation.lineIDs?.map { byID[$0] ?? "" }
            } else {
                translations = length == .full ? translation.full?.translations : translation.game?.translations
            }
            guard let translations, translations.count == lines.count else { return lines }
            for index in lines.indices { lines[index].chinese = translations[index] }
            return lines
        }

        public func credits(for rendition: Rendition, editionKey: String? = nil) -> TranslationCredits? {
            if version == 4 {
                return selectedEdition(key: editionKey)?
                    .renditions.first { $0.renditionKey == rendition.key }?.translationCredits
            }
            return rendition.translationCredits
        }

        private func selectedEdition(key: String?) -> TranslationEdition? {
            translationEditions.first { $0.key == key }
                ?? translationEditions.first { $0.key == defaultTranslationEditionKey }
        }

        private enum CodingKeys: String, CodingKey {
            case version, revision, updatedAt, state, attribution, attributions, renditions
            case defaultTranslationEditionKey, translationEditions, lines, availableVersions, translationCredits, gameProjection
            case songID = "musicId"
        }
        public struct GameProjection: Decodable, Hashable, Sendable {
            public let reasonCode: String?
            public let lineIDs: [String]
            private enum CodingKeys: String, CodingKey { case reasonCode, lineIDs = "lineIds" }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            version = try container.decode(Int.self, forKey: .version)
            guard (1...4).contains(version) else {
                throw DecodingError.dataCorruptedError(forKey: .version, in: container, debugDescription: "Unsupported lyrics schema")
            }
            songID = try container.decode(Int.self, forKey: .songID)
            revision = try container.decode(Int.self, forKey: .revision)
            updatedAt = try container.decode(String.self, forKey: .updatedAt)
            state = try container.decodeIfPresent(Availability.self, forKey: .state)
            attribution = try container.decodeIfPresent(String.self, forKey: .attribution)
            attributions = try container.decodeIfPresent([Attribution].self, forKey: .attributions).map(Attribution.merging)
            originalLines = try container.decodeIfPresent([Line].self, forKey: .lines)
            availableVersions = try container.decodeIfPresent([String].self, forKey: .availableVersions)
            translationCredits = try container.decodeIfPresent(TranslationCredits.self, forKey: .translationCredits)
            gameProjection = try container.decodeIfPresent(GameProjection.self, forKey: .gameProjection)
            defaultTranslationEditionKey = try container.decodeIfPresent(String.self, forKey: .defaultTranslationEditionKey)
            translationEditions = try container.decodeIfPresent([TranslationEdition].self, forKey: .translationEditions) ?? []
            if version >= 3 {
                renditions = try container.decode([Rendition].self, forKey: .renditions)
            } else {
                let lines = try container.decode([Line].self, forKey: .lines)
                let lengths = availableVersions ?? ["full"]
                let projection = gameProjection
                guard Set(lines.map(\.id)).count == lines.count,
                      projection?.lineIDs.allSatisfy({ id in lines.contains { $0.id == id } }) ?? true else {
                    throw DecodingError.dataCorruptedError(forKey: .lines, in: container, debugDescription: "Invalid lyric line IDs or projection")
                }
                let full = lengths.contains("full") ? Side(version: .init(kind: .original, label: "Full"), lines: lines) : nil
                let byID = Dictionary(lines.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                let gameLines = projection?.lineIDs.compactMap { byID[$0] } ?? lines
                let game = lengths.contains("game") ? Side(version: .init(kind: .original, label: "Game"), lines: gameLines) : nil
                renditions = [Rendition(key: "default", kind: .original, label: "", availableVersions: lengths,
                                       performers: [], full: full, game: game,
                                       relation: Relation(kind: .none, fullRenditionKey: nil, lineIDs: projection?.lineIDs), sourceTabPaths: [],
                                       provenance: attributions ?? [], translationCredits: translationCredits)]
            }
            guard songID > 0, revision > 0, !renditions.isEmpty,
                  Set(renditions.map(\.key)).count == renditions.count,
                  renditions.allSatisfy({ rendition in
                      !rendition.lengths.isEmpty && rendition.lengths.allSatisfy { length in
                          let lines = rendition.lines(for: length)
                          return !lines.isEmpty && Set(lines.map(\.id)).count == lines.count
                      }
                  }) else {
                throw DecodingError.dataCorruptedError(forKey: .renditions, in: container, debugDescription: "Invalid lyrics renditions")
            }
        }
    }

    /// Returns nil only when the repository has no lyrics for this song.
    public func lyrics() async throws -> Lyrics? { try await SekaiLyrics.lyrics(forSongID: id) }
}

extension Song.Lyrics.Attribution {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if try !container.contains(.component) || container.decodeNil(forKey: .component) {
            component = []
        } else if let components = try? container.decode([Component].self, forKey: .component) {
            component = components
        } else {
            component = [try container.decode(Component.self, forKey: .component)]
        }
        provider = try container.decode(Provider.self, forKey: .provider)
        title = try container.decode(String.self, forKey: .title)
        revisionID = try container.decode(Int.self, forKey: .revisionID)
        revisionURL = try container.decode(URL.self, forKey: .revisionURL)
        licenseName = try container.decode(String.self, forKey: .licenseName)
        licenseURL = try container.decode(URL.self, forKey: .licenseURL)
    }
}

extension Song.Lyrics.Rendition {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        kind = try container.decode(Song.Lyrics.Kind.self, forKey: .kind)
        label = try container.decode(String.self, forKey: .label)
        availableVersions = try container.decode([String].self, forKey: .availableVersions)
        performers = try container.decode([Song.Lyrics.Performer].self, forKey: .performers)
        full = try container.decodeIfPresent(Song.Lyrics.Side.self, forKey: .full)
        game = try container.decodeIfPresent(Song.Lyrics.Side.self, forKey: .game)
        relation = try container.decode(Song.Lyrics.Relation.self, forKey: .relation)
        sourceTabPaths = try container.decode([[String]].self, forKey: .sourceTabPaths)
        provenance = Song.Lyrics.Attribution.merging(try container.decode([Song.Lyrics.Attribution].self, forKey: .provenance))
        translationCredits = try container.decodeIfPresent(Song.Lyrics.TranslationCredits.self, forKey: .translationCredits)
    }
}
