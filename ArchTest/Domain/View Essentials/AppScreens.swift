//
//  AppScreens.swift
//  ArchTest
//
//  Created by Bartłomiej Bukowiecki on 26/10/2024.
//

import Foundation
import SwiftUI
import ProjectMacros
import CSUCoordinatedPresentation

typealias AppCoordinator = CSUViewCoordinator<AppScreens>
typealias Navigation = CSUCoordinatedNavigationView<AppScreens>

@EnumCaseLabels
enum AppScreens: CSUScreensProvider {
    case root
    
    var screenType: CaseLabels { .init(parent: self) }
    
    func makeScreen() -> some View {
        switch self {
        case .root:
            RootView()
        }
    }
}
