//
//  RootView+ViewModel.swift
//  ArchTest
//
//  Created by Bartłomiej Bukowiecki on 26/10/2024.
//

import Foundation
import SwiftUI
import ProjectMacros

extension RootView {
    final class ViewModel: VM, HasEmptyInit {
        @Published private(set) var state = State()
        @Published private(set) var viewState: ViewState = .loading
        
        func onInput(_ input: Input) {
//            presentation.showLogin.toggle()
        }
        
        // MARK: - Privates
        
        private func updateCounter(to value: Int) {
            state.updateCounter(to: value)
        }
    }
}
