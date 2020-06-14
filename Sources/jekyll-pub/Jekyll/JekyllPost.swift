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
    
    struct Status: Equatable, Codable {
        static let published = Status(rawValue: "publish")
        static let draft = Status(rawValue: "draft")
        let rawValue: String
        
        init(rawValue: String) { self.rawValue = rawValue }
    }
    
    enum Kind: String, Codable {
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

extension JekyllPost: Codable {
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init()
        self.title = try c.decode(String.self, forKey: "title")
        self.body = try c.decode(String.self, forKey: "body")
        if let status = try c.decodeIfPresent(Status.self, forKey: "post_status") {
            self.status = status == .published ? .published : .draft
        }
        if let kind = try c.decodeIfPresent(Kind.self, forKey: "post_type") {
            self.kind = kind
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyCodingKey.self)
        try c.encode(0, forKey: "userid")
        try c.encode(id, forKey: "postid")
        try c.encode(kind, forKey: "post_type")
        try c.encode(body, forKey: "description")
        try c.encode(title, forKey: "title")
        try c.encode(["Uncategorized"], forKey: "categories")
        try c.encode(status, forKey: "post_status")
        try c.encode(tags, forKey: "mt_keywords")
        if let d = publishedDate {
            try c.encode(d, forKey: "dateCreated")
        }
    }
    
}
