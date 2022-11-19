//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation

extension JekyllSite {
    
    func allMedia() -> [JekyllMediaResult] {
        let enumerator = FileManager.default.enumerator(at: filesFolder, includingPropertiesForKeys: [.isDirectoryKey])
        var mediaItems = Array<JekyllMediaResult>()
        
        if let iterator = enumerator {
            for anyURL in iterator {
                guard let url = anyURL as? URL else { continue }
                guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == false else { continue }
                let media = JekyllMediaResult(url: url, root: rootFolder)
                mediaItems.append(media)
            }
        }
        return mediaItems
    }
    
    func saveMedia(_ media: JekyllMedia) throws -> JekyllMediaResult {
        let baseName = (media.name as NSString).deletingPathExtension.slugified()
        let pathExtension = (media.name as NSString).pathExtension
        var nextSuffix = 1
        
        var name = "\(baseName).\(pathExtension)"
        var url = filesFolder.appendingPathComponent(name)
        
        while FileManager.default.fileExists(atPath: url.path) && media.overwrite != true {
            name = "\(baseName)-\(nextSuffix).\(pathExtension)"
            url = filesFolder.appendingPathComponent(name)
            nextSuffix += 1
        }
        
        if media.overwrite == true {
            try? FileManager.default.removeItem(at: url)
        }
        
        try media.bits.write(to: url)
        return JekyllMediaResult(url: url, root: rootFolder)
    }
    
}
