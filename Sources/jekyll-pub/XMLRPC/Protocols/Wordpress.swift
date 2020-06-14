//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/14/20.
//

import Foundation

enum Wordpress {
    // ~get categories
    // new category
    // ~get tags
    // new post
    // edit post
    // delete post
    // get post
    // ~get posts
    // get post formats
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
            return [User(user_id: "0", username: "", first_name: "", last_name: "", bio: "", email: "", nickname: "", nicename: "", url: "", display_name: "", registered: Date(), roles: [])]
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
    struct GetPosts: XMLRPCMethod {
        typealias XMLRPCMethodResult = Array<JekyllPost>
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
            return Array(slice)
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
}
