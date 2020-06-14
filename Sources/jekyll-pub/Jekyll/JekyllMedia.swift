//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation

struct JekyllMedia: Decodable {
    let name: String
    let type: String
    let bits: Data
    var overwrite: Bool = true
}

struct JekyllMediaResult: Encodable {
    let name: String
    let type: String
    let siteURL: String
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyCodingKey.self)
        try c.encode(name, forKey: "id")
        try c.encode(name, forKey: "file")
        try c.encode(type, forKey: "type")
        try c.encode(siteURL, forKey: "url")
    }
}
