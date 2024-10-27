//
//  GenerateAbstractionKeyMacro.swift
//
//
//  Created by Bartłomiej Bukowiecki on 04/08/2024.
//

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

struct GenerateAbstractionKeyMacro: DeclarationMacro {
    static let typeSuffix = "Key"
    
    static func expansion(
      of node: some FreestandingMacroExpansionSyntax,
      in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let (typeName, liveArgs, testableArgs) = try parseArgs(node.argumentList)
        
        let keySyntax = try EnumDeclSyntax("enum \(raw: typeName)\(raw: typeSuffix): DependencyKey") {
            makeValueSyntax(with: "liveValue", typeName: typeName, baseTypeName: typeName, args: liveArgs)
            IfConfigDeclSyntax(clauses: .init([
                IfConfigClauseSyntax(poundKeyword: .poundIfToken(), condition: DeclReferenceExprSyntax(baseName: .identifier("DEBUG")),
                                     elements: .decls(MemberBlockItemListSyntax([
                                        .init(decl: makeValueSyntax(with: "previewValue", 
                                                                    typeName: "\(typeName).\(GenerateTestableAbstractionMacro.childObjectNamePrefix)\(typeName)",
                                                                    baseTypeName: typeName, args: testableArgs))
                                     ])))
            ]))
        }
        
        let keyAccessorSyntax = makeAccessorSyntax(for: typeName)
        
        return [keySyntax.cast(DeclSyntax.self), keyAccessorSyntax.cast(DeclSyntax.self)]
    }
    
    private static func parseArgs(_ args: LabeledExprListSyntax) throws -> (String, [ExprSyntax], [ExprSyntax]) {
        var typeName = ""
        var liveObjArgs: [ExprSyntax] = []
        var testableObjArgs: [ExprSyntax] = []
        var isReadingLiveObjArgs = false
        var isReadingTestableObjArgs = false
        
        for arg in args {
            if let label = arg.label {
                if label.tokenKind == .identifier("for"),
                    let typeDecl = arg.expression.as(MemberAccessExprSyntax.self)?.base?.as(DeclReferenceExprSyntax.self) {
                    typeName = typeDecl.baseName.trimmed.text
                } else if label.tokenKind == .identifier("liveArgs") {
                    isReadingLiveObjArgs = true
                    isReadingTestableObjArgs = false
                    
                    liveObjArgs.append(arg.expression)
                } else if label.tokenKind == .identifier("testableArgs") {
                    isReadingLiveObjArgs = false
                    isReadingTestableObjArgs = true
                    
                    testableObjArgs.append(arg.expression)
                }
                
                continue
            }
            
            guard isReadingLiveObjArgs || isReadingTestableObjArgs else { continue }
            
            if isReadingLiveObjArgs {
                liveObjArgs.append(arg.expression)
            } else if isReadingTestableObjArgs {
                testableObjArgs.append(arg.expression)
            }
        }
        
        return (typeName, liveObjArgs, testableObjArgs)
    }
    
    private static func makeValueSyntax(with name: String, typeName: String, baseTypeName: String,
                                        args: [ExprSyntax]) -> VariableDeclSyntax {
        let initExpressions = args.enumerated().map {
            LabeledExprSyntax(expression: $0.element, trailingComma: $0.offset == (args.count - 1) ? nil : .commaToken())
        }
        let liveVarInit = InitializerClauseSyntax(
            value: FunctionCallExprSyntax(calledExpression: DeclReferenceExprSyntax(baseName: .identifier(typeName)),
                                          leftParen: .leftParenToken(),
                                          arguments: LabeledExprListSyntax(initExpressions),
                                          rightParen: .rightParenToken())
        )
        let liveVarBinding = PatternBindingSyntax(
            pattern: IdentifierPatternSyntax(identifier: .identifier(name)),
            typeAnnotation: TypeAnnotationSyntax(type: IdentifierTypeSyntax(name: .identifier("any \(baseTypeName).\(GenerateTestableAbstractionMacro.abstractionProtocolName)"))),
            initializer: liveVarInit
        )
        return VariableDeclSyntax(modifiers: DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(.static))]),
                                  bindingSpecifier: .keyword(.var),
                                  bindings: PatternBindingListSyntax([liveVarBinding]))
    }
    
    private static func makeAccessorSyntax(for typeName: String) -> VariableDeclSyntax {
        let getSubscript = SubscriptCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: .keyword(.self)),
            arguments: LabeledExprListSyntax([
                LabeledExprSyntax(
                    expression: MemberAccessExprSyntax(base: DeclReferenceExprSyntax(baseName: .identifier("\(typeName)\(typeSuffix)")),
                                                       declName: DeclReferenceExprSyntax(baseName: .keyword(.self)))
                )
            ]))
        let setExp = InfixOperatorExprSyntax(leftOperand: getSubscript, operator: AssignmentExprSyntax(),
                                             rightOperand: DeclReferenceExprSyntax(baseName: .identifier("newValue")))
        let accessor = try AccessorDeclListSyntax {
            AccessorDeclSyntax(accessorSpecifier: .keyword(.get),
                               body: CodeBlockSyntax(statements: CodeBlockItemListSyntax([
                                CodeBlockItemSyntax(item: .expr(getSubscript.cast(ExprSyntax.self)))
                               ])))
            AccessorDeclSyntax(accessorSpecifier: .keyword(.set),
                               body: CodeBlockSyntax(statements: CodeBlockItemListSyntax([
                                CodeBlockItemSyntax(item: .expr(setExp.cast(ExprSyntax.self)))
                               ])))
        }
        
        let varName = String(typeName.map { $0 }.enumerated().compactMap { $0.offset == 0 ? $0.element.lowercased().first : $0.element })
        let typeSyntax = TypeAnnotationSyntax(type: IdentifierTypeSyntax(name: .identifier("any \(typeName).\(GenerateTestableAbstractionMacro.abstractionProtocolName)")))
        let pattern = PatternBindingSyntax(
            pattern: IdentifierPatternSyntax(identifier: .identifier(varName)),
            typeAnnotation: typeSyntax,
            accessorBlock: AccessorBlockSyntax(accessors: .accessors(accessor))
        )
        return VariableDeclSyntax(bindingSpecifier: .keyword(.var), bindings: PatternBindingListSyntax([pattern]))
    }
}

extension GenerateAbstractionKeyMacro {
    struct PrintDiagnostic: DiagnosticMessage {
        var message: String
        let diagnosticID: MessageID = .init(domain: "GenerateAbstractionKeyMacro", id: "1")
        let severity: DiagnosticSeverity = .error
        
        init(message: String) {
            self.message = message
        }
    }
}
