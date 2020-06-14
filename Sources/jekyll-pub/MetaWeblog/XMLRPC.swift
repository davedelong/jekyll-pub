//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/13/20.
//

import Foundation

enum XMLRPCParam {
    case empty
    case array(Array<XMLRPCParam>)
    case object(Dictionary<String, XMLRPCParam>)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case string(String)
    case date(Date)
    case data(Data)
    
    var array: Array<XMLRPCParam>? {
        guard case .array(let a) = self else { return nil }
        return a
    }
    
    var object: Dictionary<String, XMLRPCParam>? {
        guard case .object(let d) = self else { return nil }
        return d
    }
    
    var int: Int? {
        guard case .int(let i) = self else { return nil }
        return i
    }
    
    var double: Double? {
        guard case .double(let d) = self else { return nil }
        return d
    }
    
    var bool: Bool? {
        guard case .bool(let b) = self else { return nil }
        return b
    }
    
    var string: String? {
        guard case .string(let s) = self else { return nil }
        return s
    }
    
    var date: Date? {
        guard case .date(let d) = self else { return nil }
        return d
    }
    
    var data: Data? {
        guard case .data(let d) = self else { return nil }
        return d
    }
    
    init(xmlNode: XMLNode) throws {
        guard let name = xmlNode.name else { throw XMLRPCError.wrongNode("<any>", xmlNode) }
        if name == "array" {
            guard let data = xmlNode.child(at: 0) else { throw XMLRPCError.malformedXMLDocument }
            let children = try (data.children ?? []).map { value -> XMLRPCParam in
                guard let valueNode = value.child(at: 0) else { throw XMLRPCError.malformedXMLDocument }
                return try XMLRPCParam(xmlNode: valueNode)
            }
            self = .array(children)
        } else if name == "struct" {
            let members = (xmlNode.children ?? [])
            let keyPairs = try members.map { xmlNode -> (String, XMLRPCParam) in
                guard let name = xmlNode.child(at: 0)?.stringValue else { throw XMLRPCError.malformedXMLDocument }
                guard let valueNode = xmlNode.child(at: 1) else { throw XMLRPCError.malformedXMLDocument }
                guard let valueNodeContents = valueNode.child(at: 0) else { throw XMLRPCError.malformedXMLDocument }
                let value = try XMLRPCParam(xmlNode: valueNodeContents)
                return (name, value)
            }
            let dict = Dictionary(uniqueKeysWithValues: keyPairs)
            self = .object(dict)
            
        } else if name == "int" || name == "i4" {
            self = .int(try Int(node: xmlNode))
        } else if name == "double" {
            self = .double(try Double(node: xmlNode))
        } else if name == "boolean" {
            self = .bool(try Bool(node: xmlNode))
        } else if name == "string" {
            self = .string(try String(node: xmlNode))
        } else if name == "dateTime.iso8601" {
            self = .date(try Date(node: xmlNode))
        } else if name == "base64" {
            self = .data(try Data(node: xmlNode))
        } else {
            throw XMLRPCError.malformedXMLDocument
        }
    }
    
    func xmlNode() throws -> XMLNode? {
        switch self {
            case .empty: return nil
            case .array(let a):
                let children = try a.map { param -> XMLNode in
                    return XMLElement(name: "value", child: try param.xmlNode())
                }
                return XMLElement(name: "array", child: XMLElement(name: "data", children: children))
            case .object(let o):
                let sortedKeys = o.keys.sorted()
                let members = try sortedKeys.map { key -> XMLNode in
                    let name = XMLElement(name: "name", stringValue: key)
                    let value = XMLElement(name: "value", child: try o[key]!.xmlNode())
                    return XMLElement(name : "member", children: [name, value])
                }
                return XMLElement(name: "struct", children: members)
            case .int(let i): return try i.xmlNode()
            case .double(let d): return try d.xmlNode()
            case .bool(let b): return try b.xmlNode()
            case .string(let s): return try s.xmlNode()
            case .date(let d): return try d.xmlNode()
            case .data(let d): return try d.xmlNode()
        }
    }
}

