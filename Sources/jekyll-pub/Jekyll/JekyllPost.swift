//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation
import Ink

let publishDateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.calendar = Calendar(identifier: .gregorian)
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone(secondsFromGMT: 0)!
    df.dateFormat = "y-MM-dd'T'HH:mm:ssZ"
    return df
}()

struct JekyllPost {
    let url: URL
    var markdown: Markdown
    
    var id: String {
        get { markdown.metadata["id"] ?? "NONE" }
        set { markdown.metadata["id"] = newValue }
    }
    
    var tags: Array<String> {
        get {
            guard let tags = markdown.metadata["tags"] else { return [] }
            let all: Array<String>
            if tags.hasPrefix("[") && tags.hasSuffix("]") {
                let inner = tags.dropFirst().dropLast()
                let pieces = inner.components(separatedBy: ",")
                all = pieces.map { $0.trimmingCharacters(in: .whitespaces) }
            } else {
                all = [tags]
            }
            return all.filter { $0.isEmpty == false }
        }
        set {
            let cleaned = newValue
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.isEmpty == false }
            let escaped = cleaned.map { tag -> String in
                if tag.hasPrefix("\"") && tag.hasSuffix("\"") { return tag }
                if tag.contains(where: \.isWhitespace) == false { return tag }
                return "\"\(tag)\""
            }
            let joined = escaped.joined(separator: ", ")
            markdown.metadata["tags"] = "[" + joined + "]"
        }
    }
    
    var title: String {
        get {
            let raw = markdown.metadata["title"] ?? ""
            return raw.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        set {
            markdown.metadata["title"] = "\"\(newValue)\""
        }
    }
    
    var publishedDate: Date? {
        get {
            guard let pub = markdown.metadata["published"] else { return nil }
            return publishDateFormatter.date(from: pub)
        }
        set {
            if let new = newValue {
                let str = publishDateFormatter.string(from: new)
                markdown.metadata["published"] = str
            } else {
                markdown.metadata["published"] = nil
            }
        }
    }
    
    init(url: URL, markdown: Markdown) {
        self.url = url
        self.markdown = markdown
    }
    
}
