//
//  GenerateMutatorsMacro.swift
//  ProjectMacros
//
//  Created by Bartłomiej Bukowiecki on 26/10/2024.
//

import Foundation
import SwiftSyntax
import SwiftDiagnostics
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import SwiftCompilerPlugin

struct GenerateMutatorsMacro: PeerMacro {
    static let coupledValueParamName = "coupledValueType"
    
    static func expansion(
      of node: AttributeSyntax,
      providingPeersOf declaration: some DeclSyntaxProtocol,
      in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let varSyntax = declaration.as(VariableDeclSyntax.self) else {
            throw DiagnosticsError(diagnostics: [
                .init(node: declaration, message: WrongDeclarationType())
            ])
        }
        
        guard let argsList = node.arguments?.as(LabeledExprListSyntax.self), let nameParamExpr = argsList.first?.as(LabeledExprSyntax.self),
              let nameParam = nameParamExpr.expression.as(StringLiteralExprSyntax.self)?.segments.first?.as(StringSegmentSyntax.self)?.content else {
            throw DiagnosticsError(diagnostics: [
                .init(node: node, message: MissingNameParameter())
            ])
        }
        
        guard varSyntax.bindingSpecifier.tokenKind != .keyword(.let) else {
            throw DiagnosticsError(diagnostics: [
                .init(node: varSyntax, message: ImmutableDeclaration())
            ])
        }
        
        guard let pattern = varSyntax.bindings.first,
                let varName = pattern.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                varSyntax.bindings.count == 1 else {
            throw DiagnosticsError.init(diagnostics: [
                .init(node: declaration, message: MissingBindings())
            ])
        }
        
        guard let typeSyntax = findType(in: pattern) else {
            throw DiagnosticsError(diagnostics: [
                .init(node: varSyntax, message: WrongVarType())
            ])
        }
        
        var coupledValueTypeName: String?
        var coupledValueVarName: String?
        var declarations = [DeclSyntax]()
        
        if let coupledValueExpr = argsList.last?.as(LabeledExprSyntax.self), let paramLabel = coupledValueExpr.label,
           paramLabel.text == coupledValueParamName, let typeExpression = coupledValueExpr.expression.as(MemberAccessExprSyntax.self),
           let typeName = typeExpression.base?.as(DeclReferenceExprSyntax.self)?.baseName.text {
            coupledValueTypeName = typeName
            
            let name = "\(varName)_\(typeName)"
            coupledValueVarName = name
            let variableDecl = try VariableDeclSyntax("private(set) var \(raw: name): \(raw: typeName)?")
            declarations.append(variableDecl.cast(DeclSyntax.self))
        }
        
        let mutators = makeMutators(variableName: varName, nameParam: nameParam.text, isNonBoolParam: !typeSyntax.is(IdentifierTypeSyntax.self),
                                    paramType: typeSyntax, valueTypeName: coupledValueTypeName, valueTypeVarName: coupledValueVarName)
            .map { $0.cast(DeclSyntax.self) }
        declarations.append(contentsOf: mutators)
        
        return declarations
    }
    
    private static func findType(in syntax: PatternBindingSyntax) -> (any TypeSyntaxProtocol)? {
        if let initializer = syntax.initializer, initializer.value.is(BooleanLiteralExprSyntax.self) {
            return IdentifierTypeSyntax(name: .identifier("Bool"))
        }
        
        guard let typeAnnotation = syntax.typeAnnotation else { return nil }
        
        if let typeName = typeAnnotation.type.as(IdentifierTypeSyntax.self), typeName.name.text == "Bool" {
            return IdentifierTypeSyntax(name: .identifier("Bool"))
        }
        
        if let optionalType = typeAnnotation.type.as(OptionalTypeSyntax.self) {
            return optionalType.detached
        }
        
        return nil
    }
    