protocol XMLRPCParamConvertible {
    init(parameter: XMLRPCParam) throws
    func xmlrpcParameter() throws -> XMLRPCParam
}
extension XMLRPCParamConvertible {
    init(parameter: XMLRPCParam) throws {
        throw XMLRPCError.wrongType(Self.self, parameter)
    }
    func xmlrpcParameter() throws -> XMLRPCParam {
        throw XMLRPCError.unknown
    }
}
protocol XMLNodeConvertible {
    init(node: XMLNode) throws
    func xmlNode() throws -> XMLNode
}

enum XMLRPCError: Error {
    case wrongType(Any.Type, XMLRPCParam?)
    case wrongNode(String, XMLNode)
    case malformedXMLDocument
    case unknown
}

//extension XMLDocument {
//
//    func xmlrpcParameter() throws -> XMLRPCParam {
//        guard let root = rootElement() else {
//            throw XMLRPCError.malformedXMLDocument
//        }
//        guard root.name == "methodResponse" else {
//            throw XMLRPCError.malformedXMLDocument
//        }
//        let faults = (root.children?.filter { $0.name == "fault" }) ?? []
//        if faults.count > 0 {
//            return try parseFaults(faults)
//        }
//
//        let params = (root.children?.filter { $0.name == "params" }) ?? []
//        if params.count > 0 {
//            return try parseParams(params)
//        }
//
//        throw XMLRPCError.malformedXMLDocument
//    }
//
//    private func parseFaults(_ faults: Array<XMLNode>) throws -> XMLRPCParam {
//
//    }
//
//    private func parseParams(_ params: Array<XMLNode>) throws -> XMLRPCParam {
//
//    }
//}

// MARK: - Value<T> && Member<T>
struct Value<T> {
    let value: T
}
extension Value: XMLNodeConvertible where T: XMLNodeConvertible {
    init(node: XMLNode) throws {
        guard node.name == "value" else { throw XMLRPCError.wrongNode("value", node) }
        guard node.childCount == 1 else { throw XMLRPCError.malformedXMLDocument }
        guard let child = node.child(at: 0) else { throw XMLRPCError.malformedXMLDocument }
        value = try T(node: child)
    }
    func xmlNode() throws -> XMLNode {
        let childValue = try value.xmlNode()
        return XMLElement(name: "value", child: childValue)
    }
}

struct Member<T> {
    let name: String
    let value: T
}
extension Member: XMLNodeConvertible where T: XMLNodeConvertible {
    init(node: XMLNode) throws {
        guard node.name == "member" else { throw XMLRPCError.wrongNode("member", node) }
        guard node.childCount == 2 else { throw XMLRPCError.malformedXMLDocument }
        guard let name = node.child(at: 0) else { throw XMLRPCError.malformedXMLDocument }
        guard let value = node.child(at: 1) else { throw XMLRPCError.malformedXMLDocument }
        guard name.name == "name" else { throw XMLRPCError.malformedXMLDocument }
        guard let n = name.stringValue else { throw XMLRPCError.malformedXMLDocument }
        
        self.name = n
        self.value = try Value<T>(node: value).value
    }
    func xmlNode() throws -> XMLNode {
        let nameValue = XMLElement(name: "name", stringValue: name)
        let childValue = try value.xmlNode()
        return XMLElement(name: "member", children: [nameValue, childValue])
    }
}

// MARK: - Array

