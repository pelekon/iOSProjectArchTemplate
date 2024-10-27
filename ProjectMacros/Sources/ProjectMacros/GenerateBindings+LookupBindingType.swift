//
//  GenerateBindings+LookupBindingType.swift
//  ProjectMacros
//
//  Created by Bartłomiej Bukowiecki on 27/10/2024.
//

public enum LookupBindingType {
    case withMutator(_ targetName: String)
    case simple(_ targetName: String)
}
