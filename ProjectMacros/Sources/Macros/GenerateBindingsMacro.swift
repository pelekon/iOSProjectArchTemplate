//
//  GenerateBindingsMacro.swift
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

struct GenerateBindingsMacro: MemberMacro {
    static let varMacroName = "BindTarget"
    static let funcMacroName = "Bindable"
    static let flagName = "makeNonFunctionBindings"
    
    static func expansion(
      of node: AttributeSyntax,
      providingMembersOf declaration: some DeclGroupSyntax,
      in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        //        pause()
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw DiagnosticsError(diagnostics: [
                .init(node: declaration, message: WrongParentType())
            ])
        }
        
        let makeNonFuncBindigns = canMakeNonFuncBindigns(from: node)
        var targetableVariables = [BindingTarget]()
        var functionsForBindings = [BindingSource]()
        
        try classDecl.memberBlock.members.forEach {
            if let varMember = $0.decl.as(VariableDeclSyntax.self),
               let macroAttribute = varMember.attributes.firstAttribute(of: .identifier(varMacroName)),
               let typeName = varMember.typeName,
               let varName = varMember.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text {
                
                if let names = extractVariableNames(from: macroAttribute) {
                    let target = BindingTarget(variableName: varName, typeName: typeName, variables: names)
                    targetableVariables.append(target)
                } else {
                    throw DiagnosticsError(diagnostics: [
                        .init(node: declaration, message: BindTargetVariableNamesExtractFailure(varName: varName))
                    ])
                }
            } else if let funcMember = $0.decl.as(FunctionDeclSyntax.self),
                      let macroAttribute = funcMember.attributes.firstAttribute(of: .identifier(funcMacroName)) {
                if let source = makeSource(from: funcMember, with: macroAttribute) {
                    functionsForBindings.append(source)
                } else {
                    throw DiagnosticsError(diagnostics: [
                        .init(node: declaration, message: BindSourceInfoExtractFailure(funcName: funcMember.name.text))
                    ])
                }
            }
        }
        
