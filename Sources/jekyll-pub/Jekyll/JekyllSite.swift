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
    let filesFolder: URL
    let draftsFolder: URL
    
    init(siteFolder: Path) {
        rootFolder = siteFolder.fileURL
        postsFolder = siteFolder.fileURL.appendingPathComponent("_posts")
        filesFolder = siteFolder.fileURL.appendingPathComponent("_files")
        draftsFolder = siteFolder.fileURL.appendingPathComponent("_drafts")
    }
    
}
