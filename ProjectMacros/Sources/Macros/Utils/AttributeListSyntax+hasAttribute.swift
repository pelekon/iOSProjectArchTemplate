//
//  AttributeListSyntax+hasAttribute.swift
//
//
//  Created by Bartłomiej Bukowiecki on 03/08/2024.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension AttributeListSyntax {
    func firstAttribute(of kind: TokenKind) -> AttributeSyntax? {
        for attri in self {
            guard let attriSyntax = attri.as(AttributeSyntax.self),
                  let typeSyntax = attriSyntax.attributeName.as(IdentifierTypeSyntax.self), typeSyntax.name.tokenKind == kind else { continue }
            
            return attriSyntax
        }
        
        return nil
    }
    
    func hasAttribute(of kind: TokenKind) -> Bool {
        return firstAttribute(of: kind) != nil
    }
}
