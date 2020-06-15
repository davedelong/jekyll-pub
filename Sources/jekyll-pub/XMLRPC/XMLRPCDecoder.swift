//
//  File.swift
//  
//
//  Created by Dave DeLong on 6/14/20.
//

import Foundation

class XMLRPCDecoder {
    init() { }
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let doc = try XMLDocument(data: data, options: [])
        let parameterNodes = try doc.nodes(forXPath: "//methodCall/params/param/value")
        parameterNodes.forEach { $0.detach() }
        let array = XMLElement(name: "array", child: XMLElement(name: "data", children: parameterNodes))
        let decoder = _XMLRPCDecoder(node: array, path: [])
        return try T.init(from: decoder)
    }
}

private struct _XMLRPCDecoder: Decoder {
    var codingPath: [CodingKey]
    
    var userInfo: [CodingUserInfoKey : Any]
    
    private let node: XMLNode
    
    init(node: XMLNode, path: [CodingKey]) {
        self.node = node
        self.codingPath = path
        self.userInfo = [:]
    }
    
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        // this should only work if the current node is "struct"
        return try KeyedDecodingContainer(_XMLRPCKeyedDecoder<Key>(node: node, path: codingPath))
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        // this should only work if the current node is "array"
        return try _XMLRPCUnkeyedDecoder(node: node, path: codingPath)
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return try _XMLRPCSingleValueDecoder(codingPath: codingPath, node: node)
    }
    
}

extension DecodingError {
    static func missingChildNode(_ node: XMLNode, _ name: String, _ path: [CodingKey]) -> DecodingError {
        let actual = node.xPath ?? "<missing>"
        let ctx = DecodingError.Context(codingPath: path, debugDescription: "Node \(actual) is missing a child named '\(name)")
        return .dataCorrupted(ctx)
    }
    static func missingChildNode(_ node: XMLNode, _ index: Int, _ path: [CodingKey]) -> DecodingError {
        let actual = node.xPath ?? "<missing>"
        let ctx = DecodingError.Context(codingPath: path, debugDescription: "Node \(actual) is missing a child at index '\(index)")
        return .dataCorrupted(ctx)
    }
    static func wrongNodeName(_ node: XMLNode, expected: String, _ path: [CodingKey]) -> DecodingError {
        let actual = node.xPath ?? "<missing>"
        let ctx = DecodingError.Context(codingPath: path, debugDescription: "Node \(actual) is not a named '\(expected)")
        return .dataCorrupted(ctx)
    }
    static func missingContents(_ node: XMLNode, _ path: [CodingKey]) -> DecodingError {
        let actual = node.xPath ?? "<missing>"
        let ctx = DecodingError.Context(codingPath: path, debugDescription: "Node \(actual) does not have any contents")
        return .dataCorrupted(ctx)
    }
    static func invalidContents(_ node: XMLNode, _ path: [CodingKey]) -> DecodingError {
        let actual = node.xPath ?? "<missing>"
        let ctx = DecodingError.Context(codingPath: path, debugDescription: "Node \(actual) has contents that cannot be interpreted")
        return .dataCorrupted(ctx)
    }
}
struct AnyCodingKey: CodingKey, ExpressibleByStringLiteral {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        guard let i = Int(stringValue) else { return nil }
        self.stringValue = stringValue
        self.intValue = i
    }
    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
    init(stringLiteral value: String) {
        self.stringValue = value
        self.intValue = Int(value)
    }
}

// this decodes a <struct>, which holds an array of <member /> nodes
private struct _XMLRPCKeyedDecoder<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let codingPath: [CodingKey]
    let allKeys: [Key]
    
    private let rootNode: XMLNode
    private let valueNodes: Dictionary<String, XMLNode>
    
    init(node: XMLNode, path: [CodingKey]) throws {
        guard node.name == "struct" else { throw DecodingError.wrongNodeName(node, expected: "struct", path) }
        let children = node.children ?? []
        let members = children.filter { $0.name == "member" }
        
        var map = Dictionary<String, XMLNode>()
        for member in members {
            let nameNode = try member.child(at: 0) ?! DecodingError.missingChildNode(node, 0, path)
            guard nameNode.name == "name" else { throw DecodingError.wrongNodeName(nameNode, expected: "name", path) }
            let name = try nameNode.stringValue ?! DecodingError.missingContents(nameNode, path)
            
            let valueNode = try member.child(at: 1) ?! DecodingError.missingChildNode(node, 1, path)
            guard valueNode.name == "value" else { throw DecodingError.wrongNodeName(valueNode, expected: "value", path) }
            
            map[name] = valueNode
        }
        self.rootNode = node
        self.codingPath = path
        self.valueNodes = map
        self.allKeys = map.keys.compactMap(Key.init(stringValue:))
    }
    
    func contains(_ key: Key) -> Bool {
        return valueNodes.keys.contains(key.stringValue)
    }
    
    func decodeNil(forKey key: Key) throws -> Bool {
        if contains(key) { return false }
        return true
    }
    
    private func getSingleChild(_ key: Key) throws -> XMLNode {
        let valueNode = try valueNodes[key.stringValue] ?! DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: "No member with name '\(key.stringValue)'"))
        
        return try valueNode.child(at: 0) ?! DecodingError.missingChildNode(valueNode, 0, codingPath + [key])
    }
    
    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
        let child = try getSingleChild(key)
        let decoder = try _XMLRPCSingleValueDecoder(codingPath: codingPath + [key], node: child)
        return try decoder.decode(type)
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        let valueNode = try getSingleChild(key)
        return try KeyedDecodingContainer(_XMLRPCKeyedDecoder<NestedKey>(node: valueNode, path: codingPath + [key]))
    }
    
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        let valueNode = try getSingleChild(key)
        return try _XMLRPCUnkeyedDecoder(node: valueNode, path: codingPath + [key])
    }
    
    func superDecoder() throws -> Decoder {
        return _XMLRPCDecoder(node: rootNode, path: codingPath)
    }
    
    func superDecoder(forKey key: Key) throws -> Decoder {
        return _XMLRPCDecoder(node: rootNode, path: codingPath)
    }
    
}

