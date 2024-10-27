//
//  RootViewModel+Presentation.swift
//  ArchTest
//
//  Created by Bartłomiej Bukowiecki on 26/10/2024.
//

import ProjectMacros

extension RootView.ViewModel {
    struct Presentation {
        @GenerateMutators(name: "LoginPage")
        private(set) var showLogin = false
        @GenerateMutators(name: "MainPage", coupledValueType: UserContext.self)
        private(set) var showMain = false
        @GenerateMutators(name: "Dupa", coupledValueType: UserContext.self)
        private(set) var dupa: Int?
    }
}
