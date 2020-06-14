//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation

struct JekyllSite {
    let rootFolder: URL
    let postsFolder: URL
    let assetsFolder: URL
    let draftsFolder: URL
    
    init(siteFolder: Path) {
        rootFolder = siteFolder.fileURL
        postsFolder = siteFolder.fileURL.appendingPathComponent("_posts")
        assetsFolder = siteFolder.fileURL.appendingPathComponent("_assets")
        draftsFolder = siteFolder.fileURL.appendingPathComponent("_drafts")
    }
    
}

extension JekyllSite: XMLRPCParamConvertible {
    init(parameter: XMLRPCParam) throws {
        let path = try Path(parameter: parameter)
        var exists: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path.fileURL.path, isDirectory: &exists) && exists.boolValue == true else {
            throw CocoaError(CocoaError.fileNoSuchFile)
        }
        
        self.init(siteFolder: path)
    }
}
