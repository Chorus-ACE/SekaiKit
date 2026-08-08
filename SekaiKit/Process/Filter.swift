//
//  Filter.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/8/2.
//

import Foundation

public struct SekaiFilter: Hashable, Codable, Equatable {
    public var configuration: [String: Set<Int?>] = [:]
//    public var matchingMethod
    
    public init(_ configuration: [String : Set<Int?>]) {
        self.configuration = configuration
    }
    
    public init(forKeys keys: [Self.Key]) {
        var configuration: [String: Set<Int?>] = [:]
        for key in keys {
            configuration[key.id] = Set(key.defaultValue.map(\.id))
        }
        
        self.configuration = configuration
    }
    
//    public var identity: String {
//        "\(self)"
//    }
    
    public func isFiltering(referencing reference: [Self.Key]? = nil) -> Bool {
        for (key, value) in configuration {
//            if value.isEmpty {
//                continue
            if let reference, let defaultOptions = (reference.first(where: { $0.id == key })?.defaultValue.map(\.id)), value == Set(defaultOptions) {
                continue
            }
            return true
        }
        return false
    }
    
    public subscript (index: String) -> Set<Int?>? {
        get {
            return self.configuration[index]
        }
        set(newValue) {
            if let newValue {
                configuration[index] = newValue
            } else {
                configuration.removeValue(forKey: index)
            }
        }
    }
    
    public struct Key: Hashable, Codable, Identifiable, Sendable {
        public let id: String
        public let title: String
        
        public private(set) var allowMultipleSelection: Bool
        public private(set) var options: [Option]
        private var _defaultValue: [Option]?
        
        public var defaultValue: [Option] {
            if let _defaultValue {
                return _defaultValue
            } else if allowMultipleSelection {
                return self.options
            } else if let first = self.options.first {
                return [first]
            } else {
                return []
            }
        }
        
        public var allOptionsID: [Int?] {
            self.options.map(\.id)
        }
        
        public init(id: String, title: String? = nil, allowMultipleSelection: Bool = true, options: [Option], defaultOptions: [Option]? = nil
        ) {
            self.id = id
            self.title = title ?? NSLocalizedString("Filter.key.\(id)", bundle: #bundle, comment: "")
            self.allowMultipleSelection = allowMultipleSelection
            self.options = options
            self._defaultValue = defaultOptions
        }
        
        public struct Option: Hashable, Codable, Identifiable, Sendable {
            public var id: Int?
            public var selectorName: String
            public var selectorImage: URL?
            
            public static let other = Self.init(id: nil, selectorName: NSLocalizedString("Filter.option.other", bundle: #bundle, comment: ""), selectorImage: nil)
            
            init(id: Int?, selectorName: String, selectorImage: URL? = nil) {
                self.id = id
                self.selectorName = selectorName
                self.selectorImage = selectorImage
            }
        }
        
        public var withOtherOption: Self {
            var mutatingSelf = self
            if !self.allOptionsID.contains(nil) {
                mutatingSelf.options.append(Option.other)
            }
            return mutatingSelf
        }
    }
}

extension SekaiFilter {
    internal func permits(_ value: Int?, inKey key: String) -> Bool {
        if let allowlist = self[key], !allowlist.contains(value) {
            return false
        }
        return true
    }
    
    internal func permits<T: SekaiFilterElementProtocol>(_ item: T?) -> Bool {
        self.permits(item?.filterValue, inKey: T.filterKey.id)
    }
}


public protocol SekaiFilterable {
    static var filterKeys: [SekaiFilter.Key] { get }
    
    func _matches(_ filter: SekaiFilter) -> Bool
}

extension Array where Element: SekaiFilterable {
    public func filter(withSekaiFilter filter: SekaiFilter) -> [Element] {
        guard filter.isFiltering(referencing: Element.filterKeys) else { return self }
        return self.filter { $0._matches(filter) }
    }
    
    mutating func filter(withSekaiFilter filter: SekaiFilter) {
        self = self.filter(withSekaiFilter: filter)
    }
}
