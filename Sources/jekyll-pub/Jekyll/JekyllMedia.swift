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
    
    init(url: URL) {
        name = url.lastPathComponent
        let components = url.pathComponents
        let _files = components.lastIndex(of: "_files")!
        let pieces = components.dropFirst(_files + 1)
        siteURL = "/files/" + pieces.joined(separator: "/")
        
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
        try c.encode(siteURL, forKey: "url")
    }
}
