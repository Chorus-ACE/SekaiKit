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
