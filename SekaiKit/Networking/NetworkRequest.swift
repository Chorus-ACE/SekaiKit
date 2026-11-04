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


extension JSON: @retroactive @unchecked Sendable {}
