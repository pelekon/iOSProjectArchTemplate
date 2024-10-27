//
//  BindTargetMacro.swift
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

struct BindTargetMacro: PeerMacro {
    static func expansion(
      of node: AttributeSyntax,
      providingPeersOf declaration: some DeclSyntaxProtocol,
      in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
            throw DiagnosticsError(diagnostics: [
                .init(node: declaration, message: WrongParentType())
            ])
        }
        
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else { return [] }
        
        guard let typeName = varDecl.typeName else {
            throw DiagnosticsError(diagnostics: [
                .init(node: declaration, message: FailedToDetermineObjectType())
            ])
        }
        
        guard let firstArgs = arguments.first?.as(LabeledExprSyntax.self),
              let argTuple = firstArgs.expression.as(TupleExprSyntax.self),
              let keyPath =  argTuple.elements.first?.expression.as(KeyPathExprSyntax.self),
              let targetType = keyPath.root?.as(IdentifierTypeSyntax.self)?.name.text else {
            throw DiagnosticsError(diagnostics: [
                .init(node: declaration, message: ObjectTypeMismatch(expectedType: typeName))
            ])
        }
        
        return []
    }
}

extension BindTargetMacro {
    struct WrongParentType: DiagnosticMessage {
        let message = "Macro can be used only on variable declarations."
        let diagnosticID = MessageID(domain: "project.macros", id: "1")
        let severity = DiagnosticSeverity.error
    }
    
    struct FailedToDetermineObjectType: DiagnosticMessage {
        let message = "Failed to determine variable type."
        let diagnosticID = MessageID(domain: "project.macros", id: "2")
        let severity = DiagnosticSeverity.error
    }
    
    struct ObjectTypeMismatch: DiagnosticMessage {
        let message: String
        let diagnosticID = MessageID(domain: "project.macros", id: "3")
        let severity = DiagnosticSeverity.error
        
        init(expectedType: String) {
            self.message = "Macro provided arguments are refering to diferent type. Expected keypaths of type: \(expectedType)"
        }
    }
}