extension Array: XMLRPCParamConvertible where Element: XMLRPCParamConvertible {
    init(parameter: XMLRPCParam) throws {
        guard let v = parameter.array else { throw XMLRPCError.wrongType(Array<Element>.self, parameter) }
        self = try v.map { try Element(parameter: $0) }
    }
    func xmlrpcParameter() throws -> XMLRPCParam {
        let mapped = try map { try $0.xmlrpcParameter() }
        return .array(mapped)
    }
}
extension Array: XMLNodeConvertible where Element: XMLNodeConvertible {
    init(node: XMLNode) throws {
        guard node.name == "array" else { throw XMLRPCError.wrongNode("array", node) }
        guard let dataNode = node.children?.first else { throw XMLRPCError.malformedXMLDocument }
        guard dataNode.name == "data" else { throw XMLRPCError.wrongNode("data", dataNode) }
        let children = dataNode.children ?? []
        self = try children.map { child -> Element in
            return try Value<Element>(node: child).value
        }
    }
    func xmlNode() throws -> XMLNode {
        let children = try map { element -> XMLNode in
            return try Value<Element>(value: element).xmlNode()
        }
        return XMLElement(name: "array", child: XMLElement(name: "data", children: children))
    }
}

// MARK: - Dictionary

extension Dictionary: XMLRPCParamConvertible where Key == String, Value: XMLRPCParamConvertible {
    init(parameter: XMLRPCParam) throws {
        guard let v = parameter.object else { throw XMLRPCError.wrongType(Dictionary<Key, Value>.self, parameter) }
        self = try v.mapValues { try Value(parameter: $0) }
    }
    func xmlrpcParameter() throws -> XMLRPCParam {
        let mapped = try mapValues { try $0.xmlrpcParameter() }
        return .object(mapped)
    }
}
extension Dictionary: XMLNodeConvertible where Key == String, Value: XMLNodeConvertible {
    init(node: XMLNode) throws {
        guard node.name == "struct" else { throw XMLRPCError.wrongNode("struct", node) }
        let members = try (node.children ?? []).map { node -> Member<Value> in
            try Member<Value>(node: node)
        }
        self.init()
        for member in members {
            self[member.name] = member.value
        }
    }
    func xmlNode() throws -> XMLNode {
        let sortedKeys = keys.sorted()
        let members = try sortedKeys.map { key -> XMLNode in
            let m = Member<Value>(name: key, value: self[key]!)
            return try m.xmlNode()
        }
        return XMLElement(name: "struct", children: members)
    }
}

// MARK: - Int

extension Int: XMLRPCParamConvertible {
    init(parameter: XMLRPCParam) throws {
        guard let v = parameter.int else { throw XMLRPCError.wrongType(Int.self, parameter) }
        self = v
    }
    func xmlrpcParameter() throws -> XMLRPCParam { return .int(self) }
}
extension Int: XMLNodeConvertible {
    init(node: XMLNode) throws {
        guard node.name == "int" || node.name == "i4" else { throw XMLRPCError.wrongNode("int", node) }
        guard let s = node.stringValue else { throw XMLRPCError.malformedXMLDocument }
        guard let i = Int(s) else { throw XMLRPCError.malformedXMLDocument }
        self = i
    }
    func xmlNode() throws -> XMLNode {
        return XMLElement(name: "int", stringValue: String(self))
    }
}

// MARK: - Double

extension Double: XMLRPCParamConvertible {
    init(parameter: XMLRPCParam) throws {
        guard let v = parameter.double else { throw XMLRPCError.wrongType(Double.self, parameter) }
        self = v
    }
    func xmlrpcParameter() throws -> XMLRPCParam { return .double(self) }
}
extension Double: XMLNodeConvertible {
    init(node: XMLNode) throws {
        guard node.name == "double" else { throw XMLRPCError.wrongNode("double", node) }
        guard let s = node.stringValue else { throw XMLRPCError.malformedXMLDocument }
        guard let i = Double(s) else { throw XMLRPCError.malformedXMLDocument }
        self = i
    }
    func xmlNode() throws -> XMLNode {
        assert(!self.isInfinite, "Only numeric values supported")
        assert(!self.isNaN, "Only numeric values supported")
        return XMLElement(name: "double", stringValue: "\(self)")
    }
}

