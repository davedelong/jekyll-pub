//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation

struct JekyllSite {
    // Serve XMLRPC on this port
    let port: UInt16 = 9080

    // Root of the Jekyll site on disk
    let rootFolder: URL

    // Not the only place files can be, but the contents of this folder will be exposed
    // from the getMediaLibrary endpoint, and binary uploads will go here.
    let filesFolder: URL

    init(siteFolder: Path) {
        rootFolder = siteFolder.fileURL
        filesFolder = siteFolder.fileURL.appendingPathComponent("assets")
    }

    var webBase: URL {
        // Assuming that you're also running jekyll in dev mode nearby. MarsEdit
        // will need this running to fetch assets for preview.
        URL(string: "http://localhost:4000/")!
    }
    
}
