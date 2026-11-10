//===---*- Greatdori! -*---------------------------------------------------===//
//
// SekaiCache.swift
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

import SwiftUI
import Foundation

/// Manages disk caches and asynchronous loading for SekaiKit.
public final class SekaiCache {
    private init() {}
    
    @TaskLocal
    internal static var preferCachedNetworkSource: Bool = false
    
    /// A type that can be cached by SekaiKit.
    public protocol Cacheable: Codable {
        /// Decodes a value from cached property-list data.
        ///
        /// The initializer accepts direct values and wrapped scalar values, and returns
        /// `nil` if the data cannot be decoded.
        ///
        /// - Parameter cache: The cached bytes to decode.
        init?(fromCache cache: Data)
        
        /// The binary property-list representation of the value, wrapping scalar values when needed.
        var dataForCache: Data { get }
    }
    
    /// A handle for receiving cached and newly loaded values.
    ///
    /// Register an update closure immediately after obtaining the promise. Updates
    /// that occur before registration are not replayed. An initial value, when one
    /// was supplied, is delivered only if no update has occurred yet.
    ///
    /// - Important: Register one update closure per promise. A later registration
    ///   replaces the existing closure.
    public final class Promise<Result> {
        @safe nonisolated(unsafe)
        private var _onUpdate: ((Result, DataSource) -> Void)?
        @safe nonisolated(unsafe)
        private var initialValue: Result?
        @safe nonisolated(unsafe)
        private var isValueFirstUpdated: Bool = false
        @safe nonisolated(unsafe)
        private var isCancelled: Bool = false
        @safe nonisolated(unsafe)
        private var _onCancel: (() -> Void)?
        
        internal init(_ initialValue: Result? = nil) {
            self.initialValue = initialValue
        }
        
        /// The source of a value delivered by a cache promise.
        public enum DataSource {
            /// A value read from the disk cache.
            case cache
            /// A result returned by the loading operation.
            case origin
            /// An initial value supplied when the promise was created.
            case initial
        }
        
        @MainActor
        internal func updateValue(_ value: Result, from source: DataSource) {
            if _fastPath(!isCancelled) {
                _onUpdate?(value, source)
            }
            isValueFirstUpdated = true
        }
        @discardableResult
        internal func onCancel(perform action: @escaping () -> Void) -> Self {
            self._onCancel = action
            return self
        }
        
        /// Registers the closure that receives subsequent value updates.
        ///
        /// An initial value is delivered synchronously only if no update has occurred.
        /// Previously delivered updates are not replayed. Registering another closure
        /// replaces the existing closure.
        ///
        /// - Parameter action: The closure receiving a value and its source.
        /// - Returns: This promise, allowing chained calls.
        @discardableResult
        public func onUpdate(_ action: @escaping (Result, DataSource) -> Void) -> Self {
            self._onUpdate = action
            if !isValueFirstUpdated, let initialValue {
                action(initialValue, .initial)
            }
            return self
        }
        
        /// Cancels future update delivery and requests cancellation of the loading task.
        ///
        /// Cancellation is cooperative, and a cancelled promise cannot be reactivated.
        public func cancel() {
            self._onCancel?()
            self.isCancelled = true
        }
    }
    
    /// A policy controlling whether a loading operation can be skipped in favor of cached data.
    public enum CacheTrait: Sendable {
        /// Requests a new value even when a disk cache is available.
        case realTime
        /// Allows a sufficiently recent cached value to skip the loading operation.
        ///
        /// The current freshness interval is 24 hours.
        case invocationElidable
    }
    
    @TaskLocal
    internal static var cacheDirectory = URL(filePath: NSHomeDirectory() + "/Library/Caches")

    // Serialize cache and metadata writes so concurrent loads do not lose timestamps.
    private actor DiskStorage {
        static let shared = DiskStorage()

        struct Entry<Value: Sendable>: Sendable {
            var value: Value
            var updated: TimeInterval?

            var isFresh: Bool {
                guard let updated else { return false }
                let age = Date.now.timeIntervalSince1970 - updated
                return age >= 0 && age < 24 * 60 * 60
            }
        }

        func read<Value: Sendable & Cacheable>(
            _ type: Value.Type, id: String, directory: URL
        ) -> Entry<Value>? {
            let key = "\(Value.self)_\(id)"
            let url = directory.appending(path: "SekaiKit_\(key).cache")
            guard let data = try? Data(contentsOf: url), let value = Value(fromCache: data) else { return nil }
            return Entry(value: value, updated: dates(in: directory)[key])
        }

        func write<Value: Sendable & Cacheable>(_ value: Value, id: String, directory: URL) {
            let key = "\(Value.self)_\(id)"
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try value.dataForCache.write(to: directory.appending(path: "SekaiKit_\(key).cache"), options: .atomic)
                var dates = dates(in: directory)
                dates[key] = Date.now.timeIntervalSince1970
                try PropertyListEncoder().encode(dates).write(
                    to: directory.appending(path: "SekaiCacheInfo.plist"), options: .atomic
                )
            } catch {
                // A failed write must not make an old cache appear fresh.
            }
        }

