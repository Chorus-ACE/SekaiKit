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
    
    private static let cacheDateEncoder = PropertyListEncoder()
    private static let cacheDateDecoder = PropertyListDecoder()
    
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
        let cacheURL = URL(filePath: NSHomeDirectory() + "/Library/Caches/SekaiKit_\(Result.self)_\(id).cache")
        
        let promise: Promise<Result?> = .init()
        
//        #if canImport(SekaiAssetShims)
//        let offlineAssetBehavior = SekaiOfflineAsset.localBehavior
//        #endif
        
        let task = Task.detached(priority: .userInitiated) {
            var cachedResult: Result?
            if let cachedData = try? Data(contentsOf: cacheURL) {
                cachedResult = Result(fromCache: cachedData)
            }
            
            if let cachedResult {
                await promise.updateValue(cachedResult, from: .cache)
                if trait == .invocationElidable {
                    let cacheInfoURL = URL(filePath: NSHomeDirectory() + "/Library/Caches/SekaiCacheInfo.plist")
                    let nowDate = Date.now
                    let newCacheDates: [String: TimeInterval]
                    if let _data = try? Data(contentsOf: cacheInfoURL),
                       var cacheDates = try? cacheDateDecoder.decode([String: TimeInterval].self, from: _data) {
                        if let thisDate = cacheDates["\(Result.self)_\(id)"],
                           nowDate.timeIntervalSince1970 - thisDate <= 24 * 60 * 60 {
                            // Current cache is new enough, we elide request from network
                            return
                        }
                        cacheDates.updateValue(nowDate.timeIntervalSince1970, forKey: "\(Result.self)_\(id)")
                        newCacheDates = cacheDates
                    } else {
                        newCacheDates = ["\(Result.self)_\(id)": nowDate.timeIntervalSince1970]
                    }
                    try? cacheDateEncoder.encode(newCacheDates).write(to: cacheInfoURL)
                }
            }
            
//            #if canImport(SekaiAssetShims)
//            // We have to explicitly call `withValue` to keep the localBehavior
//            // because we're running in a detached task.
//            let result = await SekaiOfflineAsset.$localBehavior.withValue(offlineAssetBehavior) {
//                await $preferCachedNetworkSource.withValue(true, operation: invocation)
//            }
//            #else
            let result = await $preferCachedNetworkSource.withValue(true, operation: invocation)
//            #endif
            
            // If result is nil but there's data in cache,
            // we don't update value of promise.
            if result == nil && cachedResult != nil {
                return
            }
            
            await promise.updateValue(result, from: .origin)
            
            // Don't save cache if result is nil
            if result == nil {
                return
            }
            
            let cache = result.dataForCache
            try? cache.write(to: cacheURL)
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
        let cacheURL = URL(filePath: NSHomeDirectory() + "/Library/Caches/SekaiKit_\(type)_\(id).cache")
        try? FileManager.default.removeItem(at: cacheURL)
    }
    /// Removes SekaiKit cache files from the app’s cache directory.
    ///
    /// Missing files and removal errors are ignored. This does not clear the bundled cache.
    public static func invalidateAll() {
        let cacheRootPath = NSHomeDirectory() + "/Library/Caches"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: cacheRootPath) else { return }
        for file in files where file.hasPrefix("SekaiKit") && file.hasSuffix(".cache") && !file.hasPrefix(".") {
            try? FileManager.default.removeItem(atPath: "\(cacheRootPath)/\(file)")
        }
    }
    
    /// Awaits a result using the specified disk cache policy.
    ///
    /// The elidable policy returns the first delivered value. The real-time policy
    /// waits for an origin update. If an origin request fails after cached data was
    /// delivered, the current promise implementation suppresses that update and
    /// this method can remain suspended.
    ///
    /// - Parameters:
    ///   - id: The cache identifier.
    ///   - trait: The policy governing reuse of cached values.
    ///   - invocation: The asynchronous operation used to obtain a value.
    /// - Returns: The first result allowed by the policy, or `nil` when an allowed update has no value.
    public static func withDirectCache<Result: Sendable & Cacheable>(
        id: String,
        trait: CacheTrait = .invocationElidable,
        invocation: @Sendable @escaping () async -> Result?
    ) async -> Result? {
        var hadReturned = false
        
        
        let result = await withCheckedContinuation { continuation in
            withCache(id: id, trait: trait, invocation: invocation)
                .onUpdate { result, source in
                    if !hadReturned && (source == .origin || trait == .invocationElidable) {
                        continuation.resume(returning: result)
                        hadReturned = true
                    }
                }
        }
        
        return result
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
