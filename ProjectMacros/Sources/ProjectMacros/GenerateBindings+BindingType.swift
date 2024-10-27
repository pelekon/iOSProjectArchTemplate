//
//  GenerateBindings+BindingType.swift
//  ProjectMacros
//
//  Created by Bartłomiej Bukowiecki on 26/10/2024.
//

public enum BindingType<Target, Value> {
    case withMutator(KeyPath<Target, Value>, Value.Type)
    case simple(KeyPath<Target, Value>, Value.Type)
}
