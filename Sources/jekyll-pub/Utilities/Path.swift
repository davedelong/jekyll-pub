//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation

struct Path: ExpressibleByStringLiteral {
    let fileURL: URL
    
    init(stringLiteral value: String) {
        let expanded = (value as NSString).expandingTildeInPath
        let cwd = FileManager.default.currentDirectoryPath
        
        fileURL = URL(fileURLWithPath: expanded,
                      relativeTo: URL(fileURLWithPath: cwd)).absoluteURL
    }
}
