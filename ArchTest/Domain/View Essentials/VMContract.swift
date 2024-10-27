//
//  VMContract.swift
//  ArchTest
//
//  Created by Bartłomiej Bukowiecki on 26/10/2024.
//

import Foundation

protocol VM: ObservableObject {
    associatedtype Input
    associatedtype State
    
    var state: State { get }
    var viewState: ViewState { get }
    
    func onInput(_ input: Input)
}
