//
//  Debugging.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/2/1.
//

// FIXME: Everything here shall be declared internal later on.

public import SwiftyJSON

@_spi(Debug)
public extension JSON {
    @discardableResult
    func debugFindUnknownKeys(knownKeys: [String]) -> [String] {
        let result = Array(self.dictionaryValue.keys).filter({ !knownKeys.contains($0) })
        if !result.isEmpty {
            print("[!] Unknown Keys Found: \(result)")
        }
        return result
    }
}


public func disassemble(_ content: Any) -> String {
    var result = ""
    dump(content, to: &result)
    return result
}