        private func dates(in directory: URL) -> [String: TimeInterval] {
            guard let data = try? Data(contentsOf: directory.appending(path: "SekaiCacheInfo.plist")),
                  let dates = try? PropertyListDecoder().decode([String: TimeInterval].self, from: data) else { return [:] }
            return dates
        }
    }

    private static func refresh<Value: Sendable & Cacheable>(
        id: String, trait: CacheTrait, directory: URL,
        isolation: isolated (any Actor)? = #isolation,
        invocation: () async -> Value?
    ) async -> Value? {
        guard !Task.isCancelled else { return nil }
        let result = await $preferCachedNetworkSource.withValue(trait != .realTime, operation: invocation)
        guard !Task.isCancelled else { return nil }
        if let result {
            await DiskStorage.shared.write(result, id: id, directory: directory)
        }
        return result
    }
    
    /// Loads a value while delivering available disk cache data through a promise.
    ///
    /// A cached value is delivered first when available. Unless the cache policy
    /// skips loading, a non-`nil` result is then delivered and written to disk. A
    /// failed load delivers `nil` only when no cached value was available.
    /// Register the update closure immediately; earlier updates are not replayed.
    ///
    /// ```swift
    /// SekaiCache.withCache(id: "JapaneseCharacters") {
    ///     await Character.allInLocale(.jp)
    /// }.onUpdate { characters, source in
    ///     print(characters?.count ?? 0, source)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - id: The cache identifier. Identical identifiers with different result types use separate files.
    ///   - trait: The policy governing reuse of cached values.
    ///   - invocation: The asynchronous operation used to obtain a value.
    /// - Returns: A promise delivering cached and loaded results.
    public static func withCache<Result: Sendable & Cacheable>(
        id: String,
        trait: CacheTrait = .invocationElidable,
        invocation: sending @escaping () async -> Result?
    ) -> Promise<Result?> {
        let directory = cacheDirectory
        let promise: Promise<Result?> = .init()
        let task = Task.detached(priority: .userInitiated) {
            let cached = await DiskStorage.shared.read(Result.self, id: id, directory: directory)
            if let cached {
                await promise.updateValue(cached.value, from: .cache)
                if trait == .invocationElidable && cached.isFresh { return }
            }
            let result = await refresh(id: id, trait: trait, directory: directory, invocation: invocation)
            guard !Task.isCancelled else { return }
            if result != nil || cached == nil {
                await promise.updateValue(result, from: .origin)
            }
        }
        
        promise.onCancel {
            task.cancel()
        }
        
        return promise
    }
    
    /// Removes the disk cache for a result type and identifier.
    ///
    /// Missing files and removal errors are ignored.
    ///
    /// - Parameters:
    ///   - type: The cached result type.
    ///   - id: The cache identifier.
    public static func invalidate<T>(_ type: T.Type, withID id: String) {
        let cacheURL = cacheDirectory.appending(path: "SekaiKit_\(type)_\(id).cache")
        try? FileManager.default.removeItem(at: cacheURL)
    }
    /// Removes SekaiKit cache files from the app’s cache directory.
    ///
    /// Missing files and removal errors are ignored. This does not clear the bundled cache.
    public static func invalidateAll() {
        let cacheRootPath = cacheDirectory.path
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: cacheRootPath) else { return }
        for file in files where file.hasPrefix("SekaiKit") && file.hasSuffix(".cache") && !file.hasPrefix(".") {
            try? FileManager.default.removeItem(atPath: "\(cacheRootPath)/\(file)")
        }
    }
    
    /// Awaits a result using the specified disk cache policy.
    ///
    /// The elidable policy returns available cache data immediately and refreshes
    /// stale data in the background. The real-time policy waits for a new result,
    /// falling back to cached data if loading fails. Cancellation returns `nil`
    /// once the loading operation cooperates with cancellation.
    ///
    /// - Parameters:
    ///   - id: The cache identifier.
    ///   - trait: The policy governing reuse of cached values.
    ///   - invocation: The asynchronous operation used to obtain a value.
    /// - Returns: The loaded or cached result, or `nil` when neither is available or the task is cancelled.
    public static func withDirectCache<Result: Sendable & Cacheable>(
        id: String,
        trait: CacheTrait = .invocationElidable,
        invocation: @Sendable @escaping () async -> Result?
    ) async -> Result? {
        let directory = cacheDirectory
        guard !Task.isCancelled else { return nil }
        let cached = await DiskStorage.shared.read(Result.self, id: id, directory: directory)
        guard !Task.isCancelled else { return nil }
        if trait == .invocationElidable, let cached {
            if !cached.isFresh {
                Task.detached(priority: .userInitiated) {
                    _ = await refresh(id: id, trait: trait, directory: directory, invocation: invocation)
                }
            }
            return cached.value
        }
        let result = await refresh(id: id, trait: trait, directory: directory, invocation: invocation)
        return Task.isCancelled ? nil : (result ?? cached?.value)
    }
}

