//
//  GenerateTestableAbstractionMacro.swift
//
//
//  Created by Bartłomiej Bukowiecki on 28/07/2024.
//

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

struct GenerateTestableAbstractionMacro: MemberMacro {
    static let abstractionProtocolName = "AnyImpl"
    static let childObjectNamePrefix = "Testable"
    static let testableObjFuncHandlerVarSuffix = "Handler"
    static let ignoreMacroName = "IgnoreForImpl"
    
    static func expansion(
      of node: AttributeSyntax,
      providingMembersOf declaration: some DeclGroupSyntax,
      in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(ClassDeclSyntax.self) || declaration.is(StructDeclSyntax.self) else {
            throw DiagnosticsError(diagnostics: [
                .init(node: declaration, message: IncorrectObjectKindMessage())
            ])
        }
        
        if declaration.isPrivateDecl {
            throw DiagnosticsError(diagnostics: [.init(node: declaration, message: PrivateInvokeMessage())])
        }
        
        let declName = declaration.as(ClassDeclSyntax.self)?.name.trimmed.text ?? declaration.as(StructDeclSyntax.self)?.name.trimmed.text ?? ""
        let isDeclPublic = declaration.isPublicDecl
        
        return [
            try makeAbstractionDecl(with: declaration.memberBlock, isDeclPublic: isDeclPublic, 
                                    macroContext: context).cast(DeclSyntax.self),
            try makeTestableObjectDecl(with: declName, for: declaration.memberBlock, isDeclPublic: isDeclPublic,
                                       isParentAStruct: declaration.is(StructDeclSyntax.self), macroContext: context).cast(DeclSyntax.self)
        ]
    }
    
    private static func makeAbstractionDecl(with memberBlock: MemberBlockSyntax, isDeclPublic: Bool, 
                                            macroContext: some MacroExpansionContext) throws -> ProtocolDeclSyntax {
        let members = memberBlock.members.compactMap {
            if let varDecl = $0.decl.as(VariableDeclSyntax.self) {
                return parseVariable(varDecl, forProtocol: true, isDeclPublic: isDeclPublic)
            }
            if let funcDecl = $0.decl.as(FunctionDeclSyntax.self) {
                return parseFunc(funcDecl, forProtocol: true, isDeclPublic: isDeclPublic, macroContext: macroContext)
            }
            
            return nil
        }.flatMap { $0 }
        
        var modifiers = [DeclModifierSyntax]()
        if isDeclPublic {
            modifiers.append(DeclModifierSyntax(name: .keyword(.public)))
        }
        
        let membersSyntax = MemberBlockSyntax(members: MemberBlockItemListSyntax(members))
        return try ProtocolDeclSyntax(modifiers: .init(modifiers),
                                      name: .identifier(abstractionProtocolName),
                                      memberBlock: membersSyntax)
    }
    
