//===---*- Greatdori! -*---------------------------------------------------===//
//
// NetworkRequest.swift
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
internal import SwiftyJSON

internal func requestJSON(
    _ convertible: URLConvertible,
    method: HTTPMethod = .get,
    parameters: Parameters? = nil,
    encoding: ParameterEncoding = URLEncoding.default,
    interceptor: RequestInterceptor? = nil,
    requestModifier: Session.RequestModifier? = nil
) async -> JSON? {
    let request = AF.request(convertible, method: method, parameters: parameters, encoding: encoding, interceptor: interceptor, requestModifier: requestModifier)
    let result: JSON? = await withCheckedContinuation { continuation in
        request.response(completionHandler: { response in
            if let data = response.data {
                Task.detached(priority: .userInitiated) {
                    if let json = try? JSON(data: data) {
                        continuation.resume(returning: json)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            } else {
                continuation.resume(returning: nil)
            }
        })   
    }
    return result
}


internal func legacyRequestJSON(
    _ convertible: URLConvertible,
    method: HTTPMethod = .get,
    parameters: Parameters? = nil,
    encoding: ParameterEncoding = URLEncoding.default,
    interceptor: RequestInterceptor? = nil,
    requestModifier: Session.RequestModifier? = nil
) async -> JSON? {
    let result = await _requestJSON(convertible) {
        AF.request(
            convertible,
            method: method,
            parameters: parameters,
            encoding: encoding,
            headers: _getThreadHeaders(),
            interceptor: interceptor,
            requestModifier: requestModifier
        )
    }
    if case .success(let success) = result {
        return success
    } else {
        return nil
    }
}

internal func legacyRequestJSON<Parameters: Encodable & Sendable>(
    _ convertible: URLConvertible,
    method: HTTPMethod = .get,
    parameters: Parameters? = nil,
    encoder: any ParameterEncoder = URLEncodedFormParameterEncoder.default,
    interceptor: RequestInterceptor? = nil,
    requestModifier: Session.RequestModifier? = nil
) async -> JSON? {
    let result = await _requestJSON(convertible) {
        AF.request(
            convertible,
            method: method,
            parameters: parameters,
            encoder: encoder,
            headers: _getThreadHeaders(),
            interceptor: interceptor,
            requestModifier: requestModifier
        )
    }
    if case .success(let success) = result {
        return success
    } else {
        return nil
    }
}

private func _getThreadHeaders() -> HTTPHeaders {
    var result = AF.sessionConfiguration.headers
//    
//    if let userToken = SekaiFrontend.User._currentUserToken {
//        var cookie = result["Cookie"] ?? ""
//        if !cookie.isEmpty {
//            cookie += "; "
//        }
//        cookie += "token=\(userToken.value)"
//        result.update(name: "Cookie", value: cookie)
//    }
    
    return result
}

private func _requestJSON(
    _ convertible: URLConvertible,
    makeRequest: sending @escaping () -> DataRequest
) async -> Result<JSON, Void> {
//    switch offlineAssetResult(for: convertible) {
//    case .delegated(let data):
//        if let data {
//            let task = Task.detached(priority: .userInitiated) { () -> Result<JSON, Void> in
//                do {
//                    let json = try JSON(data: data)
//                    return .success(json)
//                } catch {
//                    return .failure(())
//                }
//            }
//            return await task.value
//        } else {
//            return .failure(())
//        }
//    case .useDefault:
//        break
//    }
    
    // Preload
    if let url = try? convertible.asURL(),
       let data = await SekaiCache._dataFromPreloaded(url),
       let json = try? JSON(data: data) {
        return .success(json)
    }
    
    if SekaiCache.preferCachedNetworkSource,
       let url = try? convertible.asURL(),
       let cache = await NetworkCache.shared.getCache(for: url),
       abs(Date.now.timeIntervalSince1970 - cache.dateUpdated.timeIntervalSince1970) < 60 * 60 {
        if let json = (try? JSON(data: cache.data)) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                makeRequest().responseData { response in
                    if let data = response.data {
                        Task.detached(priority: .userInitiated) {
                            if (try? JSON(data: data)) != nil {
                                await NetworkCache.shared.updateCache(.init(data: data), for: url)
                            }
                        }
                    }
                }
            }
            SekaiCache._finishedLoadSource?(url, cache.data)
            return .success(json)
        } else {
            await NetworkCache.shared.removeCache(for: url)
        }
    }
    
    let request = makeRequest()
    return await withTaskCancellationHandler {
        await withCheckedContinuation { continuation in
            // !!!: Receive all task locals here
            let preferCachedNetworkSource = SekaiCache.preferCachedNetworkSource
            let finishedLoadSource = SekaiCache._finishedLoadSource
            request.responseData { response in
                let data = response.data
                if data != nil {
                    Task.detached(priority: .userInitiated) {
                        do {
                            let json = try JSON(data: data!)
                            continuation.resume(returning: .success(json))
                            if let url = try? convertible.asURL() {
                                finishedLoadSource?(url, data!)
                                if preferCachedNetworkSource {
                                    await NetworkCache.shared.updateCache(.init(data: data!), for: url)
                                }
                            }
                        } catch {
                            continuation.resume(returning: .failure(()))
                        }
                    }
                } else {
                    continuation.resume(returning: .failure(()))
                }
            }
        }
    } onCancel: {
        request.cancel()
    }
}

internal enum Result<Success, Failure> {
    case success(Success)
    case failure(Failure)
}

extension Result: Sendable where Success: Sendable, Failure: Sendable {}

extension JSON: @retroactive @unchecked Sendable {}
