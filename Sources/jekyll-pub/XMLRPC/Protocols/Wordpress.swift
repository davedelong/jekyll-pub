//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/14/20.
//

import Foundation

// https://codex.wordpress.org/XML-RPC_WordPress_API
enum Wordpress {

    // ~get categories
    // ~new category
    // ~get tags
    // ~new post
    // ~edit post
    // ~delete post
    // ~get post
    // ~get posts
    // ~get post formats
    // ~get users
    // ~get authors
    // get media library
    struct GetCategories: XMLRPCMethod {
        typealias XMLRPCMethodResult = Array<JekyllCategory>
        static let methodCalls: Set<String> = ["wp.getCategories"]
        
        let blogID: String
        let userName: String
        let password: String
        
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            blogID = try c.decode(String.self)
            userName = try c.decode(String.self)
            password = try c.decode(String.self)
        }
        
        func execute(with site: JekyllSite) throws -> Array<JekyllCategory> {
            return site.allCategories()
        }
    }
    struct NewCategory: XMLRPCMethod {
        typealias XMLRPCMethodResult = Int
        static let methodCalls: Set<String> = ["wp.newCategory"]
        
        func execute(with site: JekyllSite) throws -> Int {
            throw XMLRPCFault(code: 403, message: "Jekyll does not support creating categories")
        }
    }
    struct GetUsers: XMLRPCMethod {
        typealias XMLRPCMethodResult = Array<User>
        static let methodCalls: Set<String> = ["wp.getUsers"]
        
        let blogID: String
        let userName: String
        let password: String
        
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            blogID = try c.decode(String.self)
            userName = try c.decode(String.self)
            password = try c.decode(String.self)
        }
        
        func execute(with site: JekyllSite) throws -> XMLRPCMethodResult {
            return [User(user_id: "0", username: "dave", first_name: "Dave", last_name: "", bio: "", email: "", nickname: "", nicename: "", url: "", display_name: "Dave", registered: Date(), roles: [])]
        }
    }
    struct GetAuthors: XMLRPCMethod {
        typealias XMLRPCMethodResult = Array<Author>
        static let methodCalls: Set<String> = ["wp.getAuthors"]
        
        let blogID: String
        let userName: String
        let password: String
        
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            blogID = try c.decode(String.self)
            userName = try c.decode(String.self)
            password = try c.decode(String.self)
        }
        
        func execute(with site: JekyllSite) throws -> XMLRPCMethodResult {
            return [Author(user_id: "0", user_login: "", display_name: "")]
        }
    }
    struct NewPost: XMLRPCMethod {
        typealias XMLRPCMethodResult = String
        static let methodCalls: Set<String> = ["wp.newPost"]
        
        let blogID: String
        let userName: String
        let password: String
        let post: SavePost
        
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            blogID = try c.decode(String.self)
            userName = try c.decode(String.self)
            password = try c.decode(String.self)
            post = try c.decode(SavePost.self)
        }
        
        func execute(with site: JekyllSite) throws -> XMLRPCMethodResult {
            var post = JekyllPost(root: site.rootFolder)
            post.update(from: self.post)
            return try site.newPost(post, publish: post.status == .publish).id ?! CocoaError(CocoaError.fileNoSuchFile)
        }
    }
    struct EditPost: XMLRPCMethod {
        typealias XMLRPCMethodResult = Bool
        static let methodCalls: Set<String> = ["wp.editPost"]
        
        let blogID: String
        let userName: String
        let password: String
        let postID: String
        let post: SavePost
        
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            blogID = try c.decode(String.self)
            userName = try c.decode(String.self)
            password = try c.decode(String.self)
            postID = try c.decode(String.self)
            post = try c.decode(SavePost.self)
        }
        
        func execute(with site: JekyllSite) throws -> XMLRPCMethodResult {
            var existing = try site.getPost(postID)
            existing.update(from: post)
            try site.editPost(existing, publish: true)
            return true
        }
    }

    struct GetPost: XMLRPCMethod {
        typealias XMLRPCMethodResult = Post
        static let methodCalls: Set<String> = ["wp.getPost"]
        
        let userName: String
        let password: String
        let postID: String
        
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            userName = try c.decode(String.self)
            password = try c.decode(String.self)
            _ = try c.decode(String.self)
            postID = try c.decode(String.self)
        }
        
        func execute(with site: JekyllSite) throws -> XMLRPCMethodResult {
            return Post(try site.getPost(postID))
        }
    }
    struct DeletePost: XMLRPCMethod {
        typealias XMLRPCMethodResult = Bool
        static let methodCalls: Set<String> = ["wp.deletePost"]
        
        let blogID: String
        let userName: String
        let password: String
        let postID: String
        
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            blogID = try c.decode(String.self)
            userName = try c.decode(String.self)
            password = try c.decode(String.self)
            postID = try c.decode(String.self)
        }
        
        func execute(with site: JekyllSite) throws -> XMLRPCMethodResult {
            return site.deletePost(postID)
        }
    }
    struct GetPosts: XMLRPCMethod {
        typealias XMLRPCMethodResult = Array<Post>
        static let methodCalls: Set<String> = ["wp.getPosts"]
        
        let blogID: String
        let userName: String
        let password: String
        let filter: PostFilter
        
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            blogID = try c.decode(String.self)
            userName = try c.decode(String.self)
            password = try c.decode(String.self)
            filter = try c.decode(PostFilter.self)
        }
        
        func execute(with site: JekyllSite) throws -> XMLRPCMethodResult {
            var posts = site.allPosts()
            if let kind = filter.post_type { posts = posts.filter { $0.kind == kind } }
            if let status = filter.post_status { posts = posts.filter { $0.status == status } }

            var slice = posts[...]
            if let offset = filter.offset {
                slice = slice.dropFirst(offset)
            }
            if let number = filter.number {
                slice = slice.prefix(number)
            }

            return slice.map { Post($0) }
        }
    }
    struct GetPostFormats: XMLRPCMethod {
        typealias XMLRPCMethodResult = Dictionary<String, String>
        static let methodCalls: Set<String> = ["wp.getPostFormats"]
        
        let blogID: String
        let userName: String
        let password: String
        
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            blogID = try c.decode(String.self)
            userName = try c.decode(String.self)
            password = try c.decode(String.self)
        }
        
        func execute(with site: JekyllSite) throws -> XMLRPCMethodResult {
            return ["post": "Post", "page": "Page"]
        }
    }
    struct GetTags: XMLRPCMethod {
        typealias XMLRPCMethodResult = Array<Tag>
        static let methodCalls: Set<String> = ["wp.getTags"]
        
        let blogID: String
        let userName: String
        let password: String
        
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            blogID = try c.decode(String.self)
            userName = try c.decode(String.self)
            password = try c.decode(String.self)
        }
        
        func execute(with site: JekyllSite) throws -> XMLRPCMethodResult {
            let posts = site.allPosts()
            var tags = Dictionary<String, Int>()
            for post in posts {
                for tag in post.tags {
                    tags[tag, default: 0] += 1
                }
            }
            let wpTags = tags.map { tag, count in
                return Tag(tag_id: tag, name: tag, slug: tag.slugified(), count: count)
            }
            return wpTags
        }
    }
    struct GetMediaLibrary: XMLRPCMethod {
        typealias XMLRPCMethodResult = Array<MediaItem>
        static let methodCalls: Set<String> = ["wp.getMediaLibrary"]
        
        let blogID: String
        let userName: String
        let password: String
        let filter: MediaFilter?
        
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            blogID = try c.decode(String.self)
            userName = try c.decode(String.self)
            password = try c.decode(String.self)
            if c.isAtEnd == false {
                filter = try c.decode(MediaFilter.self)
            } else {
                filter = nil
            }
        }
        
        func execute(with site: JekyllSite) throws -> XMLRPCMethodResult {
            let media = site.allMedia()
            var slice = media[...]
            if let offset = filter?.offset { slice = slice.dropFirst(offset) }
            if let number = filter?.number { slice = slice.prefix(number) }
            return slice.map {
                MediaItem(
                    attachment_id: $0.relativePath,
                    link: site.webBase.appending(path: $0.relativePath).absoluteString,
                    thumbnail: site.webBase.appending(path: $0.relativePath).absoluteString,
                    title: $0.name,
                    caption: $0.name,
                    description: $0.name)
            }
        }
    }
}