// MARK: - Bool

extension Bool: XMLRPCParamConvertible {
    init(parameter: XMLRPCParam) throws {
        guard let v = parameter.bool else { throw XMLRPCError.wrongType(Bool.self, parameter) }
        self = v
    }
    func xmlrpcParameter() throws -> XMLRPCParam { return .bool(self) }
}
extension Bool: XMLNodeConvertible {
    init(node: XMLNode) throws {
        guard node.name == "boolean" else { throw XMLRPCError.wrongNode("boolean", node) }
        guard let s = node.stringValue else { throw XMLRPCError.malformedXMLDocument }
        self = (s == "1")
    }
    func xmlNode() throws -> XMLNode {
        return XMLElement(name: "boolean", stringValue: self ? "1" : "0")
    }
}

// MARK: - String

extension String: XMLRPCParamConvertible {
    init(parameter: XMLRPCParam) throws {
        guard let v = parameter.string else { throw XMLRPCError.wrongType(String.self, parameter) }
        self = v
    }
    func xmlrpcParameter() throws -> XMLRPCParam { return .string(self) }
}
extension String: XMLNodeConvertible {
    init(node: XMLNode) throws {
        guard node.name == "string" else { throw XMLRPCError.wrongNode("string", node) }
        guard let s = node.stringValue else { throw XMLRPCError.malformedXMLDocument }
        self = s
    }
    func xmlNode() throws -> XMLNode {
        return XMLElement(name: "string", stringValue: self)
    }
}

// MARK: - Date

extension Date: XMLRPCParamConvertible {
    init(parameter: XMLRPCParam) throws {
        guard let v = parameter.date else { throw XMLRPCError.wrongType(Date.self, parameter) }
        self = v
    }
    func xmlrpcParameter() throws -> XMLRPCParam { return .date(self) }
}
extension Date: XMLNodeConvertible {
    init(node: XMLNode) throws {
        guard node.name == "dateTime.iso8601" else { throw XMLRPCError.wrongNode("dateTime.iso8601", node) }
        guard let s = node.stringValue else { throw XMLRPCError.malformedXMLDocument }
        guard let d = iso8601Formatter.date(from: s) else { throw XMLRPCError.malformedXMLDocument }
        self = d
    }
    func xmlNode() throws -> XMLNode {
        return XMLElement(name: "dateTime.iso8601", stringValue: iso8601Formatter.string(from: self))
    }
}

private let iso8601Formatter: ISO8601DateFormatter = {
    // yyyyMMdd'T'HH:mm:ss
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withColonSeparatorInTime]
    return f
}()

// MARK: - Data

extension Data: XMLRPCParamConvertible {
    init(parameter: XMLRPCParam) throws {
        guard let v = parameter.data else { throw XMLRPCError.wrongType(Data.self, parameter) }
        self = v
    }
    func xmlrpcParameter() throws -> XMLRPCParam { return .data(self) }
}
extension Data: XMLNodeConvertible {
    init(node: XMLNode) throws {
        guard node.name == "base64" else { throw XMLRPCError.wrongNode("base64", node) }
        guard let s = node.stringValue else { throw XMLRPCError.malformedXMLDocument }
        guard let d = Data(base64Encoded: s) else { throw XMLRPCError.malformedXMLDocument }
        self = d
    }
    func xmlNode() throws -> XMLNode {
        return XMLElement(name: "base64", stringValue: base64EncodedString())
    }
}

// MARK: - Any

extension XMLRPCParamConvertible where Self: RawRepresentable, RawValue: XMLRPCParamConvertible {
    init(parameter: XMLRPCParam) throws {
        let raw = try RawValue(parameter: parameter)
        let v = try Self(rawValue: raw) ?! XMLRPCError.wrongType(Self.self, parameter)
        self = v
    }
    func xmlrpcParameter() throws -> XMLRPCParam {
        return try rawValue.xmlrpcParameter()
    }
}
