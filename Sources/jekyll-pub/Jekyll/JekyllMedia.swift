//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation

struct JekyllMedia: XMLRPCParamConvertible {
    let name: String
    let type: String
    let data: Data
    let overwrite: Bool
    
    init(parameter: XMLRPCParam) throws {
        let obj = try parameter.object ?! XMLRPCError.wrongType(JekyllMedia.self, parameter)
        name = try obj["name"]?.string ?! XMLRPCError.wrongType(String.self, obj["name"])
        type = try obj["type"]?.string ?! XMLRPCError.wrongType(String.self, obj["type"])
        data = try obj["bits"]?.data ?! XMLRPCError.wrongType(Data.self, obj["bits"])
        overwrite = obj["overwrite"]?.bool ?? true
    }
}

struct JekyllMediaResult: XMLRPCParamConvertible {
    let name: String
    let type: String
    let url: URL
    
    func xmlrpcParameter() throws -> XMLRPCParam {
        return .object([
            "id": .string(url.path),
            "file": .string(url.lastPathComponent),
            "type": .string(type),
            "url": .string(url.absoluteString)
        ])
    }
}
