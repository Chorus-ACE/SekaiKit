//
//  TitleDescribable.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/8/2.
//

/// A type that exposes a localized display title.
public protocol TitleDescribable {
    /// The localized title used to represent this record.
    var title: LocalizableData<String> { get }
}

extension Character: TitleDescribable {
    /// The localized title used to represent this record.
    public var title: LocalizableData<String> { fullName }
}

extension Card: TitleDescribable {
    /// The localized title used to represent this record.
    public var title: LocalizableData<String> { self.name }
}

extension Event: TitleDescribable {}

extension ExtendedEvent: TitleDescribable {
    /// The localized title used to represent this record.
    public var title: LocalizableData<String> { self.event.title }
}

extension Song: TitleDescribable {}

extension ExtendedSong: TitleDescribable {
    /// The localized title used to represent this record.
    public var title: LocalizableData<String> { self.song.title }
}
