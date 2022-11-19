//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/14/20.
//

import Foundation

// https://codex.wordpress.org/XML-RPC_MetaWeblog_API
enum MetaWeblog {

    struct GetCategories: XMLRPCMethod {
        typealias XMLRPCMethodResult = Array<JekyllCategory>
        static let methodCalls: Set<String> = ["metaWeblog.getCategories"]

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

    struct GetRecentPosts: XMLRPCMethod {
        typealias XMLRPCMethodResult = Array<JekyllPost>
        static let methodCalls: Set<String> = ["metaWeblog.getRecentPosts"]

        let blogID: String
        let userName: String
        let password: String
        let count: Int

        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            blogID = try c.decode(String.self)
            userName = try c.decode(String.self)
            password = try c.decode(String.self)
            if c.isAtEnd == false {
                count = try c.decode(Int.self)
            } else {
                count = 10
            }
        }

        func execute(with site: JekyllSite) throws -> Array<JekyllPost> {
            return site.recentPosts(count)
        }
    }

    struct NewPost: XMLRPCMethod {
        typealias XMLRPCMethodResult = String
        static let methodCalls: Set<String> = ["metaWeblog.newPost"]

        let blogID: String
        let userName: String
        let password: String
        let content: JekyllPost
        let publish: Bool

        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            blogID = try c.decode(String.self)
            userName = try c.decode(String.self)
            password = try c.decode(String.self)
            content = try c.decode(JekyllPost.self)
            if c.isAtEnd == false {
                publish = try c.decode(Bool.self)
            } else {
                publish = true
            }
        }

        func execute(with site: JekyllSite) throws -> String {
            return try site.newPost(content, publish: publish).id ?! CocoaError(CocoaError.fileNoSuchFile)
        }

    }

    struct EditPost: XMLRPCMethod {
        typealias XMLRPCMethodResult = Bool
        static let methodCalls: Set<String> = ["metaWeblog.editPost"]

        let blogID: String
        let userName: String
        let password: String
        let content: JekyllPost
        let publish: Bool

        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            blogID = try c.decode(String.self)
            userName = try c.decode(String.self)
            password = try c.decode(String.self)
            content = try c.decode(JekyllPost.self)
            if c.isAtEnd == false {
                publish = try c.decode(Bool.self)
            } else {
                publish = true
            }
        }

    }

    struct DeletePost: XMLRPCMethod {
        typealias XMLRPCMethodResult = Bool
        static let methodCalls: Set<String> = ["metaWeblog.deletePost", "blogger.deletePost"]

        let blogID: String
        let postID: String
        let userName: String
        let password: String
        let publish: Bool

        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            blogID = try c.decode(String.self)
            postID = try c.decode(String.self)
            userName = try c.decode(String.self)
            password = try c.decode(String.self)
            publish = false
        }

        func execute(with site: JekyllSite) throws -> Bool {
            return site.deletePost(postID)
        }
    }

    struct GetPost: XMLRPCMethod {
        typealias XMLRPCMethodResult = JekyllPost
        static let methodCalls: Set<String> = ["metaWeblog.getPost"]

        let postID: String
        let userName: String
        let password: String

        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            postID = try c.decode(String.self)
            userName = try c.decode(String.self)
            password = try c.decode(String.self)
        }

        func execute(with site: JekyllSite) throws -> JekyllPost {
            return try site.getPost(postID)
        }
    }

    struct NewMediaObject: XMLRPCMethod {
        typealias XMLRPCMethodResult = JekyllMediaResult
        static let methodCalls: Set<String> = ["metaWeblog.newMediaObject"]

        let blogID: String
        let userName: String
        let password: String
        let media: JekyllMedia

        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            blogID = try c.decode(String.self)
            userName = try c.decode(String.self)
            password = try c.decode(String.self)
            media = try c.decode(JekyllMedia.self)
        }

        func execute(with site: JekyllSite) throws -> JekyllMediaResult {
            return try site.saveMedia(media)
        }
    }

}
