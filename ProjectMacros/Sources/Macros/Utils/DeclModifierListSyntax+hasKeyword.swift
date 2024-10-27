//
//  DeclModifierListSyntax+hasKeyword.swift
//
//
//  Created by Bartłomiej Bukowiecki on 03/08/2024.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension DeclModifierListSyntax {
    func hasKeyword(of kind: TokenSyntax, with detail: TokenSyntax?) -> Bool {
        var isPresent = false
        
        for modifier in self {
            guard modifier.name.tokenKind == kind.tokenKind else { continue }
            
            if let detail, let modifierDetails = modifier.detail, detail.tokenKind != modifierDetails.detail.tokenKind {
                continue
            } else if (detail == nil && modifier.detail != nil) || (detail != nil && modifier.detail == nil) {
                continue
            }
            
            isPresent = true
            break
        }
        
        return isPresent
    }
}