    private static func makeTestableObjectDecl(with name: String, for memberBlock: MemberBlockSyntax, isDeclPublic: Bool, 
                                               isParentAStruct: Bool, macroContext: some MacroExpansionContext) throws -> DeclSyntax {
        let inheritanceSyntax = InheritanceClauseSyntax {
            InheritedTypeSyntax(typeName: TypeSyntax(stringLiteral: abstractionProtocolName))
        }
        var members = memberBlock.members.compactMap {
            if let varDecl = $0.decl.as(VariableDeclSyntax.self) {
                return parseVariable(varDecl, forProtocol: false, isDeclPublic: isDeclPublic)
            }
            if let funcDecl = $0.decl.as(FunctionDeclSyntax.self) {
                return parseFunc(funcDecl, forProtocol: false, isDeclPublic: isDeclPublic, macroContext: macroContext)
            }
            
            return nil
        }.flatMap { $0 }
        
        var modifiers = [DeclModifierSyntax]()
        
        if isDeclPublic {
            modifiers.append(DeclModifierSyntax(name: .keyword(.public)))
        }
        
        var initParams = members.compactMap {
            $0.decl.as(VariableDeclSyntax.self)?.bindings
        }.flatMap {
            $0
        }.compactMap { (binding: PatternBindingSyntax) -> FunctionParameterSyntax? in
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self), let type = binding.typeSyntax else { return nil }
            let isClosure = binding.typeAnnotation?.type.is(FunctionTypeSyntax.self) ?? false
            
            let typeSyntax: any TypeSyntaxProtocol = isClosure ? AttributedTypeSyntax(attributes: AttributeListSyntax {
                AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier("escaping")))
            }, baseType: type.type) : type.type
            return FunctionParameterSyntax(firstName: pattern.identifier.detached, type: typeSyntax)
        }
        initParams = initParams.enumerated().map {
            FunctionParameterSyntax(firstName: $0.element.firstName, type: $0.element.type, 
                                    trailingComma: $0.offset == (initParams.count - 1) ? nil : .commaToken())
        }
        
        let initSignature = FunctionSignatureSyntax(parameterClause: FunctionParameterClauseSyntax(parameters: FunctionParameterListSyntax(initParams)))
        let initStatements = initParams.map {
            let left = MemberAccessExprSyntax(base: DeclReferenceExprSyntax(baseName: .keyword(.self)), name: $0.firstName.detached)
            let right = DeclReferenceExprSyntax(baseName: $0.firstName.detached)
            return InfixOperatorExprSyntax(leftOperand: left, operator: AssignmentExprSyntax(), rightOperand: right)
        }.map {
            CodeBlockItemSyntax(item: .init($0))
        }
        let body = CodeBlockSyntax(statements: CodeBlockItemListSyntax(initStatements))
        let initSyntax = InitializerDeclSyntax(modifiers: DeclModifierListSyntax(modifiers), signature: initSignature, body: body)
        
        let emptyInitParams = initParams.map {
            FunctionParameterSyntax(firstName: .wildcardToken(), secondName: $0.firstName, type: $0.type, trailingComma: $0.trailingComma)
        }
        let emptyInitSignature = FunctionSignatureSyntax(parameterClause: FunctionParameterClauseSyntax(parameters: FunctionParameterListSyntax(emptyInitParams)))
        let emptyInitStatements = initParams.map {
            let left = MemberAccessExprSyntax(base: DeclReferenceExprSyntax(baseName: .keyword(.self)), name: $0.firstName.detached)
            let right = DeclReferenceExprSyntax(baseName: $0.firstName.detached)
            return InfixOperatorExprSyntax(leftOperand: left, operator: AssignmentExprSyntax(), rightOperand: right)
        }.map {
            CodeBlockItemSyntax(item: .init($0))
        }
        let emptyInitBody = CodeBlockSyntax(statements: CodeBlockItemListSyntax(emptyInitStatements))
        let emptyInitSyntax = InitializerDeclSyntax(modifiers: DeclModifierListSyntax(modifiers), signature: emptyInitSignature, body: emptyInitBody)
        
        members.append(.init(decl: initSyntax))
        members.append(.init(decl: emptyInitSyntax))
        let memberBlockSyntax = MemberBlockSyntax(members: MemberBlockItemListSyntax(members))
        
        let objectDecl = makeTestableObjectSyntax(modifiers: modifiers, name: name, inheritanceSyntax: inheritanceSyntax,
                                                  memberBlockSyntax: memberBlockSyntax, isParentAStruct: isParentAStruct)
        let ifSyntax = IfConfigClauseSyntax(poundKeyword: .poundIfToken(), condition: DeclReferenceExprSyntax(baseName: .identifier("DEBUG")),
                                            elements: .decls(MemberBlockItemListSyntax([.init(decl: objectDecl)])))
        return IfConfigDeclSyntax(clauses: .init([ifSyntax])).cast(DeclSyntax.self)
    }
    
    private static func makeTestableObjectSyntax(modifiers: [DeclModifierSyntax], name: String,
                                                 inheritanceSyntax: InheritanceClauseSyntax,
                                                 memberBlockSyntax: MemberBlockSyntax,
                                                 isParentAStruct: Bool) -> DeclSyntax {
        if isParentAStruct {
            return try StructDeclSyntax(modifiers: .init(modifiers),
                                                  name: .identifier(childObjectNamePrefix + name),
                                                  inheritanceClause: inheritanceSyntax,
                                                  memberBlock: memberBlockSyntax).cast(DeclSyntax.self)
        } else {
            var classModifiers = modifiers
            classModifiers.append(DeclModifierSyntax(name: .keyword(.final)))
            return try ClassDeclSyntax(modifiers: .init(classModifiers),
                                                name: .identifier(childObjectNamePrefix + name),
                                                inheritanceClause: inheritanceSyntax,
                                                memberBlock: memberBlockSyntax).cast(DeclSyntax.self)
        }
    }
    
    private static func parseVariable(_ varDecl: VariableDeclSyntax, forProtocol: Bool, isDeclPublic: Bool) -> [MemberBlockItemSyntax]? {
        guard !varDecl.isPrivateDecl else { return nil }
        guard !varDecl.attributes.hasAttribute(of: .identifier(ignoreMacroName)) else { return nil }
        guard !isDeclPublic || (isDeclPublic && varDecl.isPublicDecl) else { return nil }
        
        var items = [MemberBlockItemSyntax]()
        
        varDecl.bindings.forEach {
            guard let pattern = $0.pattern.as(IdentifierPatternSyntax.self), let type = $0.typeSyntax else { return }
            
            let varName = pattern.identifier.trimmed.text
            var varAccessors = [AccessorDeclSyntax]()
            
            if !forProtocol {
                varAccessors = []
            } else if varDecl.bindingSpecifier.tokenKind == .keyword(.let) {
                varAccessors = [.init(accessorSpecifier: .keyword(.get))]
            } else if varDecl.modifiers.hasKeyword(of: .keyword(.private), with: .identifier("set")) || $0.accessorBlock != nil {
                varAccessors = [.init(accessorSpecifier: .keyword(.get))]
            } else {
                varAccessors = [.init(accessorSpecifier: .keyword(.get)), .init(accessorSpecifier: .keyword(.set))]
            }
            
            var accessorBlock: AccessorBlockSyntax?
            if !varAccessors.isEmpty {
                accessorBlock = AccessorBlockSyntax(accessors: .init(AccessorDeclListSyntax(varAccessors)))
            }
            
            let declBindings = PatternBindingListSyntax {
                PatternBindingSyntax(pattern: IdentifierPatternSyntax(identifier: .identifier(varName)), typeAnnotation: type,
                                     accessorBlock: accessorBlock)
            }
            
            var modifiers = [DeclModifierSyntax]()
            
            if !forProtocol && isDeclPublic {
                modifiers.append(DeclModifierSyntax(name: .keyword(.public)))
            }
            
            items.append(.init(decl: VariableDeclSyntax(modifiers: DeclModifierListSyntax(modifiers), bindingSpecifier: .keyword(.var), bindings: declBindings)))
        }
        
        return items
    }
    
    private static func parseFunc(_ funcDecl: FunctionDeclSyntax, forProtocol: Bool, isDeclPublic: Bool,
                                  macroContext: some MacroExpansionContext) -> [MemberBlockItemSyntax]? {
        guard !funcDecl.isPrivateDecl else { return nil }
        guard !funcDecl.attributes.hasAttribute(of: .identifier(ignoreMacroName)) else { return nil }
        guard !isDeclPublic || (isDeclPublic && funcDecl.isPublicDecl) else { return nil }
        
        var handlerClosureSyntax: VariableDeclSyntax?
        var funcBody: CodeBlockSyntax?
        
        if !forProtocol {
            var args = funcDecl.signature.parameterClause.parameters.map {
                TupleTypeElementSyntax(type: $0.type.detached, trailingComma: .commaToken())
            }
            if !args.isEmpty {
                let lastItemIndex = args.count - 1
                args[lastItemIndex] = TupleTypeElementSyntax(type: args[lastItemIndex].type, trailingComma: nil)
            }
            let returnType = funcDecl.signature.returnClause?.type.detached ?? TypeSyntax(fromProtocol: IdentifierTypeSyntax(name: .identifier("Void")))
            let typeSyntax = TypeAnnotationSyntax(type: FunctionTypeSyntax(parameters: TupleTypeElementListSyntax(args), 
                                                                           returnClause: ReturnClauseSyntax(type: returnType)))
            let varName = TokenSyntax.identifier(funcDecl.name.trimmed.text + testableObjFuncHandlerVarSuffix)
            let pattern = PatternBindingListSyntax {
                PatternBindingSyntax(pattern: IdentifierPatternSyntax(identifier: varName),
                                     typeAnnotation: typeSyntax)
            }
            
            var modifiers = [DeclModifierSyntax]()
            
            if !forProtocol && isDeclPublic {
                modifiers.append(DeclModifierSyntax(name: .keyword(.public)))
            }
            
            handlerClosureSyntax = VariableDeclSyntax(modifiers: DeclModifierListSyntax(modifiers), bindingSpecifier: .keyword(.var), bindings: pattern)
            
            var closureArgsSyntax = funcDecl.signature.parameterClause.parameters.map {
                let refDecl = DeclReferenceExprSyntax(baseName: $0.secondName?.detached ?? $0.firstName.detached)
                
                if $0.type.isInoutType {
                    return InOutExprSyntax(expression: refDecl).cast(ExprSyntax.self)
                } else {
                    return refDecl.cast(ExprSyntax.self)
                }
            }.map {
                LabeledExprSyntax(label: nil, expression: $0, trailingComma: .commaToken())
            }
            if !closureArgsSyntax.isEmpty {
                let lastItemIndex = closureArgsSyntax.count - 1
                closureArgsSyntax[lastItemIndex] = LabeledExprSyntax(label: closureArgsSyntax[lastItemIndex].label,
                                                                     expression: closureArgsSyntax[lastItemIndex].expression,
                                                                     trailingComma: nil)
            }
            
            let closureCallSyntax = FunctionCallExprSyntax(calledExpression: DeclReferenceExprSyntax(baseName: varName),
                                                           leftParen: .leftParenToken(),
                                                           arguments: LabeledExprListSyntax(closureArgsSyntax),
                                                           rightParen: .rightParenToken())
            
            funcBody = CodeBlockSyntax(statements: CodeBlockItemListSyntax(arrayLiteral: CodeBlockItemSyntax(item: CodeBlockItemSyntax.Item(closureCallSyntax))))
        }
        
        var modifiers = [DeclModifierSyntax]()
        
        if !forProtocol && isDeclPublic {
            modifiers.append(DeclModifierSyntax(name: .keyword(.public)))
        }
        
        let signatureSyntax = FunctionSignatureSyntax(parameterClause: funcDecl.signature.parameterClause.detached,
                                                      returnClause: funcDecl.signature.returnClause?.detached)
        let funcSyntax = FunctionDeclSyntax(modifiers: DeclModifierListSyntax(modifiers), name: funcDecl.name.detached, signature: signatureSyntax, body: funcBody)
        
        return handlerClosureSyntax.flatMap { [.init(decl: $0), .init(decl: funcSyntax)] } ?? [.init(decl: funcSyntax)]
    }
}

extension GenerateTestableAbstractionMacro {
    struct PrivateInvokeMessage: DiagnosticMessage {
        let message: String = "Macro cannot be used with private declratation!"
        let diagnosticID: MessageID = .init(domain: "GenerateTestableAbstractionMacro", id: "1")
        let severity: DiagnosticSeverity = .error
    }
    
    struct IncorrectObjectKindMessage: DiagnosticMessage {
        let message: String = "Macro can be used only with classes and structs!"
        let diagnosticID: MessageID = .init(domain: "GenerateTestableAbstractionMacro", id: "2")
        let severity: DiagnosticSeverity = .error
    }
    
    struct PrintDiagnostic: DiagnosticMessage {
        var message: String
        let diagnosticID: MessageID = .init(domain: "GenerateTestableAbstractionMacro", id: "3")
        let severity: DiagnosticSeverity = .error
        
        init(message: String) {
            self.message = message
        }
    }
}
