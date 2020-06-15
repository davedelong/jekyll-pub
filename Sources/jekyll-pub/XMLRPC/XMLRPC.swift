//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation

struct XMLRPCFault: Error, Encodable {
    let code: Int
    let message: String
}

struct XMLRPCRoute : CustomStringConvertible {
    typealias Executor = (JekyllSite) throws -> Data
    
    let decode: (Data) throws -> Executor
    let description: String
    let supportedMethods: Set<String>
    
    init<T: XMLRPCMethod>(type: T.Type) {
        self.description = "\(T.self) -> \(T.XMLRPCMethodResult.self)"
        self.supportedMethods = T.methodCalls
        self.decode = {
            let decoder = XMLRPCDecoder()
            let parameters = try decoder.decode(T.self, from: $0)
            return { site in
                let result = try parameters.execute(with: site)
                return try XMLRPCEncoder().encode(result)
            }
        }
    }
    
}

let iso8601Formatter: ISO8601DateFormatter = {
    // yyyyMMdd'T'HH:mm:ss
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withColonSeparatorInTime]
    return f
}()
