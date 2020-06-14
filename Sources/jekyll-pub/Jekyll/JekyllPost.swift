//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation
import Yams

let NoID = "<<NONE>>"

let publishDateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.calendar = Calendar(identifier: .gregorian)
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone(secondsFromGMT: 0)!
    df.dateFormat = "y-MM-dd'T'HH:mm:ssZ"
    return df
}()

struct JekyllPost {
    
    struct Status: Equatable, XMLRPCParamConvertible {
        static let published = Status(rawValue: "publish")
        static let draft = Status(rawValue: "draft")
        let rawValue: String
        
        init(rawValue: String) { self.rawValue = rawValue }
        
        init(parameter: XMLRPCParam) throws {
            self.rawValue = try parameter.string ?! XMLRPCError.wrongType(Status.self, parameter)
        }
        
        func xmlrpcParameter() throws -> XMLRPCParam {
            return .string(rawValue)
        }
    }
    
    enum Kind: String, XMLRPCParamConvertible {
        case post
        case page
    }
    
    var yaml: Yams.Node
    var body: String
    var status: Status
    var kind: Kind
    var fileURL: URL?
    
    subscript(key: String) -> Yams.Node? {
        get {
            return yaml.mapping?[key]
        }
        set {
            yaml.mapping?[key] = newValue
        }
    }
    
    var id: String {
        get { self["id"]?.string ?? NoID }
        set { self["id"] = .init(newValue) }
    }
    
    var tags: Array<String> {
        get {
            return self["tags"]?.array().compactMap(\.string) ?? []
        }
        set {
            self["tags"] = .init(newValue.map { .init($0) })
        }
    }
    
    var title: String {
        get { self["title"]?.string ?? "New Post" }
        set { self["title"] = .init(newValue) }
    }
    
    var publishedDate: Date? {
        get {
            guard let pub = self["published"]?.string else { return nil }
            return publishDateFormatter.date(from: pub)
        }
        set {
            if let new = newValue {
                let str = publishDateFormatter.string(from: new)
                self["published"] = .init(str)
            } else {
                self["published"] = nil
            }
        }
    }
    
    init() {
        self.yaml = [:]
        self.body = ""
        self.fileURL = nil
        self.status = .draft
        self.kind = .post
    }
    
    init(url: URL, isPost: Bool, isDraftsFolder: Bool) throws {
        let contents = try String(contentsOf: url)
        let nsContents = contents as NSString
        let ymlRegex = try NSRegularExpression(pattern: "^---[\r\n](.*?)---[\r\n]+(.*)$", options: [.dotMatchesLineSeparators, .anchorsMatchLines])
        
        var yaml: Yams.Node?
        var body: String?
        if let match = ymlRegex.firstMatch(in: contents, options: [.anchored], range: NSRange(location: 0, length: nsContents.length)) {
            let extracted = nsContents.substring(with: match.range(at: 1))
            yaml = try Yams.compose(yaml: extracted)
            
            body = nsContents.substring(with: match.range(at: 2))
        }
        
        self.yaml = yaml ?? [:]
        self.body = body ?? contents
        self.status = isDraftsFolder ? .draft : .published
        self.fileURL = url
        self.kind = isPost ? .post : .page
    }
    
    func content() throws -> String {
        return """
        ---
        \(try Yams.serialize(node: yaml))
        ---
        
        \(body)
        """
    }
}

extension JekyllPost: XMLRPCParamConvertible {
    
    init(parameter: XMLRPCParam) throws {
        self.init()
        let obj = try parameter.object ?! XMLRPCError.wrongType(JekyllPost.self, parameter)
        self.title = try obj["title"]?.string ?! XMLRPCError.wrongType(String.self, obj["title"])
        self.body = try obj["description"]?.string ?! XMLRPCError.wrongType(String.self, obj["description"])
        if let statusParam = obj["post_status"] {
            let status = try Status(parameter: statusParam)
            self.status = (status == .published) ? .published : .draft
        }
        if let typeParam = obj["post_type"] {
            self.kind = try Kind(parameter: typeParam)
        }
    }
    
    func xmlrpcParameter() throws -> XMLRPCParam {
        return try .object([
            "dateCreated": .date(publishedDate ?? .distantPast),
            "userid": .int(0),
            "postid": .string(id),
            "post_type": .string("post"),
            "description": .string(body),
            "title": .string(title),
            "categories": .array([.string("Uncategorized")]),
            "post_status": status.xmlrpcParameter(),
            "mt_keywords": .array(tags.map { .string($0) })
        ])
    }
    
}
