//
//  ArchTestApp.swift
//  ArchTest
//
//  Created by Bartłomiej Bukowiecki on 26/10/2024.
//

import SwiftUI

@main
struct ArchTestApp: App {
    var body: some Scene {
        WindowGroup {
            Navigation(rootScreenProvider: .root)
        }
    }
}
