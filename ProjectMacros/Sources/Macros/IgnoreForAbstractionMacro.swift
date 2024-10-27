//
//  IgnoreForAbstractionMacro.swift
//
//
//  Created by Bartłomiej Bukowiecki on 03/08/2024.
//

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

struct IgnoreForAbstractionMacro: PeerMacro {
    static func expansion(
      of node: AttributeSyntax,
      providingPeersOf declaration: some DeclSyntaxProtocol,
      in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return []
    }
}
