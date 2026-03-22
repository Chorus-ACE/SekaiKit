//
//  StringHandling.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/2/1.
//

import Foundation
import SwiftUI
internal import SwiftyJSON


internal let dateOfYear2100: Date = .init(timeIntervalSince1970: 4107477600)

internal extension Array {
    subscript(access index: Int) -> Element? {
        get {
            if index < self.count && index >= 0 {
                return self[index]
            } else {
                return nil
            }
        }
    }
}

internal extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        let cleanedHex = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        
        guard cleanedHex.count == 6 else { return nil }
        
        var rgbValue: UInt64 = 0
        unsafe Scanner(string: cleanedHex).scanHexInt64(&rgbValue)
        
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255
        let b = Double(rgbValue & 0x0000FF) / 255
        
        self.init(.sRGB, red: r, green: g, blue: b)
    }
}

internal extension Dictionary {
    // - `modifying` creates a default key-value pair if necessary to ensure no Optional value. If able, the default value will be `[:]`.
    subscript(modifying key: Key, defaultAs defaultValue: Value) -> Value {
        mutating get {
            if self[key] == nil {
                self.updateValue(defaultValue, forKey: key)
            }
            return self[key]!
        }
        set {
            self.updateValue(newValue, forKey: key)
        }
    }
    
    // - `accessing` do not require a default value, and may return `nil`.
    // - Updating a nested dictionary: `dict[modifying: a][modifying: b][accessing: c] = d`
    subscript(accessing key: Key) -> Value? {
        get {
            return self[key]
        } set {
            if let newValue {
                self.updateValue(newValue, forKey: key)
            } else {
                self.removeValue(forKey: key)
            }
        }
    }
}

internal extension Dictionary where Value: ExpressibleByDictionaryLiteral {
    subscript(modifying key: Key) -> Value {
        mutating get {
            if self[key] == nil {
                self[key] = [:] as! Value
            }
            return self[key]!
        }
        set {
            self[key] = newValue
        }
    }
}

internal extension Duration {
    @usableFromInline
    static func &+ (lhs: Self, rhs: Self) -> Self {
        let low = lhs._low &+ rhs._low
        let carry: Int64 = low < lhs._low ? 1 : 0
        let high = lhs._high &+ rhs._high &+ carry
        return .init(_high: high, low: low)
    }
    
    @usableFromInline
    static func &* (lhs: Self, rhs: Self) -> Self {
        let p0 = lhs._low.multipliedFullWidth(by: rhs._low)
        let p1 = UInt64(bitPattern: lhs._high) &* rhs._low
        let p2 = lhs._low &* UInt64(bitPattern: rhs._high)
        return .init(_high: Int64(bitPattern: p0.high &+ p1 &+ p2), low: p0.low)
    }
    
    @usableFromInline
    static func &* (lhs: Self, rhs: Int) -> Self {
        return lhs &* Duration(
            _high: rhs < 0 ? -1 : 0,
            low: .init(bitPattern: Int64(rhs))
        )
    }
}

internal extension Equatable {
    /// Returns `nil` if `self` is equal to the given `keyword`; otherwise returns `self`.
    ///
    /// This is useful when you want to omit a value that matches a sentinel/default.
    ///
    /// - Parameter keyword: The value to compare against.
    /// - Returns: `nil` when equal; otherwise `self`.
    func nilIfEqual(to keyword: Self) -> Self? {
        self == keyword ? nil : self
    }
}

internal extension Date {
    internal func ignoreAfter2090() -> Date? {
        if self.timeIntervalSince1970 >= 3786879600 {
            return nil
        } else {
            return self
        }
    }
}

internal extension JSON {
    var date: Date? {
        get {
            if let int = self.int {
                return Date(timeIntervalSince1970: TimeInterval(int/1000))
            } else {
                return nil
            }
        }
        set {
            if let newValue = newValue {
                object = newValue
            } else {
                object = NSNull()
            }
        }
    }
    
    var dateValue: Date {
        get {
            return Date(timeIntervalSince1970: TimeInterval(self.intValue/1000))
        }
        set {
            object = newValue
        }
    }
}
