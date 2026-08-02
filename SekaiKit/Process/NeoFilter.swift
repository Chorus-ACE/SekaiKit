//
//  NeoFilter.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/8/2.
//

import Foundation

public struct NeoSekaiFilter {
    public var configuration: [String: Set<Int>] = [:]
    
    public init(_ configuration: [String : Set<Int>]) {
        self.configuration = configuration
    }
    
    public func isFiltering(referencing reference: [Self.Key]? = nil) -> Bool {
        for (key, value) in configuration {
            if value.isEmpty {
                continue
            } else if let reference, let allCases = reference.first(where: { $0.id == key })?.allCasesID, Set(allCases) == value {
                continue
            }
            return true
        }
        return false
    }
    
    public subscript (index: String) -> Set<Int>? {
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
    
    public struct Key: Identifiable {
        public var id: String
        public var title: String
        
        public var allowMultipleSelection: Bool
        public var options: [Option]
        
        public var allCasesID: [Int] {
            self.options.map(\.id)
        }
        
        public init(id: String, title: String? = nil, allowMultipleSelection: Bool = true, options: [Option]) {
            self.id = id
            self.title = title ?? NSLocalizedString("Filter.key.\(id)", bundle: #bundle, comment: "")
            self.allowMultipleSelection = allowMultipleSelection
            self.options = options
        }
        
        public struct Option: Identifiable {
            public var id: Int
            public var selectorName: String
            public var selectorImage: URL?
        }
    }
}

extension NeoSekaiFilter {
    internal func contains(key: String, value: Int) -> Bool {
        if let allowlist = self[key], !allowlist.contains(value) {
            return false
        }
        return true
    }
    
    internal func contains<T: SekaiFilterElementProtocol>(_ item: T) -> Bool {
        self.contains(key: T.filterKey.id, value: item.filterValue)
    }
}


public protocol NeoSekaiFilterable {
    static var filterKeys: [NeoSekaiFilter.Key] { get }
    
    func _matches(_ filter: NeoSekaiFilter) -> Bool
}

extension Array where Element: NeoSekaiFilterable {
    public func filter(withSekaiFilter filter: NeoSekaiFilter) -> [Element] {
        guard filter.isFiltering(referencing: Element.filterKeys) else { return self }
        return self.filter { $0._matches(filter) }
    }
    
    mutating func filter(withSekaiFilter filter: NeoSekaiFilter) {
        self = self.filter(withSekaiFilter: filter)
    }
}
