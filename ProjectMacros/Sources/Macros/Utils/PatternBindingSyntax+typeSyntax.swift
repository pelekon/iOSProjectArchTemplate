//
//  PatternBindingSyntax+typeSyntax.swift
//
//
//  Created by Bartłomiej Bukowiecki on 03/08/2024.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension PatternBindingSyntax {
    var typeSyntax: TypeAnnotationSyntax? {
        if let syntax = typeAnnotation?.detached {
            return syntax
        }
        
        guard let initSyntax = self.initializer else { return nil }
        
        if initSyntax.value.is(BooleanLiteralExprSyntax.self) {
            return TypeAnnotationSyntax(type: IdentifierTypeSyntax(name: .identifier("Bool")))
        } else if initSyntax.value.is(FloatLiteralExprSyntax.self) {
            return TypeAnnotationSyntax(type: IdentifierTypeSyntax(name: .identifier("Float")))
        } else if initSyntax.value.is(IntegerLiteralExprSyntax.self) {
            return TypeAnnotationSyntax(type: IdentifierTypeSyntax(name: .identifier("Int")))
        } else if initSyntax.value.is(SimpleStringLiteralExprSyntax.self) {
            return TypeAnnotationSyntax(type: IdentifierTypeSyntax(name: .identifier("String")))
        } else if initSyntax.value.is(StringLiteralExprSyntax.self) {
            return TypeAnnotationSyntax(type: IdentifierTypeSyntax(name: .identifier("String")))
        } else if let exp = initSyntax.value.as(FunctionCallExprSyntax.self), let declRefSyntax = exp.calledExpression.as(DeclReferenceExprSyntax.self) {
            
            return TypeAnnotationSyntax(type: IdentifierTypeSyntax(name: .identifier(declRefSyntax.baseName.trimmed.text)))
        }
        
        return nil
    }
}
