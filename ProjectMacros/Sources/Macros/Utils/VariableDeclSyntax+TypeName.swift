//
//  VariableDeclSyntax+TypeName.swift
//  ProjectMacros
//
//  Created by Bartłomiej Bukowiecki on 27/10/2024.
//

import SwiftSyntax

extension VariableDeclSyntax {
    var typeName: String? {
        guard let pattern = self.bindings.first else { return nil }
        
        if let typeAnnotation = pattern.typeAnnotation?.type.as(IdentifierTypeSyntax.self) {
            return typeAnnotation.name.text
        } else if let initExpr = pattern.initializer?.value.as(FunctionCallExprSyntax.self),
           let typeName = initExpr.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text {
            return typeName
        }
        
        return nil
    }
}