        return try makeBindings(for: targetableVariables, with: functionsForBindings, makeNonFuncBindigns: makeNonFuncBindigns)
//        var variables = Dictionary<String, VariableDeclSyntax>()
//        var functions = [FunctionDeclSyntax]()
//        classDecl.memberBlock.members.forEach {
//            guard let itemDecl = $0.as(MemberBlockItemSyntax.self) else { return }
//            if let varDecl = itemDecl.decl.as(VariableDeclSyntax.self), let typeName = varDecl.typeName {
//                if !variables.keys.contains(typeName) {
//                    variables[typeName] = varDecl
//                }
//            } else if let funcDecl = itemDecl.decl.as(FunctionDeclSyntax.self) {
//                functions.append(funcDecl)
//            }
//        }
//        
//        let bindings = try arguments.map {
//            try parseBinding(for: $0, variables: variables, functions: functions).cast(DeclSyntax.self)
//        }
//        
//        return bindings
    }
    
    private static func canMakeNonFuncBindigns(from attribute: AttributeSyntax) -> Bool {
        guard let attributes = attribute.arguments?.as(LabeledExprListSyntax.self),
              let arg = attributes.first(where: { $0.label?.text == flagName }) else {
            return false
        }
        
        return arg.expression.as(BooleanLiteralExprSyntax.self)?.literal.text == "true"
    }
    
    private static func extractVariableNames(from attribute: AttributeSyntax) -> [BindingTarget.Variable]? {
        guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self) else {
            return nil
        }
        
        return arguments
            .compactMap { $0.expression.as(TupleExprSyntax.self)?.elements }
            .compactMap { (list: LabeledExprListSyntax) in
                guard let keyPathExp = list.first?.expression.as(KeyPathExprSyntax.self) else { return nil }
                guard let typeExpr = list.last?.expression.as(MemberAccessExprSyntax.self)?.base?.as(DeclReferenceExprSyntax.self) else { return nil }
                
                return (typeExpr, keyPathExp)
            }
            .compactMap { (tuple: (DeclReferenceExprSyntax, KeyPathExprSyntax)) -> (DeclReferenceExprSyntax, KeyPathPropertyComponentSyntax)? in
                guard let propertyName = tuple.1.components.first?.component.as(KeyPathPropertyComponentSyntax.self) else { return nil }
                
                return (tuple.0, propertyName)
            }
            .map { .init(name: $0.1.declName.baseName.text, typeName: $0.0.baseName.text) }
    }
    
    private static func makeSource(from funcDecl: FunctionDeclSyntax, with attribute: AttributeSyntax) -> BindingSource? {
        guard let funcArgument = funcDecl.signature.parameterClause.parameters.first,
              let argType = funcArgument.type.as(IdentifierTypeSyntax.self)?.name.text else {
            return nil
        }
        
        guard let attriArg = attribute.arguments?.as(LabeledExprListSyntax.self)?.first,
              let keyPathExpr = attriArg.expression.as(KeyPathExprSyntax.self),
              let rootType = keyPathExpr.root?.as(IdentifierTypeSyntax.self)?.name.text,
              let rootVarName = keyPathExpr.components.first?.component.as(KeyPathPropertyComponentSyntax.self)?.declName.baseName.text else {
            return nil
        }
        
        let argLabel = funcArgument.firstName.text
        
        return BindingSource(functionName: funcDecl.name.text, targetTypeName: rootType, targetVariableName: rootVarName,
                             argumentLabel: argLabel, valueTypeName: argType)
    }
    
    private static func makeBindings(for variables: [BindingTarget], with functions: [BindingSource],
                                     makeNonFuncBindigns: Bool) throws -> [DeclSyntax] {
        var targets = variables
        var declarations = [DeclSyntax]()
        
        for source in functions {
            let targetIndex = targets.firstIndex { target in
                target.typeName == source.targetTypeName && target.variables.contains { $0.name == source.targetVariableName}
            }
            guard let targetIndex else { continue }
            
            var target = targets[targetIndex]
            let syntax = try makeFuncBinding(source: source, target: target)
            declarations.append(syntax)
            
            target.removeVariable(with: source.targetVariableName)
            targets[targetIndex] = target
        }
        
        if makeNonFuncBindigns {
            try targets.forEach { target in
                try target.variables.forEach {
                    let binding = try makeVarBinding(target: target, variable: $0)
                    declarations.append(binding)
                }
            }
        }
        
        return declarations
    }
    
    private static func makeFuncBinding(source: BindingSource, target: BindingTarget) throws -> DeclSyntax {
        let bindingName = "bind\(target.variableName.withUppercaseFirstLetter)\(source.targetVariableName.withUppercaseFirstLetter)"
        return try VariableDeclSyntax("""
                var \(raw: bindingName): Binding<\(raw: source.valueTypeName)> {
                    .init {
                        return self[keyPath: \\.\(raw: target.variableName).\(raw: source.targetVariableName)]
                    } set: { newValue in
                        self.\(raw: source.functionName)(\(raw: source.argumentLabel): newValue)
                    }
                }
                """).cast(DeclSyntax.self)
    }
    
    private static func makeVarBinding(target: BindingTarget, variable: BindingTarget.Variable) throws -> DeclSyntax {
        let bindingName = "bind\(target.variableName.withUppercaseFirstLetter)\(variable.name.withUppercaseFirstLetter)"
        return try VariableDeclSyntax("""
                var \(raw: bindingName): Binding<\(raw: variable.typeName)> {
                    .init {
                        return self[keyPath: \\.\(raw: target.variableName).\(raw: variable.name)]
                    } set: { newValue in
                        self[keyPath: \\.\(raw: target.variableName).\(raw: variable.name)] = newValue
                    }
                }
                """).cast(DeclSyntax.self)
    }
    
