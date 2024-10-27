//
//  String+Utils.swift
//  ProjectMacros
//
//  Created by Bartłomiej Bukowiecki on 26/10/2024.
//

import Foundation

extension String {
    var withLowercaseFirstLetter: String {
        guard !self.isEmpty else { return self }
        var copy = self
        guard let firstLetter = copy.first else { return self }
        
        copy.replaceSubrange(copy.startIndex..<copy.index(copy.startIndex, offsetBy: 1), with: firstLetter.lowercased())
        return copy
    }
    
    var withUppercaseFirstLetter: String {
        guard !self.isEmpty else { return self }
        var copy = self
        guard let firstLetter = copy.first else { return self }
        
        copy.replaceSubrange(copy.startIndex..<copy.index(copy.startIndex, offsetBy: 1), with: firstLetter.uppercased())
        return copy
    }
}
