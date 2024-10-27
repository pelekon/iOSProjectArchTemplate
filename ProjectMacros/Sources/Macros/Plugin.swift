//
//  Plugin.swift
//
//
//  Created by Bartłomiej Bukowiecki on 29/06/2024.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

@main struct Plugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        MakeSubEnumWithCasesMacro.self,
        GenerateTestableAbstractionMacro.self,
        IgnoreForAbstractionMacro.self,
        GenerateAbstractionKeyMacro.self,
        GenerateMutatorsMacro.self,
        GenerateBindingsMacro.self,
        BindTargetMacro.self,
        BindableMacro.self
    ]
}