//    private static func parseBinding(for argument: LabeledExprSyntax,
//                                     variables: Dictionary<String, VariableDeclSyntax>,
//                                     functions: [FunctionDeclSyntax]) throws -> VariableDeclSyntax {
//        guard let bindingExpr = argument.expression.as(FunctionCallExprSyntax.self),
//              let bindingType = bindingExpr.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text else {
//            throw DiagnosticsError(diagnostics: [
//                .init(node: argument, message: BindingDeclarationError())
//            ])
//        }
//        
//        return switch bindingType {
//        case "withMutator":
//            try makeMutatorBinding(for: bindingExpr.arguments, variables: variables, functions: functions)
//        case "simple":
//            try makeSimpleBinding(for: bindingExpr.arguments, variables: variables)
//        default:
//            throw DiagnosticsError(diagnostics: [
//                .init(node: argument, message: BindingTypeNotImplemented())
//            ])
//        }
//    }
//    
//    private static func makeSimpleBinding(for arguments: LabeledExprListSyntax,
//                                          variables: Dictionary<String, VariableDeclSyntax>) throws -> VariableDeclSyntax {
//        guard let targetTypeExpr = arguments.first?.expression.as(KeyPathExprSyntax.self),
//              let targetType = targetTypeExpr.root?.as(IdentifierTypeSyntax.self)?.name.text,
//              let targetVarName = targetTypeExpr.components.first?.component.as(KeyPathPropertyComponentSyntax.self)?.declName.baseName.text,
//              let varType = arguments.last?.expression.as(MemberAccessExprSyntax.self)?.base?.as(DeclReferenceExprSyntax.self)?.baseName.text else {
//            throw DiagnosticsError(diagnostics: [
//                .init(node: arguments, message: BindingDeclarationError())
//            ])
//        }
//        
//        guard let varDecl = variables[targetType] else {
//            throw DiagnosticsError(diagnostics: [
//                .init(node: arguments, message: BindingTargetNotFound(targetTypeName: targetType))
//            ])
//        }
//        
//        guard let varNameSyntax = varDecl.bindings.first?.pattern.as(IdentifierPatternSyntax.self) else {
//            throw DiagnosticsError(diagnostics: [
//                .init(node: arguments, message: BindingTargetNotFound(targetTypeName: targetType))
//            ])
//        }
//        
//        let bindingVarName = "bind\(varNameSyntax.identifier.text.withUppercaseFirstLetter)\(targetVarName.withUppercaseFirstLetter)"
//        
//        return try VariableDeclSyntax("""
//        var \(raw: bindingVarName): Binding<\(raw: varType)> {
//            .init { 
//                return self[keyPath: \\.\(raw: varNameSyntax.identifier.text).\(raw: targetVarName)]
//            } set: { newValue in
//                self[keyPath: \\.\(raw: varNameSyntax.identifier.text).\(raw: targetVarName)] = newValue
//            }
//        }
//        """)
//    }
//    
//    private static func makeMutatorBinding(for arguments: LabeledExprListSyntax,
//                                           variables: Dictionary<String, VariableDeclSyntax>,
//                                           functions: [FunctionDeclSyntax]) throws -> VariableDeclSyntax {
//        guard let targetTypeExpr = arguments.first?.expression.as(KeyPathExprSyntax.self),
//              let targetType = targetTypeExpr.root?.as(IdentifierTypeSyntax.self)?.name.text,
//              let targetVarName = targetTypeExpr.components.first?.component.as(KeyPathPropertyComponentSyntax.self)?.declName.baseName.text,
//              let varType = arguments.last?.expression.as(MemberAccessExprSyntax.self)?.base?.as(DeclReferenceExprSyntax.self)?.baseName.text else {
//            throw DiagnosticsError(diagnostics: [
//                .init(node: arguments, message: BindingDeclarationError())
//            ])
//        }
//        
//        guard let varDecl = variables[targetType] else {
//            throw DiagnosticsError(diagnostics: [
//                .init(node: arguments, message: BindingTargetNotFound(targetTypeName: targetType))
//            ])
//        }
//        
//        guard let varNameSyntax = varDecl.bindings.first?.pattern.as(IdentifierPatternSyntax.self) else {
//            throw DiagnosticsError(diagnostics: [
//                .init(node: arguments, message: BindingTargetNotFound(targetTypeName: targetType))
//            ])
//        }
//        
//        let matchingFuncDecls = functions.filter {
//            isFunctionTargetOfBinding($0, targetTypeName: varType, macroTargetVarName: varNameSyntax.identifier.text, bindTargetVarName: targetVarName)
//        }
//        
//        guard matchingFuncDecls.count < 2 else {
//            throw DiagnosticsError(diagnostics: [
//                .init(node: arguments, message: TooManyMatchingFunctionsMatching())
//            ])
//        }
//        
//        guard let funcDecl = matchingFuncDecls.first else {
//            throw DiagnosticsError(diagnostics: [
//                .init(node: arguments, message: FunctionForBindingNotFound())
//            ])
//        }
//        
//        guard let paramSyntax = funcDecl.signature.parameterClause.parameters.first else {
//            throw DiagnosticsError(diagnostics: [
//                .init(node: arguments, message: FunctionArgumentLabelNotDetermined())
//            ])
//        }
//        
//        let bindingVarName = "bind\(varNameSyntax.identifier.text.withUppercaseFirstLetter)\(targetVarName.withUppercaseFirstLetter)"
//        
//        return try VariableDeclSyntax("""
//        var \(raw: bindingVarName): Binding<\(raw: varType)> {
//            .init { 
//                return self[keyPath: \\.\(raw: varNameSyntax.identifier.text).\(raw: targetVarName)]
//            } set: { newValue in
//                self.\(raw: funcDecl.name.text)(\(raw: paramSyntax.firstName.text): newValue)
//            }
//        }
//        """)
//    }
//    
//    private static func isFunctionTargetOfBinding(_ decl: FunctionDeclSyntax, targetTypeName: String,
//                                                  macroTargetVarName: String, bindTargetVarName: String) -> Bool {
//        guard decl.signature.returnClause == nil else { return false }
//        let hasArgWithMatchingType = decl.signature.parameterClause.parameters.count == 1 && decl.signature.parameterClause.parameters.contains {
//            ($0.as(FunctionParameterSyntax.self)?.type.as(IdentifierTypeSyntax.self)?.name.text ?? "") == targetTypeName
//        }
//        
//        guard hasArgWithMatchingType, let codeBlock = decl.body else { return false }
//        
//        let hasValidStatement = codeBlock.statements
//            .compactMap { $0.as(CodeBlockItemSyntax.self) }
//            .compactMap { $0.item.as(FunctionCallExprSyntax.self) }
//            .contains { isFunctionStatementMatching($0, macroTargetVarName: macroTargetVarName) }
//        
//        return hasValidStatement
//    }
//    
//    private static func isFunctionStatementMatching(_ stmt: FunctionCallExprSyntax,
//                                                    macroTargetVarName: String) -> Bool {
//        guard let memberExpr = stmt.calledExpression.as(MemberAccessExprSyntax.self) else { return false }
//        var isUsingMacroTarget = false
//        if let nameRef = memberExpr.base?.as(DeclReferenceExprSyntax.self) {
//            isUsingMacroTarget = nameRef.baseName.text == macroTargetVarName
//            
//        } else if let nameAccessor = memberExpr.base?.as(MemberAccessExprSyntax.self),
//                  let baseRef = nameAccessor.base?.as(DeclReferenceExprSyntax.self), baseRef.baseName.tokenKind == .keyword(.Self) {
//            isUsingMacroTarget = nameAccessor.declName.baseName.text == macroTargetVarName
//        }
//        
//        return isUsingMacroTarget && stmt.arguments.count == 1
//    }
}

