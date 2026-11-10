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
    public final class PreloadDescriptor<T: Sendable>: Sendable {
        private let source: PreloadSource
        private let loadTask: Task<T?, Never>

        internal init(perform action: sending @escaping () async -> T?) {
            let source = PreloadSource()
            self.source = source
            self.loadTask = Task.detached {
                // The task owns this state until it has actually stopped, including
                // when the descriptor is released and cancellation is ignored.
                defer { source.finish() }
                return await $_finishedLoadSource.withValue({ url, data in
                    source.store(data, for: url)
                }, operation: action)
            }
        }

        deinit {
            loadTask.cancel()
        }

        /// The preloaded result, waiting for the operation to finish if needed.
        public var value: T? {
            get async { await loadTask.value }
        }

        internal func sourceData(for url: URL, timeout: Duration = .seconds(5)) async -> Data? {
            await source.data(for: url, timeout: timeout)
        }
    }

    // All mutable state is protected by the lock. Each reader gets its own stream
    // so publication, completion, timeout and cancellation can wake every reader.
    private final class PreloadSource: @unchecked Sendable {
        private let lock = NSLock()
        private var source: (url: URL, data: Data)?
        private var isFinished = false
        private var readers: [UUID: AsyncStream<Void>.Continuation] = [:]

        func store(_ data: Data, for url: URL) {
            let readers = lock.withLock {
                source = (url, data)
                let pending = Array(self.readers.values)
                self.readers.removeAll()
                return pending
            }
            for reader in readers { reader.finish() }
        }

        func finish() {
            let readers = lock.withLock {
                isFinished = true
                let pending = Array(self.readers.values)
                self.readers.removeAll()
                return pending
            }
            for reader in readers { reader.finish() }
        }

        func data(for url: URL, timeout: Duration) async -> Data? {
            guard !Task.isCancelled else { return nil }
            let id = UUID()
            let (stream, continuation) = AsyncStream<Void>.makeStream()
            let shouldWait = lock.withLock {
                guard source == nil && !isFinished else { return false }
                readers[id] = continuation
                return true
            }
            if shouldWait {
                let timer = Task {
                    do {
                        try await Task.sleep(for: timeout)
                        continuation.finish()
                    } catch {}
                }
                defer {
                    timer.cancel()
                    _ = lock.withLock { readers.removeValue(forKey: id) }
                }
                // Finishing the stream wakes the reader without blocking a thread.
                // AsyncStream also ends iteration when this task is cancelled.
                for await _ in stream {}
            }
            guard !Task.isCancelled else { return nil }
            return lock.withLock { source?.url == url ? source?.data : nil }
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
        PreloadDescriptor(perform: closure)
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
