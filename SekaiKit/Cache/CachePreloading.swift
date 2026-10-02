//===---*- Greatdori! -*---------------------------------------------------===//
//
// CachePreloading.swift
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

extension SekaiCache {
    @TaskLocal
    internal static var _finishedLoadSource: (@Sendable (URL, Data) -> Void)?
    @TaskLocal
    internal static var _dataFromPreloaded: @Sendable (URL) async -> Data? = { _ in nil }
    
    /// A handle that retains an asynchronous preload operation and its captured network source.
    ///
    /// Keep the descriptor alive until the result or captured data is no longer needed.
    /// Releasing the descriptor cancels its task.
    @safe
    public final class PreloadDescriptor<T: Sendable>: Sendable {
        nonisolated(unsafe) private let sourceURLRef: UnsafeMutablePointer<URL?>
        nonisolated(unsafe) private let sourceDataRef: UnsafeMutablePointer<Data?>
        private let loadTask: Task<T?, Never>
        
        @safe
        internal init(
            sourceURLRef: UnsafeMutablePointer<URL?>,
            sourceDataRef: UnsafeMutablePointer<Data?>,
            perform action: sending @escaping () async -> T?
        ) {
            unsafe self.sourceURLRef = sourceURLRef
            unsafe self.sourceDataRef = sourceDataRef
            self.loadTask = Task.detached(operation: action)
        }
        
        deinit {
            loadTask.cancel()
            unsafe sourceDataRef.deallocate()
            unsafe sourceURLRef.deallocate()
        }
        
        /// The preloaded result, waiting for the operation to finish if needed.
        public var value: T? {
            get async {
                await loadTask.value
            }
        }
        
        internal func sourceData(for url: URL) async -> Data? {
            if let _url = unsafe sourceURLRef.pointee {
                if url != _url {
                    return nil
                }
                if let data = unsafe sourceDataRef.pointee {
                    return data
                }
            }
            let timeout: CGFloat = 5
            return await withCheckedContinuation { continuation in
                let startTime = CFAbsoluteTimeGetCurrent()
                while CFAbsoluteTimeGetCurrent() - startTime < timeout {
                    if let _url = unsafe sourceURLRef.pointee {
                        if url != _url {
                            continuation.resume(returning: nil)
                            return
                        }
                        if let data = unsafe sourceDataRef.pointee {
                            continuation.resume(returning: data)
                            return
                        }
                    }
                }
            }
        }
    }
    
    /// Starts loading a value for later use.
    ///
    /// Retain the returned descriptor while preloading. Await its `value` property to
    /// retrieve the result, or pass it to ``withPreloaded(_:isolation:operation:)``
    /// to make captured source data available to SekaiKit requests. Each descriptor
    /// captures a single request source; use separate descriptors for separate resources.
    ///
    /// ```swift
    /// let characters = SekaiCache.preload {
    ///     await Character.allInLocale(.jp)
    /// }
    /// let records = await characters.value
    /// ```
    ///
    /// - Parameter closure: The asynchronous operation that loads the value.
    /// - Returns: A descriptor retaining the preload operation.
    public static func preload<T: Sendable>(_ closure: sending @escaping () async -> T?) -> PreloadDescriptor<T> {
        let ptrSourceURL = UnsafeMutablePointer<URL?>.allocate(capacity: 1)
        unsafe ptrSourceURL.initialize(to: nil)
        let ptrSourceData = UnsafeMutablePointer<Data?>.allocate(capacity: 1)
        unsafe ptrSourceData.initialize(to: nil)
        let ptrRepSourceURL = Int(bitPattern: ptrSourceURL)
        let ptrRepSourceData = Int(bitPattern: ptrSourceData)
        
        return PreloadDescriptor(
            sourceURLRef: ptrSourceURL,
            sourceDataRef: ptrSourceData
        ) {
            await $_finishedLoadSource.withValue({ url, data in
                unsafe UnsafeMutablePointer(bitPattern: ptrRepSourceURL)!.pointee = url
                unsafe UnsafeMutablePointer(bitPattern: ptrRepSourceData)!.pointee = data
            }, operation: closure)
        }
    }
    
    /// Runs an operation with access to previously captured network sources.
    ///
    /// Requests made by the operation can reuse source data from the supplied
    /// descriptors when their URLs match.
    ///
    /// - Parameters:
    ///   - descriptors: The optional descriptors to consult in the supplied order.
    ///   - isolation: The actor isolation inherited by the operation.
    ///   - operation: The operation that can reuse the preloaded data.
    /// - Returns: The value returned by `operation`.
    /// - Throws: Any error thrown by `operation`.
    public static func withPreloaded<each T, Result>(
        _ descriptors: repeat PreloadDescriptor<each T>?,
        isolation: isolated (any Actor)? = #isolation,
        operation: () async throws -> Result
    ) async rethrows -> Result {
        try await $_dataFromPreloaded.withValue({ url in
            for descriptor in repeat each descriptors {
                if let descriptor {
                    if let data = await descriptor.sourceData(for: url) {
                        return data
                    }
                }
            }
            return nil
        }, operation: operation, isolation: isolation)
    }
}
