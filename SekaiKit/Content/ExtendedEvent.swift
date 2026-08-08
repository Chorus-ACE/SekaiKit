//
//  ExtendedEvent.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/8/8.
//

import Foundation
import SwiftyJSON

public struct ExtendedEvent: SekaiCachable, GettableByID, Hashable, Codable, Sendable, Identifiable {
    public let id: Int
    public let event: Event
    public let cards: [Int]?
//    public let bonus: Event.Bonus?
    
    public init?(id: Int) async {
        let groupResult = await withTasksResult {
            await Event(id: id)
        } _: {
            await SekaiCache.withDirectCache(id: "AllEventCards") {
                await Self.allEventCards()
            }
//        } _: {
//            await SekaiCache.withDirectCache(id: "AllEventBonuses") {
//                await Event.Bonus.all()
//            }
        }
        
        guard let event = groupResult.0 else { return nil }
        guard let cards = groupResult.1 else { return nil }
//        guard let bonus = groupResult.2 else { return nil }
        
        self.id = id
        self.event = event
        self.cards = cards[id]
//        self.bonus = bonus.first(where: { $0.id == id })
    }
    
    
    private static func allEventCards() async -> [Int: [Int]]? {
        guard let json = await requestJSON("https://sekai-world.github.io/sekai-master-db-diff/eventCards.json") else { return nil }
        
        let task = Task {
            var cards: [Int: [Int]] = [:]
            
            for (_, value) in json {
                let eventID = value["eventId"].intValue
                let cardID = value["cardId"].intValue
                
                cards[eventID] = (cards[eventID] ?? []) + [cardID]
            }
            
            return cards
        }
        
        return await task.value
    }
}

//extension Event {
//    public struct Bonus: SekaiCachable, Hashable, Codable, Sendable, Identifiable {
//        public var id: Int
//        public var attribute: Card.Attribute?
//        public var attributeBonus: Int?
//        public var characters: [Int]
//        public var characterBonus: Int
//        
//        static func all() async -> [Self]? {
//            guard let json = await requestJSON("https://sekai-world.github.io/sekai-master-db-diff/eventDeckBonuses.json") else { return nil }
//            
//            let task = Task.detached(priority: .userInitiated) {
//                var charResult: [Int: [Int]] = [:]
//                var charPercentResult: [Int: Int] = [:]
//                var attrResult: [Int: Card.Attribute] = [:]
//                var attrPercentResult: [Int: Int] = [:]
//                
//                for (_, value) in json {
//                    let eventID = value["eventId"].intValue
//                    
//                    let char = value["gameCharacterUnitId"].int
//                    let attr = value["cardAttr"].string
//                    
//                    let percentage = value["bonusRate"].intValue
//                    
//                    if let char, attr == nil {
//                        charResult[eventID] = (charResult[eventID] ?? []) + [char]
//                        charPercentResult[eventID] = percentage
//                    } else if let attr, let castedAttr = Card.Attribute(rawValue: attr), char == nil {
//                        attrResult[eventID] = castedAttr
//                        attrPercentResult[eventID] = percentage
//                    }
//                }
//                
//                let bonuses: [Bonus] = charResult.compactMap { id, character in
//                    let charPercentage = charPercentResult[id]
//                    let attribute = attrResult[id]
//                    let attrPercentage = attrPercentResult[id]
//                    
//                    return .init(id: id,
//                                 attribute: attribute,
//                                 attributeBonus: attrPercentage,
//                                 characters: character,
//                                 characterBonus: charPercentage ?? 0)
//                }
//                
//                return bonuses
//            }
//            return await task.value
//        }
//    }
//}