private struct _XMLRPCUnkeyedDecoder: UnkeyedDecodingContainer {
    private let root: XMLNode
    private let values: [XMLNode]
    
    let codingPath: [CodingKey]
    
    var count: Int? { values.count }
    var isAtEnd: Bool { currentIndex >= values.count }
    
    private(set) var currentIndex: Int = 0
    
    private var currentKey: CodingKey { AnyCodingKey(intValue: currentIndex)! }
    private var currentPath: [CodingKey] { codingPath + [currentKey] }
    
    init(node: XMLNode, path: [CodingKey]) throws {
        guard node.name == "array" else { throw DecodingError.wrongNodeName(node, expected: "array", path) }
        let data = try node.child(at: 0) ?! DecodingError.missingChildNode(node, 0, path)
        guard data.name == "data" else { throw DecodingError.wrongNodeName(data, expected: "data", path) }
        root = node
        values = data.children ?? []
        codingPath = path
    }
    
    private mutating func nextValue() throws -> (XMLNode, [CodingKey]) {
        let path = currentPath
        guard currentIndex >= 0 && currentIndex < values.count else {
            throw DecodingError.missingChildNode(root, currentIndex, path)
        }
        let v = values[currentIndex]
        currentIndex += 1
        guard v.name == "value" else { throw DecodingError.missingChildNode(v, "value", path) }
        let child = try v.child(at: 0) ?! DecodingError.missingChildNode(v, 0, path)
        return (child, path)
    }
    
    mutating func decodeNil() throws -> Bool {
        return false
    }
    
    mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        let (v, path) = try nextValue()
        let decoder = try _XMLRPCSingleValueDecoder(codingPath: path, node: v)
        return try decoder.decode(type)
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        let (v, path) = try nextValue()
        return try KeyedDecodingContainer(_XMLRPCKeyedDecoder<NestedKey>(node: v, path: path))
    }
    
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let (v, path) = try nextValue()
        return try _XMLRPCUnkeyedDecoder(node: v, path: path)
    }
    
    mutating func superDecoder() throws -> Decoder {
        return _XMLRPCDecoder(node: root, path: codingPath)
    }
    
}

private struct _XMLRPCSingleValueDecoder: SingleValueDecodingContainer {
    
    internal init(codingPath: [CodingKey], node: XMLNode) throws {
        var inner = node
        if node.name == "value" && node.childCount == 1 {
            inner = node.child(at: 0) ?? node
        }
        self.codingPath = codingPath
        self.node = inner
    }
    
    let codingPath: [CodingKey]
    let node: XMLNode
    
    private func stringContents(_ names: String...) throws -> String {
        let name = try node.name ?! DecodingError.wrongNodeName(node, expected: names[0], codingPath)
        if names.contains(name) == false {
            throw DecodingError.wrongNodeName(node, expected: names[0], codingPath)
        }
        return try node.stringValue ?! DecodingError.missingContents(node, codingPath)
    }
    
    func decodeNil() -> Bool { return false }
    
    func decode(_ type: Bool.Type) throws -> Bool {
        let contents = try stringContents("boolean")
        if contents == "1" { return true }
        if contents == "0" { return false }
        throw DecodingError.invalidContents(node, codingPath)
    }
    
    func decode(_ type: String.Type) throws -> String {
        return try stringContents("string")
    }
    
    func decode(_ type: Double.Type) throws -> Double {
        let contents = try stringContents("double")
        return try Double(contents) ?! DecodingError.invalidContents(node, codingPath)
    }
    
    func decode(_ type: Float.Type) throws -> Float {
        let contents = try stringContents("double")
        return try Float(contents) ?! DecodingError.invalidContents(node, codingPath)
    }
    
    func decode(_ type: Date.Type) throws -> Date {
        let contents = try stringContents("dateTime.iso8601")
        return try iso8601Formatter.date(from: contents) ?! DecodingError.invalidContents(node, codingPath)
    }
    
    func decode(_ type: Data.Type) throws -> Data {
        let contents = try stringContents("base64")
        return try Data(base64Encoded: contents) ?! DecodingError.invalidContents(node, codingPath)
    }
    
    private func decodeInt<I: FixedWidthInteger>() throws -> I {
        let contents = try stringContents("int", "i4")
        return try I(contents) ?! DecodingError.invalidContents(node, codingPath)
    }
    
    func decode(_ type: Int.Type) throws -> Int { try decodeInt() }
    func decode(_ type: Int8.Type) throws -> Int8 { try decodeInt() }
    func decode(_ type: Int16.Type) throws -> Int16 { try decodeInt() }
    func decode(_ type: Int32.Type) throws -> Int32 { try decodeInt() }
    func decode(_ type: Int64.Type) throws -> Int64 { try decodeInt() }
    func decode(_ type: UInt.Type) throws -> UInt { try decodeInt() }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try decodeInt() }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try decodeInt() }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try decodeInt() }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try decodeInt() }
    
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        let decoder = _XMLRPCDecoder(node: node, path: codingPath)
        return try T.init(from: decoder)
    }
}
