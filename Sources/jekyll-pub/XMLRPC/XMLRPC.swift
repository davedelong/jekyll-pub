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
    
    init<T: XMLRPCMethod>(type: T.Type) {
        self.description = "\(T.self) -> \(T.XMLRPCMethodResult.self)"
        self.decode = {
            let decoder = XMLRPCDecoder()
            let method = try decoder.decode(T.self, from: $0)
            guard T.methodCalls.contains(method.methodName) else {
                throw DecodingError.typeMismatch(T.self, DecodingError.Context(codingPath: [], debugDescription: "Expect one of \(T.methodCalls), but got \(method.methodName)"))
            }
            
            return { site in
                let result = try method.parameters.execute(with: site)
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
