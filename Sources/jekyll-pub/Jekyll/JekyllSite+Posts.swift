//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation

// The cache maps unsorted posts -> sorted posts. Fetching posts is about 10% of the total cost
// of generating a sorted list for me - parsing the dates is much more expensive. So basing the
// cache on the unsorted state of the disk files lets me _completely_ ignore the tricky "cache
// invalidation" problems here - if anything changes on disk (we might change it, external editor
// might change it) the fetched files will be different, and we'll re-sort. This is a big speed
// improvement over sorting every time we need a post list.
var sortedAllPostsCache = [[JekyllPost]: [JekyllPost]]()

extension JekyllSite {
    
    private func posts(in rootFolder: URL, isDrafts: Bool) -> Array<JekyllPost> {
        guard let iterator = FileManager.default.enumerator(
            at: rootFolder,
            includingPropertiesForKeys: nil
        ) else { return [] }

        // A post is any file with '_posts' or '_drafts' anywhere in the parent tree of the file
        let postsFolder = isDrafts ? "_drafts" : "_posts"
        var posts = Array<JekyllPost>()
        for anyURL in iterator {
            guard let url = anyURL as? URL else { continue }
            if url.hasDirectoryPath || !url.pathComponents.contains(postsFolder) {
                continue
            }
            guard let post = try? JekyllPost(url: url, root: rootFolder, isPost: true, isDraftsFolder: isDrafts) else { continue }
            posts.append(post)
        }
        return posts
    }
    
    private func allDrafts() -> Array<JekyllPost> {
        posts(in: rootFolder, isDrafts: true)
    }
    
    private func allPublished() -> Array<JekyllPost> {
        posts(in: rootFolder, isDrafts: false)
    }
    
    private func allPages() -> Array<JekyllPost> {
        let enumerator = FileManager.default.enumerator(at: site.rootFolder, includingPropertiesForKeys: [.typeIdentifierKey])
        var pages = Array<JekyllPost>()
        
        if let iterator = enumerator {
            for anyURL in iterator {
                guard let url = anyURL as? URL else { continue }
                // Skip all subtrees that start with an underscore - this is _posts, _drafts, or some
                // Jekyll control / config files that aren't content
                if url.lastPathComponent.hasPrefix("_") {
                    iterator.skipDescendants()
                    continue
                }
                // Don't look for pages in the assets folder
                if url == filesFolder {
                    iterator.skipDescendants()
                    continue
                }

                guard let type = (try? url.resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier else { continue }
                var page: JekyllPost?
                if UTTypeConformsTo(type as CFString, "public.html" as CFString) {
                    page = try? JekyllPost(url: url, root: site.rootFolder, isPost: false, isDraftsFolder: false)
                } else if UTTypeConformsTo(type as CFString, "net.daringfireball.markdown" as CFString) {
                    page = try? JekyllPost(url: url, root: site.rootFolder, isPost: false, isDraftsFolder: false)
                }
                if let p = page { pages.append(p) }
            }
        }
        
        return pages
    }

    /// Returns a list of every post and page on the filesystem, sorted with unpublished files
    /// first (so drafts are at the top of the recents list) followed by reverse publish order.
    func allPosts() -> Array<JekyllPost> {
        let all = allDrafts() + allPublished() + allPages()
        if let cached = sortedAllPostsCache[all] {
            return cached
        }
        // Sanity check - all post urls must be globally distinct
        assert(Set(all.map { $0.id }).count == all.count)
        let sorted = all.sorted()
        // throw away the old cache keys
        sortedAllPostsCache = [all: sorted]
        return sorted
    }

    func allTags() -> Array<String> {
        let posts = allPosts()
        let all = Set(posts.flatMap(\.tags))
        return all.sorted()
    }
    
    func getPost(_ postID: String) throws -> JekyllPost {
        return try allPosts().first(where: { $0.id == postID }) ?! CocoaError(CocoaError.fileNoSuchFile)
    }
    
    func recentPosts(_ count: Int) -> Array<JekyllPost> {
        return allPosts().suffix(count)
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
        
        filledOut["layout"] = .init(post.kind.rawValue)
        filledOut.status = publish ? .published : .draft
        
        if publish == true && filledOut.publishedDate == nil {
            filledOut.publishedDate = Date()
        }
        
        let url = try self.updateFileURL(for: &filledOut)
        let content = try filledOut.content()
        // Create the parent directory if needed
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return filledOut
    }

    @discardableResult
    func editPost(_ post: JekyllPost, publish: Bool) throws -> JekyllPost {
        let id = try post.id ?! CocoaError(CocoaError.fileNoSuchFile)
        let oldFileUrl = try getPost(id).fileURL
        let created = try newPost(post, publish: publish)

        // Updating the post might have change the filename on disk (changed date,
        // changed slug, published post) - remove the old file in that case
        if let oldFileUrl, created.fileURL != oldFileUrl {
            try? FileManager.default.removeItem(at: oldFileUrl)
        }

        return created
    }
    
    // Update the fileURL of the post to be the "desired" fileURL given the published status,
    // kind, date, and slug.
    //
    // We're not making any effort here to retain the existing filename in the case that there's
    // a page with a "slug" propery in the front matter. Maybe we should.
    private func updateFileURL(for post: inout JekyllPost) throws -> URL {
        let slug = post.slug ?? post.title?.slugified() ?? "post"

        let url: URL
        switch post.kind {
        case .page:
            url = try URL(string: "\(slug).md", relativeTo: rootFolder) ?! CocoaError(CocoaError.fileNoSuchFile) // TOOD error
        case .post:
            let publish = post.status == .publish
            var baseName = slug
            if let pubDate = post.publishedDate, publish {
                baseName = slugDateFormatter.string(from: pubDate) + "-" + slug
            }
            url = rootFolder.appendingPathComponent(publish ? "_posts" : "_drafts").appendingPathComponent("\(baseName).md")
        }

        // Preserve the old post ID in the front matter if the filename changes and we were
        // using the filename as the ID, because MarsEdit can't handle the ID changing on save.
        // TODO this is kinda weird because it's the filename, so it preserves the first
        // published slug and date (or _drafts) of the file. MD5 might be better just so it's opaque?
        let oldID = post.id
        post.fileURL = url
        if let oldID, post.id != oldID {
            post.id = .init(oldID)
        }

        return url
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
