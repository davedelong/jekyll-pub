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
    
    private let site: JekyllSite
    private let port: in_port_t
    private var xmlrpcRoutes = Array<XMLRPCRoute>()
    
    init(site: JekyllSite, port: in_port_t = 9080) {
        self.site = site
        self.port = port
        server.post["/"] = self.handleXMLRPC
        
        addRouteHandler(MetaWeblog.GetCategories.self)
        addRouteHandler(MetaWeblog.GetRecentPosts.self)
        addRouteHandler(MetaWeblog.NewPost.self)
        addRouteHandler(MetaWeblog.EditPost.self)
        addRouteHandler(MetaWeblog.DeletePost.self)
        addRouteHandler(MetaWeblog.GetPost.self)
        addRouteHandler(MetaWeblog.NewMediaObject.self)

        addRouteHandler(Wordpress.GetCategories.self)
        addRouteHandler(Wordpress.NewCategory.self)
        addRouteHandler(Wordpress.GetTags.self)
        addRouteHandler(Wordpress.NewPost.self)
        addRouteHandler(Wordpress.EditPost.self)
        addRouteHandler(Wordpress.DeletePost.self)
        addRouteHandler(Wordpress.GetPost.self)
        addRouteHandler(Wordpress.GetPosts.self)
        addRouteHandler(Wordpress.GetPostFormats.self)
        addRouteHandler(Wordpress.GetUsers.self)
        addRouteHandler(Wordpress.GetAuthors.self)
        addRouteHandler(Wordpress.GetMediaLibrary.self)
    }
    
    func run() throws {
        try server.start(port, forceIPv4: false, priority: .userInteractive)
        print("Serving files from \(site.rootFolder.path) on port \(port)")
        dispatchMain()
    }
    
    private func handleXMLRPC(_ request: HttpRequest) -> HttpResponse {
        let body = Data(request.body)
        let method: String
        do {
            method = try methodCall(for: body)
        } catch {
            return .badRequest(nil)
        }
        
        let possibleRoutes = xmlrpcRoutes.filter { $0.supportedMethods.contains(method) }
        print("\(method) -> \(possibleRoutes)")
        
        var handler: XMLRPCRoute.Executor?
        for possibleRoute in possibleRoutes {
            do {
                handler = try possibleRoute.decode(body)
            } catch {
                print("\(possibleRoute) failed to accept because: \(error)")
            }
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
    
    private func methodCall(for body: Data) throws -> String {
        let d = try XMLDocument(data: body, options: [])
        return try d.nodes(forXPath: "//methodCall/methodName").first?.stringValue ?! DecodingError.missingChildNode(d.rootElement()!, "methodName", [])
    }
    
    func addRouteHandler<T: XMLRPCMethod>(_ type: T.Type) {
        xmlrpcRoutes.append(XMLRPCRoute(type: type))
    }
    
}
