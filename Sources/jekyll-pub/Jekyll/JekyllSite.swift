//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation

struct JekyllSite {
    let id: String
    
    let postsFolder: URL
    let assetsFolder: URL
    let draftsFolder: URL
    
    init(id: String, siteFolder: URL) {
        self.id = id
        postsFolder = siteFolder.appendingPathComponent("_posts")
        assetsFolder = siteFolder.appendingPathComponent("_assets")
        draftsFolder = siteFolder.appendingPathComponent("_drafts")
    }
    
}
