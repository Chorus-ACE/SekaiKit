//
//  PagedContent.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/1/16.
//

import Foundation

/// A type that stores contents which can be separated into multiple pages.
public protocol PagedContent {
    associatedtype Content
    
    var total: Int { get }
    var currentOffset: Int { get }
    var content: [Content] { get }
}

extension PagedContent {
    @inlinable
    public var pageCapacity: Int {
        content.count
    }
    @inlinable
    public var hasMore: Bool {
        currentOffset + pageCapacity < total
    }
    @inlinable
    public var nextOffset: Int {
        currentOffset + pageCapacity
    }
    @inlinable
    public var pageCount: Int {
        Int(ceil(Double(total) / Double(pageCapacity)))
    }
    @inlinable
    public var currentPage: Int {
        currentOffset / pageCount + 1
    }
}
