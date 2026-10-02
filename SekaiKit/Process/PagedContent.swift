//
//  PagedContent.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/1/16.
//

import Foundation

/// A type containing a page of records and its position in a larger result set.
public protocol PagedContent {
    /// The type of record stored on a page.
    associatedtype Content
    
    /// The total number of records across all pages.
    var total: Int { get }
    /// The zero-based offset of the current page in the complete result set.
    var currentOffset: Int { get }
    /// The records on the current page.
    var content: [Content] { get }
}

extension PagedContent {
    /// The number of records on the current page.
    @inlinable
    public var pageCapacity: Int {
        content.count
    }
    /// A Boolean value indicating whether records remain after the current page.
    @inlinable
    public var hasMore: Bool {
        currentOffset + pageCapacity < total
    }
    /// The offset immediately after the last record on the current page.
    @inlinable
    public var nextOffset: Int {
        currentOffset + pageCapacity
    }
    /// The total page count estimated using the current page’s record count.
    ///
    /// The current page must contain at least one record.
    @inlinable
    public var pageCount: Int {
        Int(ceil(Double(total) / Double(pageCapacity)))
    }
    /// The one-based position computed by dividing the current offset by the page count.
    ///
    /// The current page and the total result set must be nonempty.
    @inlinable
    public var currentPage: Int {
        currentOffset / pageCount + 1
    }
}
