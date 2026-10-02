//
//  Filter.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/8/2.
//

import Foundation

/// A collection of selected option identifiers used to filter game records.
public struct SekaiFilter: Hashable, Codable, Equatable {
    /// The selected option identifiers keyed by filter identifier.
    ///
    /// A `nil` option identifier represents the “other” option.
    public var configuration: [String: Set<Int?>] = [:]
//    public var matchingMethod
    
    /// Creates a filter from explicit selections.
    ///
    /// - Parameter configuration: Selected option identifiers keyed by filter identifier.
    public init(_ configuration: [String : Set<Int?>]) {
        self.configuration = configuration
    }
    
    /// Creates a filter with the default selections for each key.
    ///
    /// - Parameter keys: The filter keys whose defaults should be selected.
    public init(forKeys keys: [Self.Key]) {
        var configuration: [String: Set<Int?>] = [:]
        for key in keys {
            configuration[key.id] = Set(key.defaultOptionsID)
        }
        
        self.configuration = configuration
    }
    
//    public var identity: String {
//        "\(self)"
//    }
    
    /// Returns whether the selections differ from the supplied defaults.
    ///
    /// - Parameter reference: The keys providing default selections, or `nil` to check whether the configuration is nonempty.
    /// - Returns: `true` if any configured selection differs from its default, including an unknown key.
    public func isFiltering(referencing reference: [Self.Key]? = nil) -> Bool {
        guard let reference else {
            return !configuration.isEmpty
        }

        let defaultsByKey = Dictionary(
            uniqueKeysWithValues: reference.map { ($0.id, $0.defaultOptionsID) }
        )
        return configuration.contains { key, value in
            defaultsByKey[key] != value
        }
    }
    
    /// Accesses selected option identifiers using a filter identifier.
    ///
    /// - Parameter index: The filter identifier.
    /// - Returns: The selected option identifiers, or `nil` if no selection is configured.
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
    
    /// Returns selected option identifiers for a filter key.
    ///
    /// - Parameter index: The filter key.
    /// - Returns: The selected option identifiers, or `nil` if no selection is configured.
    public subscript (index: SekaiFilter.Key) -> Set<Int?>? {
        self[index.id]
    }
    
    /// A filter category, its selectable options, and its default selections.
    public struct Key: Hashable, Codable, Identifiable, Sendable {
        /// The stable identifier used to store selections for this filter key.
        public let id: String
        /// The display title of the filter key.
        public let title: String
        
        /// A Boolean value indicating whether multiple options can be selected.
        public private(set) var allowMultipleSelection: Bool
        /// The options available for selection.
        public private(set) var options: [Option]
        private var _defaultOptions: [Option]?
        
        /// The explicit defaults, or all options for multiple selection and the first option for single selection.
        public var defaultOptions: [Option] {
            if let _defaultOptions {
                return _defaultOptions
            } else if allowMultipleSelection {
                return self.options
            } else if let first = self.options.first {
                return [first]
            } else {
                return []
            }
        }
        
        /// The identifiers of the default options.
        public var defaultOptionsID: Set<Int?> {
            Set(self.defaultOptions.map(\.id))
        }
        
        /// The identifiers of all options, in display order.
        public var allOptionsID: [Int?] {
            self.options.map(\.id)
        }
        
        /// Creates a filter key and its selectable options.
        ///
        /// - Parameters:
        ///   - id: The stable filter identifier.
        ///   - title: The display title, or `nil` to load the localized title for `id`.
        ///   - allowMultipleSelection: Whether multiple options may be selected.
        ///   - options: The options in display order.
        ///   - defaultOptions: Explicit defaults, or `nil` to derive them from the selection mode.
        public init(id: String, title: String? = nil, allowMultipleSelection: Bool = true, options: [Option], defaultOptions: [Option]? = nil
        ) {
            self.id = id
            self.title = title ?? NSLocalizedString("Filter.key.\(id)", bundle: #bundle, comment: "")
            self.allowMultipleSelection = allowMultipleSelection
            self.options = options
            self._defaultOptions = defaultOptions
        }
        
        /// An individual option displayed in a filter selector.
        public struct Option: Hashable, Codable, Identifiable, Sendable {
            /// The option identifier, or `nil` for the “other” option.
            public var id: Int?
            /// The option’s display name.
            public var selectorName: String
            /// The option’s image URL, if available.
            public var selectorImage: URL?
            
            /// The standard option for values outside the named categories.
            public static let other = Self.init(id: nil, selectorName: NSLocalizedString("Filter.option.other", bundle: #bundle, comment: ""), selectorImage: nil)
            
            init(id: Int?, selectorName: String, selectorImage: URL? = nil) {
                self.id = id
                self.selectorName = selectorName
                self.selectorImage = selectorImage
            }
        }
        
        /// A copy of the key with the “other” option appended if it is not already present.
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

/// A type that supplies filter options and evaluates whether a record matches them.
public protocol SekaiFilterable {
    /// The filter keys applicable to this type.
    static var filterKeys: [SekaiFilter.Key] { get }
    
    /// Evaluates a filter against this record.
    ///
    /// - Parameter filter: The selections to evaluate.
    /// - Returns: `true` if the record satisfies the filter.
    func _matches(_ filter: SekaiFilter) -> Bool
}

extension Array where Element: SekaiFilterable {
    /// Returns the elements that satisfy a SekaiKit filter.
    ///
    /// - Parameter filter: The filter selections to apply.
    /// - Returns: The matching elements in their original order.
    public func filter(withSekaiFilter filter: SekaiFilter) -> [Element] {
        guard filter.isFiltering(referencing: Element.filterKeys) else { return self }
        return self.filter { $0._matches(filter) }
    }
    
    mutating func filter(withSekaiFilter filter: SekaiFilter) {
        self = self.filter(withSekaiFilter: filter)
    }
}
