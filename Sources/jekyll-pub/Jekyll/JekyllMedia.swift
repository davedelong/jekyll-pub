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
    var overwrite: Bool?
}

struct JekyllMediaResult: Encodable {
    let name: String
    let type: String

    // Path relative to site root. I'm assuming this is also the path
    // relative to the web root
    let relativePath: String
    
    init(url: URL, root: URL) {
        name = url.lastPathComponent
        relativePath = url.absoluteString.replacing(root.absoluteString, with: "")
        let tag = url.pathExtension
        let cfTypes = UTTypeCreateAllIdentifiersForTag(kUTTagClassFilenameExtension, tag as CFString, nil)?.takeRetainedValue()
        let types = (cfTypes as? Array<String>) ?? []
        self.type = types.first ?? "public.item"
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyCodingKey.self)
        try c.encode(name, forKey: "id")
        try c.encode(name, forKey: "file")
        try c.encode(type, forKey: "type")
        try c.encode(relativePath, forKey: "url")
    }
}
