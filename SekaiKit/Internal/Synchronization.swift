//===---*- Greatdori! -*---------------------------------------------------===//
//
// Synchronization.swift
//
// This source file is part of the Greatdori! open source project
//
// Copyright (c) 2025 the Greatdori! project authors
// Licensed under Apache License v2.0
//
// See https://greatdori.com/LICENSE.txt for license information
// See https://greatdori.com/CONTRIBUTORS.txt for the list of Greatdori! project authors
//
//===----------------------------------------------------------------------===//

import Foundation

internal struct Locking<Value>: @unchecked Sendable {
    internal let _value: __Reference<Value>
    fileprivate let handle = NSLock()
    
    internal init(_ initialValue: consuming sending Value) {
        self._value = .init(initialValue)
    }
    
    internal func withLock<Result, E: Error>(
        _ body: (inout sending Value) throws(E) -> sending Result
    ) throws(E) -> sending Result {
        handle.lock()
        defer {
            handle.unlock()
        }
        return try body(&_value.value)
    }
    
    internal func _lock() {
        handle.lock()
    }
    internal func _unlock() {
        handle.unlock()
    }
}
