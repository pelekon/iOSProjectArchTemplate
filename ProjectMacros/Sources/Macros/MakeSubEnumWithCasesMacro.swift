//
//  File.swift
//  
//
//  Created by Bartłomiej Bukowiecki on 29/06/2024.
//

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

struct MakeSubEnumWithCasesMacro: MemberMacro {
    static func expansion(
      of node: AttributeSyntax,
      providingMembersOf declaration: some DeclGroupSyntax,
      in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw DiagnosticsError(diagnostics: [
                .init(node: declaration, message: MacroUsableOnEnum())
            ])
        }
        
        var memberNames = [String]()
        
        for enumCase in enumDecl.memberBlock.members {
            guard let caseDecl = enumCase.decl.as(EnumCaseDeclSyntax.self),
                  let caseMember = caseDecl.elements.first else { continue }
            
            memberNames.append(caseMember.name.trimmed.text)
        }
        
        var caseItemsSyntax = try memberNames.map { try MemberBlockItemSyntax(decl: EnumCaseDeclSyntax("case \(raw: $0)")) }
        
        let initSyntax = try InitializerDeclSyntax("init(parent: \(raw: enumDecl.name.trimmed))") {
            try SwitchExprSyntax("switch parent") {
                for member in memberNames {
                    SwitchCaseSyntax("case .\(raw: member): self = .\(raw: member)")
                }
            }
        }
        caseItemsSyntax.append(MemberBlockItemSyntax(decl: initSyntax))
        
        let enumMemberBlock = MemberBlockSyntax(members: MemberBlockItemListSyntax(caseItemsSyntax))
        let nestedEnum = EnumDeclSyntax(name: TokenSyntax(stringLiteral: "CaseLabels"), memberBlock: enumMemberBlock)
        
        return [nestedEnum.cast(DeclSyntax.self)]
    }
}

extension MakeSubEnumWithCasesMacro {
    struct MacroUsableOnEnum: DiagnosticMessage {
        let message = "Macro can be used only on enums!"
        let diagnosticID = MessageID(domain: "MakeSubEnumWithCasesMacro", id: "1")
        let severity = DiagnosticSeverity.error
    }
}
