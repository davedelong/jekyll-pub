//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/14/20.
//

import Foundation

protocol XMLRPCMethod: Decodable {
    associatedtype XMLRPCMethodResult: Encodable
    static var methodCalls: Set<String> { get }
    
    func execute(with site: JekyllSite) throws -> XMLRPCMethodResult
}

extension XMLRPCMethod {
    func execute(with site: JekyllSite) throws -> XMLRPCMethodResult {
        throw XMLRPCFault(code: -1, message: "This method is not implemented")
    }
}