extension Wordpress {
    struct Blog: Encodable {
        let blogid: String
        let blogName: String
        let url: String
        let xmlrpc: String
        let isAdmin: Bool
    }
    struct Tag: Encodable {
        let tag_id: String
        let name: String
        let slug: String
        let count: Int
    }
    
    struct User: Encodable {
        let user_id: String
        let username: String
        let first_name: String
        let last_name: String
        let bio: String
        let email: String
        let nickname: String
        let nicename: String
        let url: String
        let display_name: String
        let registered: Date
        let roles: Array<String>
    }
    struct Author: Encodable {
        let user_id: String
        let user_login: String
        let display_name: String
    }
    struct PostFilter: Decodable {
        let post_type: JekyllPost.Kind?
        let post_status: JekyllPost.Status?
        let number: Int?
        let offset: Int?
        let orderby: String?
        let order: String?
    }
    struct MediaFilter: Decodable {
        let number: Int?
        let offset: Int?
        let parent_id: String?
        let mime_type: String?
    }
    struct Post: Codable {
        let post_id: String?
        let post_title: String?
        let post_date: Date?
        let post_date_gmt: Date?
        let post_modified: Date?
        let post_modified_gmt: Date?
        let post_type: String
        let post_status: String
        let post_author: String
        let post_content: String
        let post_name: String?
        let terms: Array<Term>
    }
    struct SavePost: Decodable {
        let post_id: String?
        let post_title: String?
        let post_date_gmt: Date?
        let post_type: String?
        let post_status: String
        let post_content: String
        let post_name: String?
        let terms_names: Dictionary<String, Array<String>>?
    }
    struct Term: Codable {
        let term_id: String
        let name: String
        let slug: String
        let taxonomy = "post_tag"
    }
    struct MediaItem: Encodable {
        let attachment_id: String
        let link: String
        let thumbnail: String
        let title: String
        let caption: String
        let description: String
    }
}

fileprivate extension Wordpress.Post {
    init(_ p: JekyllPost) {
        post_id = p.id
        post_title = p.title
        post_date_gmt = p.publishedDate
        post_date = p.publishedDate
        post_modified = p.editedDate
        post_modified_gmt = p.editedDate
        post_type = p.kind.rawValue
        post_status = p.status.rawValue
        post_author = "0"
        post_content = p.body
        post_name = p.slug
        terms = p.tags.map { Wordpress.Term(term_id: $0, name: $0, slug: $0.slugified()) }
    }
}

fileprivate extension JekyllPost {
    mutating func update(from p: Wordpress.SavePost) {
        title = p.post_title
        publishedDate = p.post_date_gmt
        kind = p.post_type.flatMap { Kind(rawValue: $0) } ?? kind
        status = Status(rawValue: p.post_status) ?? status
        body = p.post_content
        slug = p.post_name ?? slug
        tags = p.terms_names?["post_tag"] ?? tags
    }
}