extension SekaiCache.Promise: Sendable where Result: Sendable {}

extension SekaiCache.Cacheable {
    /// Decodes a value from cached property-list data.
    ///
    /// The initializer accepts direct values and wrapped scalar values, and returns
    /// `nil` if the data cannot be decoded.
    ///
    /// - Parameter cache: The cached bytes to decode.
    public init?(fromCache cache: Data) {
        let decoder = PropertyListDecoder()
        if let data = try? decoder.decode(Self.self, from: cache) {
            self = data
        } else if let wrapped = try? decoder.decode(CacheWrapper<Self>.self, from: cache) {
            self = wrapped.value
        } else {
            return nil
        }
    }
    /// The binary property-list representation of the value, wrapping scalar values when needed.
    public var dataForCache: Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        do {
            return try encoder.encode(self)
        } catch {
            // If `self` is a single value (e.g. String),
            // PropertyListEncoder can't encode it,
            // we use a wrapper then.
            let wrappedValue = CacheWrapper(value: self)
            return try! encoder.encode(wrappedValue)
        }
    }
}
private struct CacheWrapper<T: SekaiCache.Cacheable>: SekaiCache.Cacheable {
    var value: T
}

extension Color: @retroactive Encodable {
    enum CodingKeys: CodingKey {
        case red
        case green
        case blue
    }
    
    /// Encodes the resolved red, green, and blue components of a color.
    ///
    /// The color is resolved in a default environment; alpha is not stored.
    ///
    /// - Parameter encoder: The encoder receiving the RGB components.
    /// - Throws: Any error encountered while encoding the components.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let resolved = self.resolve(in: .init())
        try container.encode(resolved.red, forKey: .red)
        try container.encode(resolved.green, forKey: .green)
        try container.encode(resolved.blue, forKey: .blue)
    }
}
extension Color: @retroactive Decodable {
    /// Decodes an opaque color from stored red, green, and blue components.
    ///
    /// - Parameter decoder: The decoder providing the RGB components.
    /// - Throws: Any error encountered while decoding the components.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let red = try container.decode(Double.self, forKey: .red)
        let green = try container.decode(Double.self, forKey: .green)
        let blue = try container.decode(Double.self, forKey: .blue)
        self.init(red: red, green: green, blue: blue)
    }
}
extension Color: SekaiCache.Cacheable {}

extension String: SekaiCache.Cacheable {}
extension Int: SekaiCache.Cacheable {}
extension Int8: SekaiCache.Cacheable {}
extension Int16: SekaiCache.Cacheable {}
extension Int32: SekaiCache.Cacheable {}
extension Int64: SekaiCache.Cacheable {}
extension UInt: SekaiCache.Cacheable {}
extension UInt8: SekaiCache.Cacheable {}
extension UInt16: SekaiCache.Cacheable {}
extension UInt32: SekaiCache.Cacheable {}
extension UInt64: SekaiCache.Cacheable {}
extension Bool: SekaiCache.Cacheable {}
extension Double: SekaiCache.Cacheable {}
extension Float: SekaiCache.Cacheable {}
extension Date: SekaiCache.Cacheable {}
extension Array: SekaiCache.Cacheable where Element: SekaiCache.Cacheable {}
extension Dictionary: SekaiCache.Cacheable where Key: SekaiCache.Cacheable, Value: SekaiCache.Cacheable {}
extension Set: SekaiCache.Cacheable where Element: SekaiCache.Cacheable {}
extension Optional: SekaiCache.Cacheable where Wrapped: SekaiCache.Cacheable {}

/// A SekaiKit model that supports property-list cache encoding and decoding.
public protocol SekaiCachable: SekaiCache.Cacheable {}
extension Array: SekaiCachable where Element: SekaiCachable {}


/// Loads a SekaiKit model while delivering cached and newly loaded values.
///
/// This convenience function forwards to ``SekaiCache/withCache(id:trait:invocation:)``.
///
/// - Parameters:
///   - id: The cache identifier.
///   - trait: The policy governing reuse of cached values.
///   - invocation: The asynchronous operation used to obtain a value.
/// - Returns: A promise delivering cached and loaded results.
@inline(__always)
public func withSekaiCache<Result: Sendable & SekaiCachable>(
    id: String,
    trait: SekaiCache.CacheTrait = .invocationElidable,
    invocation: sending @escaping () async -> Result?
) -> SekaiCache.Promise<Result?> {
    SekaiCache.withCache(id: id, trait: trait, invocation: invocation)
}
