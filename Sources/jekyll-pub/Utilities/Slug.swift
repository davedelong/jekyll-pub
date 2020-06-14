//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation

extension String {
    
    func slugified() -> String {
        return String(filter { $0.isPunctuation == false }.flatMap { $0.isWhitespace ? "-" : $0.lowercased() })
    }
    
}
