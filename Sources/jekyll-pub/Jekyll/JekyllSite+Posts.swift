//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation

extension JekyllSite {
    
    private func posts(in folder: URL) -> Array<JekyllPost> {
        let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)
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
    
    func allDrafts() -> Array<JekyllPost> {
        posts(in: draftsFolder)
    }
    
    func allPosts() -> Array<JekyllPost> {
        return allDrafts() + posts(in: postsFolder)
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
    
    func deletePost(_ id: String) -> Bool {
        for post in allPosts() {
            guard post.id == id else { continue }
            guard let url = post.fileURL else { continue }
            do {
                try FileManager.default.removeItem(at: url)
                return true
            } catch {
                continue
            }
        }
        return false
    }
}
