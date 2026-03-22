//
//  Protocol.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/2/1.
//

public protocol TitleDescribable {
    var title: String { get }
}

public protocol GettableByID {
    init?(id: Int) async
}

public protocol ListGettable {
    static func all(forLocale locale: SekaiLocale) async -> [Self]?
}

// MARK: - ExtendedTypeConvertible
public protocol ExtendedTypeConvertible {
    associatedtype ExtendedType
}
