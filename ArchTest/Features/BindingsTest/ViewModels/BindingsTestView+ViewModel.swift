//
//  BindingsTestView+ViewModel.swift
//  ArchTest
//
//  Created by Bartłomiej Bukowiecki on 27/10/2024.
//

import Foundation
import SwiftUI
import ProjectMacros

extension BindingsTestView {
    @GenerateBindings(makeNonFunctionBindings: true)
    final class ViewModel: VM, HasEmptyInit {
        @BindTarget(for: (\Model.counter, Int.self), (\.progress, Float.self))
        @Published private(set) var state: Model
        @Published private(set) var viewState = ViewState.loaded
        
        init() {
            self.state = Model()
        }
        
        func onInput(_ input: Input) {
            switch input {
            case .incrementCounter:
                state.counter += 1
            }
        }
        
        // MARK: - Privates
        @Bindable(to: \Model.progress) private func updateProgress(to value: Float) {
            state.updateProgress(to: value)
        }
    }
}
