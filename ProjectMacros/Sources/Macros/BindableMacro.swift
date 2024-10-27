//
//  BindableMacro.swift
//  ProjectMacros
//
//  Created by Bartłomiej Bukowiecki on 27/10/2024.
//

import Foundation
import SwiftSyntax
import SwiftDiagnostics
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import SwiftCompilerPlugin

struct BindableMacro: PeerMacro {
    static func expansion(
      of node: AttributeSyntax,
      providingPeersOf declaration: some DeclSyntaxProtocol,
      in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw DiagnosticsError(diagnostics: [
                .init(node: declaration, message: WrongParentType())
            ])
        }
        
        guard funcDecl.signature.returnClause == nil && funcDecl.signature.effectSpecifiers == nil else {
            throw DiagnosticsError(diagnostics: [
                .init(node: declaration, message: InvalidSunctionSignature())
            ])
        }
        
        guard let pramDecl = funcDecl.signature.parameterClause.parameters.first,
                funcDecl.signature.parameterClause.parameters.count == 1 else {
            throw DiagnosticsError(diagnostics: [
                .init(node: declaration, message: TooManyParameter())
            ])
        }
        
        return []
    }
}

extension BindableMacro {
    struct WrongParentType: DiagnosticMessage {
        let message = "Macro can be used only on functions."
        let diagnosticID = MessageID(domain: "project.macros", id: "1")
        let severity = DiagnosticSeverity.error
    }
    
    struct InvalidSunctionSignature: DiagnosticMessage {
        let message = "Function cannot have return type nor be marked with async/throws/rethrows etc keywords."
        let diagnosticID = MessageID(domain: "project.macros", id: "3")
        let severity = DiagnosticSeverity.error
    }
    
    struct TooManyParameter: DiagnosticMessage {
        let message = "Function can contain only single prameter containing new value from binding."
        let diagnosticID = MessageID(domain: "project.macros", id: "3")
        let severity = DiagnosticSeverity.error
    }
}
