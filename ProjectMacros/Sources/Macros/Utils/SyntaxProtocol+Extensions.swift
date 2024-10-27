//
//  SyntaxProtocol+Extensions.swift
//
//
//  Created by Bartłomiej Bukowiecki on 03/08/2024.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension SyntaxProtocol {
    var isPublicDecl: Bool {
        return modifiersOfSyntax?.hasKeyword(of: .keyword(.public), with: nil) ?? false
    }
    
    var isPrivateDecl: Bool {
        return modifiersOfSyntax?.hasKeyword(of: .keyword(.private), with: nil) ?? false
    }
    
    var isInoutType: Bool {
        self.as(AttributedTypeSyntax.self)?.specifier?.tokenKind == .keyword(.inout)
    }
    
    fileprivate var modifiersOfSyntax: DeclModifierListSyntax? {
        if let structDecl = self.as(StructDeclSyntax.self) {
            return structDecl.modifiers
        } else if let classDecl = self.as(ClassDeclSyntax.self) {
            return classDecl.modifiers
        } else if let enumDecl = self.as(EnumDeclSyntax.self) {
            return enumDecl.modifiers
        } else if let varDecl = self.as(VariableDeclSyntax.self) {
            return varDecl.modifiers
        } else if let protocolDecl = self.as(ProtocolDeclSyntax.self) {
            return protocolDecl.modifiers
        } else if let typealiasDecl = self.as(TypealiasDeclSyntax.self) {
            return typealiasDecl.modifiers
        } else if let funcDecl = self.as(FunctionDeclSyntax.self) {
            return funcDecl.modifiers
        } else if let actorDecl = self.as(ActorDeclSyntax.self) {
            return actorDecl.modifiers
        }
        
        return nil
    }
}
