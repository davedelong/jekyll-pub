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
    private var xmlrpcRoutes = Array<XMLRPCRoute>()
    
    init(site: JekyllSite) {
        self.site = site
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

        addRouteHandler(MovableType.GetCategories.self)
    }
    
    func run() throws {
        print("Serving files from \(site.rootFolder.path)")
        // Explicitly bind to localhost only
        server.listenAddressIPv4 = "127.0.0.1"
        try server.start(site.port, forceIPv4: true, priority: .userInteractive)
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
                print("  ..chose route: \(possibleRoute)")
                break
            }
        }
        
        if let h = handler {
            let startTime = CFAbsoluteTimeGetCurrent()
            defer {
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                print(String(format: "  ..took %.3f seconds", elapsed))
            }
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
            return .notFound
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
