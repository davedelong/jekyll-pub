//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation
import Yams

// Formats publish date in front matter when it's written to disk
let publishDateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.calendar = Calendar(identifier: .gregorian)
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone(secondsFromGMT: 0)!
    df.dateFormat = "y-MM-dd'T'HH:mm:ssZ"
    return df
}()

// This is an array of increasingly liberal date parsers that should try to
// hit every edge case of date format that I see in the wild (Jekyll preamble dates
// are pretty liberal
let publishDateParsers: [ISO8601DateFormatter] = [ISO8601DateFormatter.Options]([
    [.withInternetDateTime],
    [.withSpaceBetweenDateAndTime, .withColonSeparatorInTime, .withTimeZone],
    [.withSpaceBetweenDateAndTime, .withColonSeparatorInTime, .withTimeZone, .withColonSeparatorInTimeZone],
    [.withSpaceBetweenDateAndTime, .withColonSeparatorInTime],
]).flatMap { options in
    let df = ISO8601DateFormatter()
    // We _always_ want a full date and time
    df.formatOptions = options.union([.withFullTime, .withFullDate])

    // Also parse fractional seconds if present
    let dfFractional = ISO8601DateFormatter()
    dfFractional.formatOptions = options.union([.withFullTime, .withFullDate, .withFractionalSeconds])

    return [df, dfFractional]
}

struct JekyllPost: Hashable {
    
    enum Status: String, Codable {
        static var published: Status { .publish }
        case publish
        case draft
    }
    
    enum Kind: String, Codable {
        case post
        case page
    }
    
    var yaml: Yams.Node
    var body: String
    var status: Status
    var kind: Kind
    var rootURL: URL
    var fileURL: URL?
    var slug: String?

    // Treating post as a dict exposes raw front matter for get and set
    subscript(key: String) -> Yams.Node? {
        get { yaml.mapping?[key] }
        set { yaml.mapping?[key] = newValue }
    }
    
    // By default ID is relative path to file from site root, front matter can override it.
    // Setting it puts the override in the front matter.
    var id: String? {
        get { self["id"]?.string ?? fileURL?.absoluteString.replacing(rootURL.absoluteString, with: "") }
        set { self["id"] = newValue.map { .init($0) } }
    }
    
    var tags: Array<String> {
        get { self["tags"]?.array().compactMap(\.string) ?? [] }
        set { self["tags"] = .init(newValue.map { .init($0) }) }
    }
    
    var title: String? {
        get { self["title"]?.string }
        set { self["title"] = newValue.map { .init($0) } }
    }

    var publishedDate: Date? {
        get {
            // Look for explicit "published" then "date" keys in the front matter
            if let pub = self["published"]?.string ?? self["date"]?.string {
                if let date = publishDateParsers.lazy.compactMap({ $0.date(from: pub) }).first {
                    return date
                }
                // Ideally we should do what jekyll does if it can't parse the date. Whatever that is.
                assertionFailure("Can't parse date \(pub)")
                return nil
            }

            // For published blog posts, if there is no date key, assuming the filename is yyyy-mm-dd-slug
            if kind == .post && status == .published {
                guard let path = fileURL?.path else { return nil }
                let dateFromPath = try! Regex(#"\/(\d{4}\-\d{2}\-\d{2})-[^\/]+$"#)
                if let result = try? dateFromPath.firstMatch(in: path) {
                    return slugDateFormatter.date(from: String(result[1].value as! Substring))
                }
            }

            // Pages and drafts don't have to have a date
            return nil
        }
        set {
            if let new = newValue {
                let str = publishDateFormatter.string(from: new)
                self["date"] = .init(str)
            } else {
                self["date"] = nil
            }
        }
    }

    var editedDate: Date? {
        get {
            // mtime off disk, nothing clever
            guard let fileURL else { return nil }
            let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
            return attrs?[FileAttributeKey.creationDate] as? Date
        }
    }

    init(root: URL) {
        self.rootURL = root
        self.yaml = [:]
        self.body = ""
        self.fileURL = nil
        self.status = .draft
        self.kind = .post
    }

    init(url: URL, root: URL, isPost: Bool, isDraftsFolder: Bool) throws {
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
        
        self.rootURL = root
        self.yaml = yaml ?? [:]
        self.body = body ?? contents
        self.status = isDraftsFolder ? .draft : .published
        self.fileURL = url
        self.kind = isPost ? .post : .page

        if let explicitSlug = self["slug"]?.string {
            // Front matter can specify slug explicitly
            slug = explicitSlug
        } else if isPost {
            // Published post filenames can start yyyy-mm-dd-, the remainder is the slug
            slug = url.deletingPathExtension().lastPathComponent.replacing(try! Regex(#"^\d{4}\-\d{2}\-\d{2}-"#), with: "")
        } else {
            // Slugs for pages are their paths relative to the server root. Kinda weird
            // but I have no better place to expose path information (maybe categories?)
            slug = String(url.deletingPathExtension().absoluteString.replacing(root.absoluteString, with: "").trimmingPrefix("/"))
        }

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

// Metaweblog representation
// TODO this should be in MetaWeblog.swift and use a dedicated object,
// but I can't test it because I have no client - marsedit is the only
// thing I really care about and it doesn't call any methods in this file.
extension JekyllPost: Codable {

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        self.init(root: URL(string: "")!)
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
        try c.encode(slug, forKey: "wp_slug")
        if let d = publishedDate {
            try c.encode(d, forKey: "dateCreated")
        }
        if let d = editedDate {
            try c.encode(d, forKey: "date_modified")
        }
    }
    
}

extension JekyllPost: Comparable {
    // Sorts most recent post first, unpublished things come first so we always surface
    // drafts on the first page
    static func < (lhs: JekyllPost, rhs: JekyllPost) -> Bool {
        switch (lhs.publishedDate, rhs.publishedDate) {
        case (nil, nil): return false
        case (nil, _): return true
        case (_, nil): return false
        case (.some(let l), .some(let r)): return l > r
        }
    }
}
