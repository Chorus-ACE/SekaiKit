//
//  TitleDescribable.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/8/2.
//

public protocol TitleDescribable {
    var title: LocalizableData<String> { get }
}

extension Character: TitleDescribable {
    public var title: LocalizableData<String> { fullName }
}

extension Card: TitleDescribable {
    public var title: LocalizableData<String> { self.name }
}

extension Event: TitleDescribable {}