extension GenerateBindingsMacro {
    struct BindingTarget {
        struct Variable {
            let name: String
            let typeName: String
        }
        
        let variableName: String
        let typeName: String
        private(set) var variables: [Variable]
        
        mutating func removeVariable(with name: String) {
            self.variables.removeAll { $0.name == name }
        }
    }
    
    struct BindingSource {
        let functionName: String
        let targetTypeName: String
        let targetVariableName: String
        let argumentLabel: String
        let valueTypeName: String
    }
}

extension GenerateBindingsMacro {
    struct WrongParentType: DiagnosticMessage {
        let message = "You can attach this macro only to class!"
        let diagnosticID = MessageID(domain: "project.macros", id: "1")
        let severity = DiagnosticSeverity.error
    }
    
    struct BindTargetVariableNamesExtractFailure: DiagnosticMessage {
        let message: String
        let diagnosticID = MessageID(domain: "project.macros", id: "1")
        let severity = DiagnosticSeverity.error
        
        init(varName: String) {
            self.message = "Failed to extract variable names from: \(varName)."
        }
    }
    
    struct BindSourceInfoExtractFailure: DiagnosticMessage {
        let message: String
        let diagnosticID = MessageID(domain: "project.macros", id: "1")
        let severity = DiagnosticSeverity.error
        
        init(funcName: String) {
            self.message = "Failed to extract required information from: \(funcName)."
        }
    }
}
