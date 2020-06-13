//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation
import Swifter

struct MetaWeblog {
    let server = HttpServer()
    let sites: Array<JekyllSite>
    
    init(sites: [JekyllSite]) {
        self.sites = sites
        server.post["/"] = self.handle
    }
    
    func run() throws {
        try server.start(9080, forceIPv4: false, priority: .userInteractive)
        dispatchMain()
    }
    
    private func handle(_ request: HttpRequest) -> HttpResponse {
        guard let method = MethodCall(httpRequest: request) else {
            return .badRequest(nil)
        }
        
        return .ok(.text(method.methodName))
    }
}
