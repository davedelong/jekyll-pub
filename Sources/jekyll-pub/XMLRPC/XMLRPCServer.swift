//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation
import Swifter

class XMLRPCServer {
    let server = HttpServer()
    private var xmlrpcRoutes = Array<XMLRPCRoute>()
    
    init(site: JekyllSite) {
        server.post["/"] = self.handleXMLRPC
        
        addRouteHandler(MetaWeblog.GetCategories.self)
        addRouteHandler(MetaWeblog.GetRecentPosts.self)
        addRouteHandler(MetaWeblog.NewPost.self)
        addRouteHandler(MetaWeblog.EditPost.self)
        addRouteHandler(MetaWeblog.DeletePost.self)
        addRouteHandler(MetaWeblog.GetPost.self)
        addRouteHandler(MetaWeblog.NewMediaObject.self)
        
        addRouteHandler(Wordpress.GetAuthors.self)
        addRouteHandler(Wordpress.GetUser.self)
        addRouteHandler(Wordpress.GetUsersBlogs.self)
        addRouteHandler(Wordpress.GetUsers.self)
    }
    
    func run() throws {
        try server.start(9080, forceIPv4: false, priority: .userInteractive)
        dispatchMain()
    }
    
    private func handleXMLRPC(_ request: HttpRequest) -> HttpResponse {
        let body = Data(request.body)
        do {
            var handler: XMLRPCRoute.Executor?
            for possibleRoute in xmlrpcRoutes {
                handler = try? possibleRoute.decode(body)
                if handler != nil {
                    print("Chose route: \(possibleRoute)")
                    break
                }
            }
            
            if let h = handler {
                let responseBody = try h(site)
                if let s = String(data: responseBody, encoding: .utf8) {
                    print("BODY:\n\(s)")
                }
                return .ok(.data(responseBody))
            } else {
                return .unauthorized
            }
        } catch {
            // attempting to execute the handler failed
            return .internalServerError
        }
    }
    
    func addRouteHandler<T: XMLRPCMethod>(_ type: T.Type) {
        xmlrpcRoutes.append(XMLRPCRoute(type: type))
    }
    
}
