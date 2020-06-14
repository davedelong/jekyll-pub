//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation
import Yams

let publishDateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.calendar = Calendar(identifier: .gregorian)
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone(secondsFromGMT: 0)!
    df.dateFormat = "y-MM-dd'T'HH:mm:ssZ"
    return df
}()

struct JekyllPost {
    
    struct Status {
        static let published = Status(rawValue: "publish")
        static let draft = Status(rawValue: "draft")
        let rawValue: String
    }
    
    var yaml: Yams.Node
    var body: String
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
        get { self["id"]?.string ?? "NONE" }
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
        get { self["title"]?.string ?? "NONE" }
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
    
    init(url: URL) throws {
        let contents = try String(contentsOf: url)
        let nsContents = contents as NSString
        let ymlRegex = try NSRegularExpression(pattern: "^---[\r\n](.*?)---[\r\n]+(.*)$", options: [.dotMatchesLineSeparators, .anchorsMatchLines])
        
        var yaml: Yams.Node?
        var body: String?
        if let match = ymlRegex.firstMatch(in: contents, options: [], range: NSRange(location: 0, length: nsContents.length)) {
            let extracted = nsContents.substring(with: match.range(at: 1))
            yaml = try Yams.compose(yaml: extracted)
            
            body = nsContents.substring(with: match.range(at: 2))
        }
        
        self.yaml = yaml ?? [:]
        self.body = body ?? contents
        self.fileURL = url
    }
    
}

extension JekyllPost: XMLRPCParamConvertible {
    
    func xmlrpcParameter() throws -> XMLRPCParam {
        return .object([
            "dateCreated": .date(publishedDate ?? .distantPast),
            "userid": .int(0),
            "postid": .string(id),
            "post_type": .string("post"),
            "description": .string(body),
            "title": .string(title),
            "categories": .array([.string("Uncategorized")]),
            "post_status": .string("publish"),
            "mt_keywords": .array(tags.map { .string($0) })
        ])
    }
    
}
