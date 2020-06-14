//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/14/20.
//

import Foundation

enum Wordpress {
    struct GetUsersBlogs: XMLRPCMethod {
        typealias XMLRPCMethodResult = Array<Blog>
        static let methodCalls: Set<String> = ["wp.getUsersBlogs"]
        
        let userName: String
        let password: String
        
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            userName = try c.decode(String.self)
            password = try c.decode(String.self)
        }
        
        func execute(with site: JekyllSite) throws -> XMLRPCMethodResult {
            return [
                Blog(blogid: site.rootFolder.path, blogName: site.rootFolder.lastPathComponent, url: "", xmlrpc: "", isAdmin: true)
            ]
        }
    }
    struct GetUser: XMLRPCMethod {
        typealias XMLRPCMethodResult = User
        static let methodCalls: Set<String> = ["wp.getUser", "wp.getProfile"]
        
        let blogID: String
        let userName: String
        let password: String
        let userID: String
        
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            blogID = try c.decode(String.self)
            userName = try c.decode(String.self)
            password = try c.decode(String.self)
            userID = try c.decode(String.self)
        }
        
        func execute(with site: JekyllSite) throws -> XMLRPCMethodResult {
            return User(user_id: userID, username: "", first_name: "", last_name: "", bio: "", email: "", nickname: "", nicename: "", url: "", display_name: "", registered: Date(), roles: [])
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
}

extension Wordpress {
    struct Blog: Encodable {
        let blogid: String
        let blogName: String
        let url: String
        let xmlrpc: String
        let isAdmin: Bool
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
}
