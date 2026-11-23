//
//  ExtendedEvent.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/8/8.
//

import Foundation

/// An event together with its associated card and song identifiers.
public struct ExtendedEvent: SekaiCachable, GettableByID, Hashable, Codable, Sendable, Identifiable {
    /// The unique identifier of the event.
    public let id: Int
    /// The base event information.
    public let event: Event
    /// The associated card identifiers from Japanese event data, or `nil` if unavailable or empty.
    public let cards: [Int]?
    /// The associated song identifiers from Japanese event data, or `nil` if unavailable or empty.
    public let songs: [Int]?

    /// Finds events whose regional event-card associations include the card.
    /// Returns nil if the event archive cannot be loaded.
    public static func events(containingCardID cardID: Int) async -> [Event]? {
        await events(containing: cardID, in: \.cardIds)
    }

    /// Finds events whose regional event-song associations include the song.
    /// Returns nil if the event archive cannot be loaded.
    public static func events(containingSongID songID: Int) async -> [Event]? {
        await events(containing: songID, in: \.musicIds)
    }

    private static func events(containing id: Int, in association: KeyPath<_Event, [Int32]>) async -> [Event]? {
        guard let id = Int32(exactly: id) else { return [] }
        async let archive = requestProtobuf("event.aar", as: _EventList.self)
        async let events = Event.allWithCache()
        guard let archive = await archive, let events = await events else { return nil }
        let ids = Set(SekaiLocale.allCases.flatMap { locale in
            archive.items(in: locale).filter { $0[keyPath: association].contains(id) }.map { Int($0.id) }
        })
        return events.filter { ids.contains($0.id) }
    }
    
    /// Loads an event and its related card and song identifiers.
    ///
    /// The initializer fails if the base event cannot be loaded. Missing associations
    /// do not prevent initialization.
    ///
    /// - Parameter id: The event identifier.
    public init?(id: Int) async {
        async let event = Event(id: id)
        async let list = requestProtobuf("event.aar", as: _EventList.self)
        guard let event = await event else { return nil }
        let associations = await list?.jp.first { $0.id == id }
        self.id = id
        self.event = event
        self.cards = associations.flatMap { $0.cardIds.isEmpty ? nil : $0.cardIds.map(Int.init) }
        self.songs = associations.flatMap { $0.musicIds.isEmpty ? nil : $0.musicIds.map(Int.init) }
    }
}
