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
        addRouteHandler(Wordpress.GetCategories.self)
        addRouteHandler(Wordpress.NewCategory.self)
        addRouteHandler(Wordpress.GetUsers.self)
        addRouteHandler(Wordpress.GetPosts.self)
        addRouteHandler(Wordpress.GetTags.self)
    }
    
    func run() throws {
        try server.start(9080, forceIPv4: false, priority: .userInteractive)
        dispatchMain()
    }
    
    private func handleXMLRPC(_ request: HttpRequest) -> HttpResponse {
        let body = Data(request.body)
        var handler: XMLRPCRoute.Executor?
        for possibleRoute in xmlrpcRoutes {
            handler = try? possibleRoute.decode(body)
            if handler != nil {
                print("Chose route: \(possibleRoute)")
                break
            }
        }
        
        if let h = handler {
            do {
                let responseBody = try h(site)
                return .ok(.data(responseBody))
            } catch let fault as XMLRPCFault {
                if let encodedFault = try? XMLRPCEncoder().encode(fault) {
                    return .ok(.data(encodedFault))
                } else {
                    print("cannot encode fault: \(fault)")
                    return .internalServerError
                }
            } catch {
                print("Unknown error: \(error)")
                return .internalServerError
            }
        } else {
            return .unauthorized
        }
    }
    
    func addRouteHandler<T: XMLRPCMethod>(_ type: T.Type) {
        xmlrpcRoutes.append(XMLRPCRoute(type: type))
    }
    
}
