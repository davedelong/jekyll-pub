//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation

struct JekyllCategory: XMLRPCParamConvertible {
    static let uncategorized = JekyllCategory(id: 1, parentID: 0, name: "Uncategorized")
    
    let id: Int
    let parentID: Int
    let name: String
    
    internal init(id: Int, parentID: Int, name: String) {
        self.id = id
        self.parentID = parentID
        self.name = name
    }
    
    init(parameter: XMLRPCParam) throws {
        guard let obj = parameter.object else { throw XMLRPCError.wrongType(JekyllCategory.self, parameter) }
        id = try obj["categoryId"]?.int ?! XMLRPCError.wrongType(Int.self, obj["categoryId"])
        parentID = obj["parentId"]?.int ?? 0
        name = try obj["categoryName"]?.string ?! XMLRPCError.wrongType(String.self, obj["categoryName"])
    }
    func xmlrpcParameter() throws -> XMLRPCParam {
        return .object([
            "categoryId": .int(id),
            "parentId": .int(parentID),
            "categoryName": .string(name),
            "description": .string(name),
            "categoryDescription": .string("")
        ])
    }
}
