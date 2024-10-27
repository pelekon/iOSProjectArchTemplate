//
//  ViewModelProperty.swift
//  ArchTest
//
//  Created by Bartłomiej Bukowiecki on 26/10/2024.
//

import SwiftUI

@propertyWrapper
struct ViewModelProperty<Object>: DynamicProperty where Object: VM {
    @StateObject private var viewModel: Object
    
    init(viewModel: @autoclosure @escaping () -> Object) {
        self._viewModel = .init(wrappedValue: viewModel())
    }
    
    init() where Object: HasEmptyInit {
        self._viewModel = .init(wrappedValue: Object.init())
    }
    
    var wrappedValue: Object {
        get { viewModel }
    }
}
