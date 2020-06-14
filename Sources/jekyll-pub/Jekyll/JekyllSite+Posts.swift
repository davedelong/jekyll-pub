//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation

extension JekyllSite {
    
    private func posts(in folder: URL, isDrafts: Bool) -> Array<JekyllPost> {
        let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)
        var posts = Array<JekyllPost>()
        
        if let iterator = enumerator {
            for anyURL in iterator {
                guard let url = anyURL as? URL else { continue }
                guard let post = try? JekyllPost(url: url, isPost: true, isDraftsFolder: isDrafts) else { continue }
                posts.append(post)
            }
        }
        return posts
    }
    
    func allDrafts() -> Array<JekyllPost> {
        posts(in: draftsFolder, isDrafts: true)
    }
    
    func allPublished() -> Array<JekyllPost> {
        posts(in: postsFolder, isDrafts: false)
    }
    
    func allPosts() -> Array<JekyllPost> {
        return allDrafts() + allPublished() + allPages()
    }
    
    func allPages() -> Array<JekyllPost> {
        let enumerator = FileManager.default.enumerator(at: site.rootFolder, includingPropertiesForKeys: [.typeIdentifierKey])
        var pages = Array<JekyllPost>()
        
        if let iterator = enumerator {
            for anyURL in iterator {
                guard let url = anyURL as? URL else { continue }
                if url.lastPathComponent.hasPrefix("_") { iterator.skipDescendants() }
                guard let type = (try? url.resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier else { continue }
                var page: JekyllPost?
                if UTTypeConformsTo(type as CFString, "public.html" as CFString) {
                    page = try? JekyllPost(url: url, isPost: false, isDraftsFolder: false)
                } else if UTTypeConformsTo(type as CFString, "net.daringfireball.markdown" as CFString) {
                    page = try? JekyllPost(url: url, isPost: false, isDraftsFolder: false)
                }
                if let p = page { pages.append(p) }
            }
        }
        
        return pages
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
    
    func newPost(_ post: JekyllPost, publish: Bool) throws -> JekyllPost {
        var filledOut = post
        
        filledOut["layout"] = .init("post")
        filledOut.status = publish ? .published : .draft
        
        if publish == true && filledOut.publishedDate == nil {
            filledOut.publishedDate = Date()
        }
        
        let title = filledOut.title
        let slug = title.slugified()
        
        var baseName = slug
        if let pubDate = filledOut.publishedDate {
            filledOut.id = slug
            baseName = slugDateFormatter.string(from: pubDate) + "-" + slug
        }
        
        let url = (publish ? postsFolder : draftsFolder).appendingPathComponent("\(baseName).md")
        let content = try filledOut.content()
        
        try content.write(to: url, atomically: true, encoding: .utf8)
        
        return filledOut
    }
}

let slugDateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.calendar = Calendar(identifier: .gregorian)
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = .current
    df.dateFormat = "y-MM-dd"
    return df
}()
