//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation

extension JekyllSite {
    
    func allPosts() -> Array<JekyllPost> {
        let enumerator = FileManager.default.enumerator(at: postsFolder, includingPropertiesForKeys: nil)
        var posts = Array<JekyllPost>()
        
        if let iterator = enumerator {
            for anyURL in iterator {
                guard let url = anyURL as? URL else { continue }
                guard let post = try? JekyllPost(url: url) else { continue }
                posts.append(post)
            }
        }
        return posts
    }
    
    func allTags() -> Array<String> {
        let posts = allPosts()
        let all = Set(posts.flatMap(\.tags))
        return all.sorted()
    }
    
    func recentPosts(_ count: Int) -> Array<JekyllPost> {
        let sorted = allPosts().sorted(by: { p1, p2 -> Bool in
            switch (p1.publishedDate, p2.publishedDate) {
                case (nil, nil): return false
                case (nil, _): return true
                case (_, nil): return false
                case (.some(let l), .some(let r)): return l < r
            }
        })
        return sorted.suffix(count)
    }
}
