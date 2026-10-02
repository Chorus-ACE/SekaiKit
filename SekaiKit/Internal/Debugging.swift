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
    /// Prints and returns JSON object keys that are not in a known set.
    ///
    /// - Parameter knownKeys: The expected object keys.
    /// - Returns: The unknown keys, in unspecified order.
    @discardableResult
    func debugFindUnknownKeys(knownKeys: [String]) -> [String] {
        let result = Array(self.dictionaryValue.keys).filter({ !knownKeys.contains($0) })
        if !result.isEmpty {
            print("[!] Unknown Keys Found: \(result)")
        }
        return result
    }
}


/// Returns the diagnostic dump of a value.
///
/// - Parameter content: The value to inspect.
/// - Returns: The textual output of Swift’s `dump` function.
public func disassemble(_ content: Any) -> String {
    var result = ""
    dump(content, to: &result)
    return result
}
