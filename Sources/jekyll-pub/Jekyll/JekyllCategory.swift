//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation

struct JekyllCategory {
    static let uncategorized = JekyllCategory(id: 1, parentID: 0, name: "Uncategorized")
    
    let id: Int
    let parentID: Int
    let name: String
    
    internal init(id: Int, parentID: Int, name: String) {
        self.id = id
        self.parentID = parentID
        self.name = name
    }
}

extension JekyllCategory: Encodable {
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyCodingKey.self)
        try c.encode(id, forKey: "categoryId")
        try c.encode(parentID, forKey: "parentId")
        try c.encode(name, forKey: "categoryName")
        try c.encode(name, forKey: "description")
        try c.encode("", forKey: "categoryDescription")
    }
}
