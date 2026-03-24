//
//  LocalizableBridgeMacro.swift
//  SekaiKit
//
//  Created by ThreeManager785 on 2026/3/22.
//

import SwiftSyntax
import SwiftCompilerPlugin
import SwiftSyntaxMacros

// Macro Definition
public struct LocalizationsCombinableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
//        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
//            return []
//        }
        
        let variableNames = declaration.memberBlock.members.compactMap { member -> String? in
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                  varDecl.bindingSpecifier.text == "var" else {
                return nil
            }
            
            for binding in varDecl.bindings {
                guard binding.typeAnnotation?.type.as(IdentifierTypeSyntax.self)?.name.text == "LocalizableData" else {
                    continue
                }
                
                if let accessorBlock = binding.accessorBlock {
                            switch accessorBlock.accessors {
                            case .accessors(let accessors):
                                // 检查是否存在 'set' 或 'willSet' / 'didSet'
                                let hasWriteAccessor = accessors.contains { accessor in
                                    let token = accessor.accessorSpecifier.text
                                    return token == "set" || token == "willSet" || token == "didSet"
                                }
                                if !hasWriteAccessor { continue }
                                
                            case .getter:
                                // 只有 getter 的闭包写法：var x: Type { ... }
                                // 这种情况绝对是只读的
                                continue
                            }
                        }

                        // 4. 提取符合条件的变量名
                        if let propertyName = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text {
                            return propertyName
                        }
                
            }
            return nil
        }
        
//        let members = declaration.memberBlock.members
//        let variableNames = members.compactMap { member -> String? in
//            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
//                  let type = varDecl.bindings.first?.typeAnnotation?.type.description.trimmingCharacters(in: .whitespaces),
//                  type.contains("LocalizableData") else { return nil }
//            
//            return varDecl.bindings.first?.pattern.description.trimmingCharacters(in: .whitespaces)
//        }

        let operations = variableNames.map({ "result.\($0).updateLocalizedValue(dict[locale]?.\($0).majorValue, forLocale: locale)" }).joined(separator: "\n")
        
        let code: DeclSyntax = """
        public static func combineLocalizations(_ dict: [SekaiLocale: Self], defaultLocale: SekaiLocale = .primaryLocale) -> Self? {
            var result = dict[defaultLocale] ?? dict.first?.value
            guard var result else { return nil }
            
            for locale in SekaiLocale.allCases {
                \(raw: operations)
            }
            
            return result
        }
        
        public static func combineLocalizations(_ dict: [SekaiLocale: Self?], defaultLocale: SekaiLocale = .primaryLocale) -> Self? {
            return Self.combineLocalizations(dict.compactMapValues({ $0 }), defaultLocale: defaultLocale)
        }
        """
        
        
        return [code]
    }
}

@main
struct SekaiKitMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        LocalizationsCombinableMacro.self
    ]
}
