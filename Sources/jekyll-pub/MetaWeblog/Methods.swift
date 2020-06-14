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
    let parameters: Array<XMLRPCParam>
    
    init(request: HttpRequest) throws {
        let d = try XMLDocument(data: Data(request.body), options: [])
        guard let name = (try d.nodes(forXPath: "//methodCall/methodName")).first?.stringValue else {
            throw XMLRPCError.malformedXMLDocument
        }
        self.methodName = name
        
        let params = try d.nodes(forXPath: "//methodCall/params/param/value/.")
        parameters = try params.map { valueNode -> XMLRPCParam in
            guard let value = valueNode.child(at: 0) else { throw XMLRPCError.malformedXMLDocument }
            return try XMLRPCParam(xmlNode: value)
        }
    }
}

struct MethodResponse<B: XMLRPCParamConvertible> {
    let params: B
    
    func responseBody() throws -> Data {
        let response = XMLElement(name: "methodResponse")
        let paramsNode = XMLElement(name: "params")
        response.addChild(paramsNode)
        if let value = try params.xmlrpcParameter().xmlNode() {
            let valueNode = XMLElement(name: "value", child: value)
            paramsNode.addChild(XMLElement(name: "param", child: valueNode))
        }
        let document = XMLDocument(rootElement: response)
        document.version = "1.0"
        document.characterEncoding = "UTF-8"
        let d = document.xmlData(options: [.documentIncludeContentTypeDeclaration])
        if let s = String(data: d, encoding: .utf8) {
            print("BODY:\n\(s)")
        }
        return d
    }
}

enum MethodRouteError: Error {
    case wrongNumberOfParameters(Int, Int)
}

struct MethodRoute {
    let name: String
    let parameterCount: Int
    let handler: (Array<XMLRPCParam>) throws -> HttpResponse
    
    init(name: String, parameterCount: Int, body: @escaping (Array<XMLRPCParam>) throws -> HttpResponse) {
        self.name = name
        self.parameterCount = parameterCount
        self.handler = {
            guard $0.count == parameterCount else {
                throw MethodRouteError.wrongNumberOfParameters(parameterCount, $0.count)
            }
            return try body($0)
        }
    }
    
    init<R: XMLRPCParamConvertible>(name: String, parameterCount: Int, body: @escaping (Array<XMLRPCParam>) throws -> R) {
        self.name = name
        self.parameterCount = parameterCount
        self.handler = {
            guard $0.count == parameterCount else {
                throw MethodRouteError.wrongNumberOfParameters(parameterCount, $0.count)
            }
            let response = try body($0)
            let wrapper = MethodResponse(params: response)
            let body = try wrapper.responseBody()
            return .ok(.data(body))
        }
    }
}
