//
//  SekaiKitMacro.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/3/22.
//

/// Generates methods that combine a model’s localized fields across game locales.
///
/// Apply this macro to a model with writable `LocalizableData` properties. The
/// generated overloads accept dictionaries of records or optional records, merge
/// localized properties, and preserve other fields from the preferred source
/// record or an available fallback record.
///
/// The model must separately declare conformance to the `LocalizationsCombinable` protocol.
@attached(member, names: named(combineLocalizations))
public macro LocalizationsCombinable() = #externalMacro(module: "SekaiKitMacroMacros", type: "LocalizationsCombinableMacro")
