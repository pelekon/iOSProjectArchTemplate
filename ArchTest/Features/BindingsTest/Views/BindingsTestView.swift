//
//  BindingsTestView.swift
//  ArchTest
//
//  Created by Bartłomiej Bukowiecki on 27/10/2024.
//

import SwiftUI

struct BindingsTestView: View {
    @ViewModelProperty private var viewModel: ViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            Text(viewModel.state.counter.description)
                .font(.largeTitle)
            
            Button("Increment counter") {
                viewModel.onInput(.incrementCounter)
            }
            
            Text("Progress: \(viewModel.state.progress.description)")
            
            Slider(value: viewModel.bindStateProgress, in: 0...2)
        }
    }
}

#Preview {
    BindingsTestView()
}
