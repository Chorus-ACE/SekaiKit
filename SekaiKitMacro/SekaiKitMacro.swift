//
//  SekaiKitMacro.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/3/22.
//

@attached(member, names: named(combineLocalizations))
public macro LocalizationsCombinable() = #externalMacro(module: "SekaiKitMacroMacros", type: "LocalizationsCombinableMacro")
