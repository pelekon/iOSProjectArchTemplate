//
//  BindingsTestViewModel+Model.swift
//  ArchTest
//
//  Created by Bartłomiej Bukowiecki on 27/10/2024.
//

extension BindingsTestView {
    struct Model {
        var counter: Int = 0
        private(set) var progress = Float.zero
        
        mutating func updateProgress(to value: Float) {
            self.progress = value
        }
    }
}
