//
//  Filter.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/8/2.
//

import Foundation

public struct SekaiFilter: Hashable, Codable, Equatable {
    public var configuration: [String: Set<Int>] = [:]
    
    public init(_ configuration: [String : Set<Int>]) {
        self.configuration = configuration
    }
    
    public init(forKeys keys: [Self.Key]) {
        var configuration: [String: Set<Int>] = [:]
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
    
    public struct Key: Hashable, Codable, Identifiable {
        public let id: String
        public let title: String
        
        public let allowMultipleSelection: Bool
        public let options: [Option]
        private let _defaultValue: [Option]?
        
        public var defaultValue: [Option] {
            self._defaultValue ?? options
        }
        
        public var allCasesID: [Int] {
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
        
        public struct Option: Hashable, Codable, Identifiable {
            public var id: Int
            public var selectorName: String
            public var selectorImage: URL?
        }
    }
}

extension SekaiFilter {
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
