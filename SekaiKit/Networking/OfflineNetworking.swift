//===---*- Greatdori! -*---------------------------------------------------===//
//
// OfflineNetworking.swift
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
internal import Alamofire

@available(*, deprecated, message: "SekaiKit does not support offline asset.")
internal func offlineAssetResult(for convertible: URLConvertible) -> OfflineAssetNetworkingResult {
    if let url = try? convertible.asURL() {
        offlineAssetResult(for: url)
    } else {
        .useDefault
    }
}

@available(*, deprecated, message: "SekaiKit does not support offline asset.")
internal func offlineAssetResult(for url: URL) -> OfflineAssetNetworkingResult {
    offlineAssetResult(for: url.absoluteString)
}

@available(*, deprecated, message: "SekaiKit does not support offline asset.")
internal func offlineAssetResult(for url: String) -> OfflineAssetNetworkingResult {
//    #if canImport(SekaiAssetShims)
//    let behavior = SekaiOfflineAsset.localBehavior
//    if behavior == .disabled { return .useDefault }
//    
//    guard url.hasPrefix("https://bestdori.com/") else { return .useDefault }
//    let basePath = String(url.dropFirst("https://bestdori.com/".count))
//    
//    if basePath.hasPrefix("api") {
//        if let data = try? SekaiOfflineAsset.shared.fileData(forPath: basePath, in: .jp, of: .main) {
//            return .delegated(data)
//        } else if behavior == .enabled {
//            return .delegated(nil)
//        }
//    }
//    #endif
    
    return .useDefault
}

internal enum OfflineAssetNetworkingResult {
    case delegated(Data?)
    case useDefault
}

extension URL {
    @available(*, deprecated, message: "SekaiKit does not support offline asset.")
    public func withOfflineAsset() -> URL {
        return self
    }
    
    @available(*, deprecated, message: "SekaiKit does not support offline asset.")
    public func respectOfflineAssetContext() -> URL {
        return self
    }
}
