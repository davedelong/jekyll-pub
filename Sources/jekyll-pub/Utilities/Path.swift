//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation

struct Path: XMLRPCParamConvertible, ExpressibleByStringLiteral {
    let fileURL: URL
    init(parameter: XMLRPCParam) throws {
        guard let string = parameter.string else { throw XMLRPCError.wrongType(String.self, parameter) }
        self.init(stringLiteral: string)
    }
    
    init(stringLiteral value: String) {
        let expanded = (value as NSString).expandingTildeInPath
        let cwd = FileManager.default.currentDirectoryPath
        
        fileURL = URL(fileURLWithPath: expanded,
                      relativeTo: URL(fileURLWithPath: cwd)).absoluteURL
    }
}
