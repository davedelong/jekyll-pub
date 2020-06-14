//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation

extension JekyllSite {
    
    func saveMedia(_ media: JekyllMedia) throws -> JekyllMediaResult {
        let baseName = (media.name as NSString).deletingPathExtension.slugified()
        let pathExtension = (media.name as NSString).pathExtension
        var nextSuffix = 1
        
        var name = "\(baseName).\(pathExtension)"
        var url = filesFolder.appendingPathComponent(name)
        
        while FileManager.default.fileExists(atPath: url.path) && media.overwrite == false {
            name = "\(baseName)-\(nextSuffix).\(pathExtension)"
            url = filesFolder.appendingPathComponent(name)
            nextSuffix += 1
        }
        
        if media.overwrite == true {
            try? FileManager.default.removeItem(at: url)
        }
        
        try media.data.write(to: url)
        return JekyllMediaResult(name: name, type: media.type, siteURL: "/files/\(name)")
    }
    
}
