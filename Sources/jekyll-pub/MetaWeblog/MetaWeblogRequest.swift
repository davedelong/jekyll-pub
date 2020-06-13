//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation
import Swifter

struct MethodCall {
    let methodName: String
    let params: Array<String>
    
    init?(httpRequest: HttpRequest) {
        let body = httpRequest.body
        let bodyData = Data(body)
        do {
            let doc = try XMLDocument(data: bodyData, options: [.documentTidyXML])
            let name = try doc.nodes(forXPath: "//methodCall/methodName").first
            
            guard let nameString = name?.stringValue else { return nil }
            self.methodName = nameString
            
            let paramNodes = (try? doc.nodes(forXPath: "//methodCall/params/param/value/string")) ?? []
            self.params = paramNodes.compactMap(\.stringValue)
            print("Got params: \(params)")
        } catch {
            print("Cannot parse body: \(error)")
            return nil
        }
    }
}
