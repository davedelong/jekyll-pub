//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation
import Ink

extension JekyllSite {
    
    func allPosts() -> Array<JekyllPost> {
        let enumerator = FileManager.default.enumerator(at: postsFolder, includingPropertiesForKeys: nil)
        var posts = Array<JekyllPost>()
        
        let parser = MarkdownParser()
        if let iterator = enumerator {
            for anyURL in iterator {
                guard let url = anyURL as? URL else { continue }
                guard let contents = try? String(contentsOf: url) else { continue }
                let markdown = parser.parse(contents)
                
                posts.append(JekyllPost(url: url, markdown: markdown))
            }
        }
        return posts
    }
    
    func allTags() -> Array<String> {
        let posts = allPosts()
        let all = Set(posts.flatMap(\.tags))
        return all.sorted()
    }
    
}