    private static func makeMutators(variableName: String, nameParam: String,
                                     isNonBoolParam: Bool, paramType: (any TypeSyntaxProtocol)?,
                                     valueTypeName: String?, valueTypeVarName: String?) -> [FunctionDeclSyntax] {
        var parametersList = [FunctionParameterSyntax]()
        var showBlockItems = [CodeBlockItemSyntax]()
        var hideBlockItems = [CodeBlockItemSyntax]()
        let modifiers = DeclModifierListSyntax([
            DeclModifierSyntax(name: .keyword(.mutating))
        ])
        
        if let paramType, isNonBoolParam {
            let cleanType = paramType.as(OptionalTypeSyntax.self).flatMap { $0.wrappedType } ?? paramType
            parametersList.append(FunctionParameterSyntax(firstName: .wildcardToken(), secondName: .identifier("value"), type: cleanType,
                                                          trailingComma: valueTypeName != nil && valueTypeVarName != nil ? .commaToken() : nil))
        }
        
        let paramAssigmentExpression = MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: .keyword(.self)),
            declName: DeclReferenceExprSyntax(baseName: .identifier(variableName))
        )
        
        if isNonBoolParam {
            showBlockItems.append(.init(item: .expr(InfixOperatorExprSyntax(
                leftOperand: paramAssigmentExpression,
                operator: AssignmentExprSyntax(),
                rightOperand: DeclReferenceExprSyntax(baseName: .identifier("value"))
            ).cast(ExprSyntax.self))))
        } else {
            showBlockItems.append(.init(item: .expr(InfixOperatorExprSyntax(
                leftOperand: paramAssigmentExpression,
                operator: AssignmentExprSyntax(),
                rightOperand: BooleanLiteralExprSyntax(literal: .keyword(.true))
            ).cast(ExprSyntax.self))))
        }
        
        if isNonBoolParam {
            hideBlockItems.append(.init(item: .expr(InfixOperatorExprSyntax(
                leftOperand: paramAssigmentExpression,
                operator: AssignmentExprSyntax(),
                rightOperand: NilLiteralExprSyntax()
            ).cast(ExprSyntax.self))))
        } else {
            hideBlockItems.append(.init(item: .expr(InfixOperatorExprSyntax(
                leftOperand: paramAssigmentExpression,
                operator: AssignmentExprSyntax(),
                rightOperand: BooleanLiteralExprSyntax(literal: .keyword(.false))
            ).cast(ExprSyntax.self))))
        }
        
        if let valueTypeName, let valueTypeVarName {
            let paramName = valueTypeName.withLowercaseFirstLetter
            let type = IdentifierTypeSyntax(name: .identifier(valueTypeName))
            parametersList.append(FunctionParameterSyntax(firstName: .identifier("with"), secondName: .identifier(paramName), type: type))
            
            showBlockItems.append(.init(item: .expr(InfixOperatorExprSyntax(
                leftOperand: MemberAccessExprSyntax(
                    base: DeclReferenceExprSyntax(baseName: .keyword(.self)),
                    declName: DeclReferenceExprSyntax(baseName: .identifier(valueTypeVarName))
                ),
                operator: AssignmentExprSyntax(),
                rightOperand: DeclReferenceExprSyntax(baseName: .identifier(paramName))
            ).cast(ExprSyntax.self))))
            
            hideBlockItems.append(.init(item: .expr(InfixOperatorExprSyntax(
                leftOperand: MemberAccessExprSyntax(
                    base: DeclReferenceExprSyntax(baseName: .keyword(.self)),
                    declName: DeclReferenceExprSyntax(baseName: .identifier(valueTypeVarName))
                ),
                operator: AssignmentExprSyntax(),
                rightOperand: NilLiteralExprSyntax()
            ).cast(ExprSyntax.self))))
        }
        
        let showFuncSyntax = FunctionDeclSyntax(
            modifiers: modifiers, name: .identifier("show\(nameParam)"), signature: .init(parameterClause: .init(parameters: .init(parametersList))),
            body: CodeBlockSyntax(statements: .init(showBlockItems))
        )
        let hideFuncSyntax = FunctionDeclSyntax(
            modifiers: modifiers, name: .identifier("hide\(nameParam)"), signature: .init(parameterClause: .init(parameters: .init())),
            body: CodeBlockSyntax(statements: .init(hideBlockItems))
        )
        
        return [showFuncSyntax, hideFuncSyntax]
    }
}

extension GenerateMutatorsMacro {
    struct WrongDeclarationType: DiagnosticMessage {
        let message = "You can attach this macro only to variable declarations!"
        let diagnosticID = MessageID(domain: "project.macros", id: "1")
        let severity = DiagnosticSeverity.error
    }
    
    struct MissingNameParameter: DiagnosticMessage {
        let message = "Missing name parameter!"
        let diagnosticID = MessageID(domain: "project.macros", id: "2")
        let severity = DiagnosticSeverity.error
    }
    
    struct ImmutableDeclaration: DiagnosticMessage {
        let message = "You can't use macro on immutable variable!"
        let diagnosticID = MessageID(domain: "project.macros", id: "3")
        let severity = DiagnosticSeverity.error
    }
    
    struct MissingBindings: DiagnosticMessage {
        let message = "You have to define initializer for variable!"
        let diagnosticID = MessageID(domain: "project.macros", id: "4")
        let severity = DiagnosticSeverity.error
    }
    
    struct WrongVarType: DiagnosticMessage {
        let message = "You can attach this macro only to variables with types of: Bool, Optional<T>, T?"
        let diagnosticID = MessageID(domain: "project.macros", id: "5")
        let severity = DiagnosticSeverity.error
    }
}
