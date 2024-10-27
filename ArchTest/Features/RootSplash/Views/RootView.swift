//
//  RootView.swift
//  ArchTest
//
//  Created by Bartłomiej Bukowiecki on 26/10/2024.
//

import SwiftUI

struct RootView: View {
    @ViewModelProperty private var viewModel: ViewModel
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    RootView()
}
