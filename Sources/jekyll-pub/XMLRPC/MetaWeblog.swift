//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation
import Swifter

class MetaWeblog {
    let server = HttpServer()
    private var routes = Array<MethodRoute>()
    
    init(site: JekyllSite) {
        server.post["/"] = self.handle
        
        route("metaWeblog.getCategories") { (_: String, _: String, _: String) -> Array<JekyllCategory> in
            return site.allCategories()
        }
        route("metaWeblog.getRecentPosts") { (_: String, _: String, _: String) -> Array<JekyllPost> in
            return site.recentPosts(10)
        }
        route("metaWeblog.getRecentPosts") { (_: String, _: String, _: String, count: Int) -> Array<JekyllPost> in
            return site.recentPosts(count)
        }
        route("metaWeblog.newPost") { (_: String, _: String, _: String, post: JekyllPost, publish: Bool) -> String in
            let post = try site.newPost(post, publish: publish)
            return post.id
        }
        route("metaWeblog.editPost") { (postID: String, _: String, _: String, post: JekyllPost, publish: Bool) -> Bool in
            // TODO:
            return true
        }
        route("metaWeblog.deletePost") { (_: String, postID: String, _: String, _: String) -> Bool in
            return site.deletePost(postID)
        }
        route("metaWeblog.deletePost") { (_: String, postID: String, _: String, _: String, publish: Bool) -> Bool in
            return site.deletePost(postID)
        }
        route("blogger.deletePost") { (_: String, postID: String, _: String, _: String) -> Bool in
            return site.deletePost(postID)
        }
        route("blogger.deletePost") { (_: String, postID: String, _: String, _: String, publish: Bool) -> Bool in
            return site.deletePost(postID)
        }
        route("metaWeblog.getPost") { (postID: String, _: String, _: String) -> JekyllPost in
            guard let post = site.allPosts().first(where: { $0.id == postID }) else {
                throw CocoaError(CocoaError.fileNoSuchFile)
            }
            return post
        }
        route("metaWeblog.newMediaObject") { (_: String, _: String, _: String, media: JekyllMedia) -> JekyllMediaResult in
            return try site.saveMedia(media)
        }
    }
    
    func run() throws {
        try server.start(9080, forceIPv4: false, priority: .userInteractive)
        dispatchMain()
    }
    
    private func handle(_ request: HttpRequest) -> HttpResponse {
        do {
            let method = try MethodCall(request: request)
            guard let route = self.route(for: method) else {
                return .notFound
            }
            return try route.handler(method.parameters)
        } catch {
            return .badRequest(.text("\(error)"))
        }
    }
    
    private func route(for method: MethodCall) -> MethodRoute? {
        return routes.first(where: { $0.name == method.methodName && $0.parameterCount == method.parameters.count })
    }
}

typealias PC = XMLRPCParamConvertible
extension MetaWeblog {
    
    func route<A: PC, B: PC, C: PC, R: PC>(_ name: String, to handler: @escaping (A, B, C) throws -> R) {
        self.routes.append(MethodRoute(name: name, parameterCount: 3) { params -> R in
            let v1 = try A(parameter: params[0])
            let v2 = try B(parameter: params[1])
            let v3 = try C(parameter: params[2])
            return try handler(v1, v2, v3)
        })
    }
    
    func route<A: PC, B: PC, C: PC, D: PC, R: PC>(_ name: String, to handler: @escaping (A, B, C, D) throws -> R) {
        self.routes.append(MethodRoute(name: name, parameterCount: 4) { params -> R in
            let v1 = try A(parameter: params[0])
            let v2 = try B(parameter: params[1])
            let v3 = try C(parameter: params[2])
            let v4 = try D(parameter: params[3])
            return try handler(v1, v2, v3, v4)
        })
    }
    
    func route<A: PC, B: PC, C: PC, D: PC, E: PC, R: PC>(_ name: String, to handler: @escaping (A, B, C, D, E) throws -> R) {
        self.routes.append(MethodRoute(name: name, parameterCount: 5) { params -> R in
            let v1 = try A(parameter: params[0])
            let v2 = try B(parameter: params[1])
            let v3 = try C(parameter: params[2])
            let v4 = try D(parameter: params[3])
            let v5 = try E(parameter: params[4])
            return try handler(v1, v2, v3, v4, v5)
        })
    }
    
}
